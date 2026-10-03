-- Room command hardening and authoritative permission alignment.
-- Keeps all authorization server-side while making bury/unbury room-scoped.

create or replace function private.bury_room_member(
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
    or coalesce((public.get_my_room_controls(p_room_id)->>'can_manage_members')::boolean,false)
    or coalesce((public.get_my_room_controls(p_room_id)->>'can_manage_room')::boolean,false)
  ) then
    raise exception 'FORBIDDEN';
  end if;
  perform public._assert_room_actor_above_target(p_room_id,p_user_id);
  insert into public.chat_room_penalties(
    room_id,user_id,actor_id,penalty_type,reason,expires_at,is_active,updated_at
  ) values (
    p_room_id,p_user_id,v_uid,'bury',left(p_reason,1000),null,true,now()
  );
  perform public.write_audit(
    'bury_room_member',p_user_id::text,gen_random_uuid(),'success',
    jsonb_build_object('room_id',p_room_id,'reason',p_reason,'permanent',true)
  );
  perform public._announce_room_penalty(p_room_id,p_user_id,v_uid,'bury',p_reason,null,true);
end;
$$;

create or replace function public.bury_room_member(
  p_room_id uuid,
  p_user_id uuid,
  p_reason text default null
)
returns void
language sql
set search_path = public
as $$
  select private.bury_room_member($1,$2,$3);
$$;

create or replace function private.unbury_room_member(
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
    or coalesce((public.get_my_room_controls(p_room_id)->>'can_manage_members')::boolean,false)
    or coalesce((public.get_my_room_controls(p_room_id)->>'can_manage_room')::boolean,false)
  ) then
    raise exception 'FORBIDDEN';
  end if;
  perform public._assert_room_actor_above_target(p_room_id,p_user_id);
  update public.chat_room_penalties
     set is_active=false,
         updated_at=now()
   where room_id=p_room_id
     and user_id=p_user_id
     and penalty_type='bury'
     and is_active=true;
  if not found then raise exception 'BURY_NOT_ACTIVE'; end if;
  perform public.write_audit(
    'unbury_room_member',p_user_id::text,gen_random_uuid(),'success',
    jsonb_build_object('room_id',p_room_id,'reason',p_reason)
  );
  perform public._announce_room_penalty(p_room_id,p_user_id,v_uid,'bury',p_reason,null,false);
end;
$$;

create or replace function public.unbury_room_member(
  p_room_id uuid,
  p_user_id uuid,
  p_reason text default null
)
returns void
language sql
set search_path = public
as $$
  select private.unbury_room_member($1,$2,$3);
$$;

create or replace function private.grant_room_manager(
  p_room_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner boolean := false;
  v_platform boolean := false;
  v_role uuid;
  v_active boolean := false;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select owner_id=v_uid,is_active into v_owner,v_active
    from public.chat_rooms where id=p_room_id;
  if not found or not v_active then raise exception 'ROOM_NOT_FOUND'; end if;
  v_platform := public.is_dragon();
  if v_uid=p_user_id then raise exception 'CANNOT_CHANGE_SELF'; end if;
  if not (coalesce(v_owner,false) or v_platform) then raise exception 'FORBIDDEN'; end if;
  select cr.id into v_role
    from public.chat_room_roles cr
   where cr.room_id=p_room_id and cr.role_key='manager'
   limit 1;
  if v_role is null then
    insert into public.chat_room_roles(
      room_id,name,role_key,priority,permissions,created_by
    ) values (
      p_room_id,'مدير غرفة','manager',100,
      jsonb_build_object('manage_room',true),v_uid
    ) returning id into v_role;
  end if;
  insert into public.chat_room_members(room_id,user_id,role_id,is_banned)
  values(p_room_id,p_user_id,v_role,false)
  on conflict(room_id,user_id)
  do update set role_id=excluded.role_id,is_banned=false;
  insert into public.room_admin_permissions(room_id,user_id)
  values(p_room_id,p_user_id)
  on conflict do nothing;
  perform public._publish_room_admin_event(
    p_room_id,'manager_grant',p_user_id,
    format('👑 تم تعيين %s مديرًا للغرفة',
      coalesce((select display_name from public.profiles where id=p_user_id),'العضو')),
    '{}'::jsonb
  );
end;
$$;

create or replace function private.revoke_room_manager(
  p_room_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner boolean := false;
  v_platform boolean := false;
  v_role uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select owner_id=v_uid into v_owner
    from public.chat_rooms where id=p_room_id and is_active=true;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  v_platform := public.is_dragon();
  if not (coalesce(v_owner,false) or v_platform) then raise exception 'FORBIDDEN'; end if;
  select cr.id into v_role
    from public.chat_room_roles cr
   where cr.room_id=p_room_id and cr.role_key='manager'
   limit 1;
  update public.chat_room_members
     set role_id=null
   where room_id=p_room_id and user_id=p_user_id and role_id=v_role;
  if not found then raise exception 'MANAGER_NOT_FOUND'; end if;
  delete from public.room_admin_permissions
   where room_id=p_room_id and user_id=p_user_id;
  perform public._publish_room_admin_event(
    p_room_id,'manager_revoke',p_user_id,
    format('❌ تمت إزالة إدارة الغرفة عن %s',
      coalesce((select display_name from public.profiles where id=p_user_id),'العضو')),
    '{}'::jsonb
  );
end;
$$;
