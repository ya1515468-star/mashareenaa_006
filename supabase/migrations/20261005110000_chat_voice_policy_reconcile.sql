-- Canonical voice storage policy for rooms and private chats.
drop policy if exists "chat_voice_select_authenticated" on storage.objects;
drop policy if exists "chat_voice_insert_authenticated" on storage.objects;
drop function if exists public.can_read_chat_voice_object(text);

create or replace function private.can_read_chat_voice_object(p_object_path text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then return false; end if;

  if exists (
    select 1 from public.chat_messages m
    join public.chat_threads t on t.id = m.thread_id
    where m.type = 'audio'
      and m.media_url = p_object_path
      and auth.uid()::text = any(t.participant_uids)
      and m.deleted_at is null
  ) then return true; end if;

  return exists (
    select 1 from public.public_chat_messages m
    join public.chat_rooms r on r.id = m.room_id
    where m.kind = 'audio'
      and m.attachment_url = p_object_path
      and m.deleted_at is null
      and r.is_active = true
      and (
        r.is_public = true
        or exists (
          select 1 from public.chat_room_members cm
          where cm.room_id = r.id
            and cm.user_id = auth.uid()
            and coalesce(cm.is_banned, false) = false
        )
      )
  );
end;
$$;

revoke all on function private.can_read_chat_voice_object(text) from public;
grant execute on function private.can_read_chat_voice_object(text) to authenticated;
grant execute on function private.can_read_chat_voice_object(text) to service_role;

create policy "chat_voice_insert_authenticated" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'chat-voice'
  and (storage.foldername(name))[1] = 'chat'
  and (storage.foldername(name))[2] = 'voice_private'
  and (storage.foldername(name))[3] = auth.uid()::text
  and lower(storage.extension(name)) = any (array['mp3','m4a','wav','ogg','aac','webm']::text[])
);

create policy "chat_voice_select_authenticated" on storage.objects
for select to authenticated
using (bucket_id = 'chat-voice' and private.can_read_chat_voice_object(name));
