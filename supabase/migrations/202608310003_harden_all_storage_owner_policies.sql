-- Canonical Storage owner guard: does not call public._is_platform_owner.
CREATE OR REPLACE FUNCTION private.is_platform_owner_storage()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid()
      AND lower(r.code) = 'dragon'
  );
$$;

REVOKE ALL ON FUNCTION private.is_platform_owner_storage() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.is_platform_owner_storage() TO authenticated;

DROP POLICY IF EXISTS avatar_frames_dragon_insert ON storage.objects;
DROP POLICY IF EXISTS avatar_frames_dragon_update ON storage.objects;
DROP POLICY IF EXISTS avatar_frames_dragon_delete ON storage.objects;
CREATE POLICY avatar_frames_dragon_insert ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id='avatar-frames' AND (storage.foldername(name))[1]='catalog' AND lower(storage.extension(name)) IN ('gif','png','jpg','jpeg','webp','bmp') AND private.is_platform_owner_storage());
CREATE POLICY avatar_frames_dragon_update ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id='avatar-frames' AND private.is_platform_owner_storage())
WITH CHECK (bucket_id='avatar-frames' AND private.is_platform_owner_storage() AND lower(storage.extension(name)) IN ('gif','png','jpg','jpeg','webp','bmp'));
CREATE POLICY avatar_frames_dragon_delete ON storage.objects FOR DELETE TO authenticated
USING (bucket_id='avatar-frames' AND private.is_platform_owner_storage());

DROP POLICY IF EXISTS chat_welcome_images_owner_insert ON storage.objects;
DROP POLICY IF EXISTS chat_welcome_images_owner_update ON storage.objects;
DROP POLICY IF EXISTS chat_welcome_images_owner_delete ON storage.objects;
CREATE POLICY chat_welcome_images_owner_insert ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id='chat-welcome-images' AND split_part(name,'/',1)='rooms' AND private.is_platform_owner_storage());
CREATE POLICY chat_welcome_images_owner_update ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id='chat-welcome-images' AND private.is_platform_owner_storage())
WITH CHECK (bucket_id='chat-welcome-images' AND private.is_platform_owner_storage());
CREATE POLICY chat_welcome_images_owner_delete ON storage.objects FOR DELETE TO authenticated
USING (bucket_id='chat-welcome-images' AND private.is_platform_owner_storage());

DROP POLICY IF EXISTS chat_badges_owner_insert ON storage.objects;
DROP POLICY IF EXISTS chat_badges_owner_update ON storage.objects;
DROP POLICY IF EXISTS chat_badges_owner_delete ON storage.objects;
CREATE POLICY chat_badges_owner_insert ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id='chat-badges' AND split_part(name,'/',1)='catalog' AND lower(storage.extension(name)) IN ('gif','png','jpg','jpeg','webp') AND private.is_platform_owner_storage());
CREATE POLICY chat_badges_owner_update ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id='chat-badges' AND private.is_platform_owner_storage())
WITH CHECK (bucket_id='chat-badges' AND private.is_platform_owner_storage() AND lower(storage.extension(name)) IN ('gif','png','jpg','jpeg','webp'));
CREATE POLICY chat_badges_owner_delete ON storage.objects FOR DELETE TO authenticated
USING (bucket_id='chat-badges' AND private.is_platform_owner_storage());

REVOKE EXECUTE ON FUNCTION public._is_platform_owner(uuid) FROM PUBLIC, anon, authenticated;
