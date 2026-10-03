insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('chat-media-plus','chat-media-plus',true,26214400,array['image/png','image/jpeg','image/webp','image/gif','video/mp4','video/webm','video/quicktime','audio/mpeg','audio/wav','audio/ogg','audio/mp4','audio/aac','audio/webm','application/pdf','application/zip','application/octet-stream'])
on conflict(id) do update set file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types,public=excluded.public;

drop policy if exists chat_media_plus_insert_authenticated on storage.objects;
create policy chat_media_plus_insert_authenticated on storage.objects for insert to authenticated
with check (bucket_id='chat-media-plus' and public.has_profile_service_for_user(auth.uid(),'chat_media_plus') and (name ~ (('(^|/)'::text || auth.uid()::text) || '(/|$)'::text)));

drop policy if exists chat_media_plus_select_authenticated on storage.objects;
create policy chat_media_plus_select_authenticated on storage.objects for select to authenticated
using (bucket_id='chat-media-plus');

drop policy if exists chat_media_plus_delete_authenticated on storage.objects;
create policy chat_media_plus_delete_authenticated on storage.objects for delete to authenticated
using (bucket_id='chat-media-plus' and (name ~ (('(^|/)'::text || auth.uid()::text) || '(/|$)'::text)));

drop policy if exists chat_media_plus_update_authenticated on storage.objects;
create policy chat_media_plus_update_authenticated on storage.objects for update to authenticated
using (bucket_id='chat-media-plus' and (name ~ (('(^|/)'::text || auth.uid()::text) || '(/|$)'::text)))
with check (bucket_id='chat-media-plus' and public.has_profile_service_for_user(auth.uid(),'chat_media_plus') and (name ~ (('(^|/)'::text || auth.uid()::text) || '(/|$)'::text)));
