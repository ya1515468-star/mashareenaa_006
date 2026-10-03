-- Forward production reconciliation applied to Supabase on 2026-09-08.
-- Mirrors the deployed reconciliation logic without the historical broken RPC signature.
BEGIN;
UPDATE public.profiles p SET avatar_frame_key=NULL, updated_at=now() WHERE p.avatar_frame_key IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.avatar_frame_catalog f WHERE f.frame_key=p.avatar_frame_key);
REVOKE ALL ON FUNCTION public.admin_create_avatar_frame(text,text,text,text,text,integer,bigint,bigint,text[],integer,integer,text,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_create_avatar_frame(text,text,text,text,text,integer,bigint,bigint,text[],integer,integer,text,text,jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.get_avatar_frame_config(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_avatar_frame_config(text) TO authenticated;
REVOKE ALL ON FUNCTION public.set_avatar_frame(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.set_avatar_frame(text) TO authenticated;
REVOKE ALL ON FUNCTION public.get_avatar_frame_catalog() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_avatar_frame_catalog() TO authenticated;
UPDATE storage.buckets SET file_size_limit=8388608,allowed_mime_types=array['image/png','image/jpeg','image/webp','image/gif']::text[] WHERE id='profile-avatars';
UPDATE storage.buckets SET file_size_limit=5242880,allowed_mime_types=array['audio/mpeg','audio/wav','audio/x-wav','audio/ogg','audio/mp4','audio/aac','audio/webm']::text[] WHERE id='profile-music';
UPDATE storage.buckets SET file_size_limit=15728640,allowed_mime_types=array['image/png','image/jpeg','image/webp','image/gif']::text[] WHERE id='profile-patterns';
UPDATE storage.buckets SET file_size_limit=5242880,allowed_mime_types=array['audio/mpeg','audio/wav','audio/x-wav','audio/ogg','audio/mp4','audio/aac','audio/webm']::text[] WHERE id='chat-sounds';
UPDATE storage.buckets SET file_size_limit=8388608,allowed_mime_types=array['image/gif','image/png','image/jpeg','image/webp']::text[] WHERE id='chat-welcome-images';
UPDATE storage.buckets SET file_size_limit=8388608,allowed_mime_types=array['image/gif','image/png','image/jpeg','image/webp']::text[] WHERE id='chat-badges';
UPDATE storage.buckets SET file_size_limit=26214400,allowed_mime_types=array['image/png','image/jpeg','image/webp','image/gif','video/mp4','video/webm','video/quicktime','audio/mpeg','audio/wav','audio/ogg','audio/mp4','audio/aac','audio/webm','application/pdf','application/zip','application/octet-stream']::text[] WHERE id='media';
UPDATE storage.buckets SET file_size_limit=26214400,allowed_mime_types=array['image/png','image/jpeg','image/webp','image/gif','video/mp4','video/webm','video/quicktime','audio/mpeg','audio/wav','audio/ogg','audio/mp4','audio/aac','audio/webm','application/pdf','application/zip','application/octet-stream']::text[] WHERE id='store-media';
UPDATE storage.buckets SET file_size_limit=8388608,allowed_mime_types=array['image/gif','image/png','image/jpeg','image/webp','image/bmp']::text[] WHERE id='avatar-frames';
COMMIT;
