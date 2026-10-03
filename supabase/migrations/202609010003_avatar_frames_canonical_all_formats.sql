-- Canonical avatar-frame Storage contract.
-- Supports static and animated common image formats.
-- The renderer creates the circular inner opening and visual motion/effects.

BEGIN;

DROP POLICY IF EXISTS avatar_frames_dragon_insert ON storage.objects;
DROP POLICY IF EXISTS avatar_frames_dragon_update ON storage.objects;
DROP POLICY IF EXISTS avatar_frames_dragon_delete ON storage.objects;

CREATE POLICY avatar_frames_dragon_insert
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatar-frames'
  AND (storage.foldername(name))[1] = 'catalog'
  AND lower(storage.extension(name)) IN ('gif','png','jpg','jpeg','webp','bmp')
  AND private.is_platform_owner_storage()
);

CREATE POLICY avatar_frames_dragon_update
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'avatar-frames' AND private.is_platform_owner_storage())
WITH CHECK (
  bucket_id = 'avatar-frames'
  AND private.is_platform_owner_storage()
  AND lower(storage.extension(name)) IN ('gif','png','jpg','jpeg','webp','bmp')
);

CREATE POLICY avatar_frames_dragon_delete
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'avatar-frames' AND private.is_platform_owner_storage());

UPDATE storage.buckets
SET file_size_limit = 8388608,
    allowed_mime_types = ARRAY[
      'image/gif','image/png','image/jpeg','image/webp','image/bmp'
    ]::text[]
WHERE id = 'avatar-frames';

COMMIT;
