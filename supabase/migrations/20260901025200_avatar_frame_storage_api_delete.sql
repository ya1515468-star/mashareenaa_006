BEGIN;

-- Storage objects must be deleted through the Storage API, never directly from SQL.
CREATE OR REPLACE FUNCTION public.admin_delete_avatar_frame(p_frame_key text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_key text := lower(trim(coalesce(p_frame_key,'')));
  v_storage_path text;
  v_cleared integer := 0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF v_key = '' THEN RAISE EXCEPTION 'FRAME_KEY_REQUIRED'; END IF;

  SELECT storage_path INTO v_storage_path
  FROM public.avatar_frame_catalog
  WHERE frame_key=v_key;
  IF NOT FOUND THEN RAISE EXCEPTION 'FRAME_NOT_FOUND'; END IF;

  UPDATE public.profiles
  SET avatar_frame_key=NULL, updated_at=now()
  WHERE avatar_frame_key=v_key;
  GET DIAGNOSTICS v_cleared=ROW_COUNT;

  DELETE FROM public.profile_cosmetic_catalog
  WHERE item_key=v_key AND category='frame';
  DELETE FROM public.avatar_frame_catalog WHERE frame_key=v_key;

  -- The returned path is intentionally deleted by the client through
  -- Supabase Storage API. Direct SQL deletion from storage.objects is forbidden.
  RETURN jsonb_build_object(
    'ok',true,
    'frame_key',v_key,
    'storage_path',v_storage_path,
    'storage_bucket','avatar-frames',
    'cleared_profiles',v_cleared
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_delete_avatar_frame(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_avatar_frame(text) TO authenticated;

COMMIT;
