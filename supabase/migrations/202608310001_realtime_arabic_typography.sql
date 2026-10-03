-- Arabic typography preferences for username/message rendering.
alter table public.profiles add column if not exists username_font_family text not null default 'noto_kufi_arabic';
alter table public.profiles add column if not exists message_font_family text not null default 'cairo';

create or replace function public.set_my_profile_typography(p_username_font_family text, p_message_font_family text)
returns jsonb language plpgsql security definer set search_path=public as $function$
declare
  v_uid uuid := auth.uid();
  v_username text := lower(trim(coalesce(p_username_font_family,'')));
  v_message text := lower(trim(coalesce(p_message_font_family,'')));
  v_allowed text[] := array['noto_kufi_arabic','cairo','tajawal','noto_naskh_arabic','amiri','lateef','reem_kufi','scheherazade_new','changa','almarai','readex_pro','rubik'];
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not (v_username = any(v_allowed)) then raise exception 'INVALID_USERNAME_FONT'; end if;
  if not (v_message = any(v_allowed)) then raise exception 'INVALID_MESSAGE_FONT'; end if;
  update public.profiles set username_font_family=v_username, message_font_family=v_message, updated_at=now() where id=v_uid;
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  return jsonb_build_object('ok',true,'username_font_family',v_username,'message_font_family',v_message);
end; $function$;

revoke all on function public.set_my_profile_typography(text,text) from public;
grant execute on function public.set_my_profile_typography(text,text) to authenticated;
