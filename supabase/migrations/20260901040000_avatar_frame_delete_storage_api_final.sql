create or replace function public.admin_delete_avatar_frame(p_frame_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_key text := lower(trim(coalesce(p_frame_key, '')));
  v_storage_path text;
  v_bucket text := 'avatar-frames';
  v_cleared integer := 0;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.is_platform_owner(v_uid) then raise exception 'FORBIDDEN'; end if;
  if v_key = '' then raise exception 'FRAME_KEY_REQUIRED'; end if;

  select storage_path into v_storage_path
  from public.avatar_frame_catalog
  where frame_key = v_key;
  if not found then raise exception 'FRAME_NOT_FOUND'; end if;

  update public.profiles
  set avatar_frame_key = null, updated_at = now()
  where avatar_frame_key = v_key;
  get diagnostics v_cleared = row_count;

  delete from public.profile_cosmetic_catalog
  where item_key = v_key and category = 'frame';

  delete from public.avatar_frame_catalog
  where frame_key = v_key;

  return jsonb_build_object(
    'ok', true,
    'frame_key', v_key,
    'storage_bucket', v_bucket,
    'storage_path', v_storage_path,
    'cleared_profiles', v_cleared,
    'storage_delete_required', (v_storage_path is not null)
  );
end;
$function$;
