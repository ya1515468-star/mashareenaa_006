begin;

create or replace function public.set_visual_effect(p_effect_key text,p_placement text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid:=auth.uid(); v_effect text:=lower(trim(coalesce(p_effect_key,''))); v_placement text:=lower(trim(coalesce(p_placement,''))); v_item public.profile_cosmetic_catalog%rowtype;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_placement not in ('username','avatar','both') then raise exception 'PLACEMENT_NOT_ALLOWED'; end if;
  if v_effect='' or v_effect='none' then
    if v_placement in ('username','both') then insert into public.gamification_stats(user_id,username_effect) values(v_uid,'none') on conflict(user_id) do update set username_effect='none',updated_at=now(); end if;
    if v_placement in ('avatar','both') then update public.profiles set avatar_visual_effect_key=null,updated_at=now() where id=v_uid; if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
    else update public.profiles set updated_at=now() where id=v_uid; end if;
    return jsonb_build_object('status','cleared','effect_key','none','placement',v_placement);
  end if;
  select c.* into v_item from public.profile_cosmetic_catalog c where c.item_key='visualfx_'||v_effect and c.category='visual_effect' and c.is_active=true;
  if not found then raise exception 'EFFECT_NOT_AVAILABLE'; end if;
  if not (coalesce(v_item.metadata->'supported_targets','[]'::jsonb) ? v_placement) or (coalesce(v_item.metadata->>'placement','both')<>'both' and coalesce(v_item.metadata->>'placement','both')<>v_placement) then raise exception 'PLACEMENT_NOT_ALLOWED'; end if;
  if not coalesce(public.is_platform_owner(v_uid),false) and not exists(select 1 from public.profile_cosmetic_purchases p where p.user_id=v_uid and p.item_key=v_item.item_key) then raise exception 'ITEM_NOT_OWNED'; end if;
  if v_placement in ('username','both') then insert into public.gamification_stats(user_id,username_effect) values(v_uid,v_effect) on conflict(user_id) do update set username_effect=excluded.username_effect,updated_at=now(); end if;
  if v_placement in ('avatar','both') then update public.profiles set avatar_visual_effect_key=v_effect,updated_at=now() where id=v_uid; if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  else update public.profiles set updated_at=now() where id=v_uid; end if;
  return jsonb_build_object('status','equipped','effect_key',v_effect,'placement',v_placement,'item_key',v_item.item_key);
end;
$$;

commit;
