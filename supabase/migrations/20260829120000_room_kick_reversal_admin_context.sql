-- Restore a real inverse for temporary room kicks and expose kick state in admin context.
create or replace function private.unkick_room_member(
  p_room_id uuid,
  p_user_id uuid,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_room_id is null or p_user_id is null then raise exception 'INVALID_ARGUMENT'; end if;
  if v_uid = p_user_id then raise exception 'CANNOT_MODERATE_SELF'; end if;
  if not (
    public._is_platform_owner(v_uid)
    or coalesce((public.get_my_room_controls(p_room_id)->>'can_kick')::boolean, false)
    or coalesce((public.get_my_room_controls(p_room_id)->>'can_manage_members')::boolean, false)
    or coalesce((public.get_my_room_controls(p_room_id)->>'can_manage_room')::boolean, false)
  ) then
    raise exception 'FORBIDDEN';
  end if;
  perform public._assert_room_actor_above_target(p_room_id, p_user_id);

  update public.chat_room_penalties
     set is_active = false,
         updated_at = now()
   where room_id = p_room_id
     and user_id = p_user_id
     and penalty_type = 'kick'
     and is_active = true
     and (expires_at is null or expires_at > now());

  if not found then
    raise exception 'KICK_NOT_ACTIVE';
  end if;

  perform public.write_audit(
    'unkick_room_member',
    p_user_id::text,
    gen_random_uuid(),
    'success',
    jsonb_build_object('room_id',p_room_id,'reason',left(coalesce(p_reason,''),500))
  );
end;
$$;

grant execute on function private.unkick_room_member(uuid,uuid,text) to authenticated;

create or replace function public.unkick_room_member(
  p_room_id uuid,
  p_user_id uuid,
  p_reason text default null
)
returns void
language sql
security definer
set search_path = public
as $$
  select private.unkick_room_member($1,$2,$3);
$$;

grant execute on function public.unkick_room_member(uuid,uuid,text) to authenticated;

create or replace function private.get_room_member_admin_context(
  p_room_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid:=auth.uid();
  v_actor jsonb;
  v_target jsonb;
  v_is_banned boolean:=false;
  v_is_muted boolean:=false;
  v_is_kicked boolean:=false;
  v_is_buried boolean:=false;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  v_actor:=public.get_my_room_controls(p_room_id);
  v_actor:=jsonb_set(v_actor,'{can_unmute}',to_jsonb(coalesce((v_actor->>'can_unban')::boolean,false)),true);
  v_actor:=jsonb_set(v_actor,'{can_unkick}',to_jsonb(coalesce((v_actor->>'can_kick')::boolean,false)),true);
  if not(
    public._is_platform_owner(v_uid)
    or coalesce((v_actor->>'can_manage_members')::boolean,false)
    or coalesce((v_actor->>'can_kick')::boolean,false)
    or coalesce((v_actor->>'can_ban')::boolean,false)
    or coalesce((v_actor->>'can_mute')::boolean,false)
    or coalesce((v_actor->>'can_unban')::boolean,false)
  ) then raise exception 'FORBIDDEN'; end if;

  delete from public.chat_room_penalties
   where room_id=p_room_id
     and (is_active=false or (expires_at is not null and expires_at<now()));

  select
    exists(select 1 from public.chat_room_penalties p where p.room_id=p_room_id and p.user_id=p_user_id and p.penalty_type='ban' and p.is_active=true and (p.expires_at is null or p.expires_at>now())),
    exists(select 1 from public.chat_room_penalties p where p.room_id=p_room_id and p.user_id=p_user_id and p.penalty_type='mute' and p.is_active=true and (p.expires_at is null or p.expires_at>now())),
    exists(select 1 from public.chat_room_penalties p where p.room_id=p_room_id and p.user_id=p_user_id and p.penalty_type='kick' and p.is_active=true and (p.expires_at is null or p.expires_at>now())),
    exists(select 1 from public.chat_room_penalties p where p.room_id=p_room_id and p.user_id=p_user_id and p.penalty_type='bury' and p.is_active=true)
  into v_is_banned,v_is_muted,v_is_kicked,v_is_buried;

  select jsonb_build_object(
    'user_id',m.user_id,
    'role_id',m.role_id,
    'role_name',r.name,
    'role_code',r.role_key,
    'role_priority',coalesce(r.priority,0),
    'is_banned',v_is_banned,
    'is_muted',v_is_muted,
    'is_kicked',v_is_kicked,
    'is_buried',v_is_buried,
    'is_member',true
  )
  into v_target
  from public.chat_room_members m
  left join public.chat_room_roles r on r.id=m.role_id
  where m.room_id=p_room_id and m.user_id=p_user_id;

  return jsonb_build_object(
    'target',coalesce(v_target,jsonb_build_object(
      'user_id',p_user_id,
      'is_member',false,
      'role_priority',0,
      'is_banned',v_is_banned,
      'is_muted',v_is_muted,
      'is_kicked',v_is_kicked,
      'is_buried',v_is_buried
    )),
    'actor',coalesce(v_actor,'{}'::jsonb),
    'is_dragon',public._is_platform_owner(v_uid)
  );
end;
$$;

grant execute on function private.get_room_member_admin_context(uuid,uuid) to authenticated;
