-- Final parity repair: keep chat-badge Storage and profile-avatar presentation contracts aligned.
begin;

update storage.buckets
set file_size_limit = 8388608,
    allowed_mime_types = array['image/gif','image/png','image/jpeg','image/webp']::text[]
where id = 'chat-badges';

drop policy if exists chat_badges_owner_insert on storage.objects;
create policy chat_badges_owner_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'chat-badges'
  and split_part(name,'/',1) = 'catalog'
  and lower(storage.extension(name)) in ('gif','png','jpg','jpeg','webp')
  and private.is_platform_owner_storage()
);

drop policy if exists chat_badges_owner_update on storage.objects;
create policy chat_badges_owner_update on storage.objects
for update to authenticated
using (bucket_id = 'chat-badges' and private.is_platform_owner_storage())
with check (
  bucket_id = 'chat-badges'
  and private.is_platform_owner_storage()
  and lower(storage.extension(name)) in ('gif','png','jpg','jpeg','webp')
);

commit;
