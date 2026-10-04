-- Private DM voice storage: basic voice messages must not depend on Plus media entitlement.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-voice', 'chat-voice', false, 10485760,
  array['audio/mp4','audio/mpeg','audio/wav','audio/ogg','audio/aac','audio/webm']
)
on conflict (id) do update set
  public = false,
  file_size_limit = 10485760,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists chat_voice_insert_authenticated on storage.objects;
create policy chat_voice_insert_authenticated
on storage.objects for insert to authenticated
with check (
  bucket_id = 'chat-voice'
  and (storage.foldername(name))[1] = 'chat'
  and (storage.foldername(name))[2] = 'voice_private'
  and (storage.foldername(name))[3] = (auth.uid())::text
);

drop policy if exists chat_voice_select_authenticated on storage.objects;
create policy chat_voice_select_authenticated
on storage.objects for select to authenticated
using (
  bucket_id = 'chat-voice'
  and exists (
    select 1
    from public.chat_messages m
    join public.chat_threads t on t.id = m.thread_id
    where m.type = 'audio'
      and m.media_url = objects.name
      and (auth.uid())::text = any(t.participant_uids)
  )
);

drop policy if exists chat_voice_delete_authenticated on storage.objects;
create policy chat_voice_delete_authenticated
on storage.objects for delete to authenticated
using (
  bucket_id = 'chat-voice'
  and (storage.foldername(name))[1] = 'chat'
  and (storage.foldername(name))[2] = 'voice_private'
  and (storage.foldername(name))[3] = (auth.uid())::text
);
