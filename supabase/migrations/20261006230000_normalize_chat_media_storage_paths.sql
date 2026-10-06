-- Normalize persisted chat Storage references to object paths.
-- The bucket name belongs to Storage.from(bucket), not to the object name.

create or replace function public.normalize_chat_attachment_storage_path()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v text;
begin
  v := trim(coalesce(NEW.attachment_url, ''));
  if TG_TABLE_NAME = 'public_chat_messages' then
    if v like 'chat-voice/%' then
      NEW.attachment_url := substr(v, length('chat-voice/') + 1);
    elsif v like 'chat-media-plus/%' then
      NEW.attachment_url := substr(v, length('chat-media-plus/') + 1);
    end if;
  elsif TG_TABLE_NAME = 'chat_messages' then
    v := trim(coalesce(NEW.media_url, ''));
    if v like 'chat-voice/%' then
      NEW.media_url := substr(v, length('chat-voice/') + 1);
    elsif v like 'chat-media-plus/%' then
      NEW.media_url := substr(v, length('chat-media-plus/') + 1);
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_normalize_public_chat_attachment_path
on public.public_chat_messages;

create trigger trg_normalize_public_chat_attachment_path
before insert or update of attachment_url
on public.public_chat_messages
for each row
execute function public.normalize_chat_attachment_storage_path();

drop trigger if exists trg_normalize_private_chat_media_path
on public.chat_messages;

create trigger trg_normalize_private_chat_media_path
before insert or update of media_url
on public.chat_messages
for each row
execute function public.normalize_chat_attachment_storage_path();

update public.public_chat_messages
set attachment_url = substr(trim(attachment_url), length('chat-voice/') + 1)
where kind = 'audio'
  and trim(attachment_url) like 'chat-voice/%';

update public.public_chat_messages
set attachment_url = substr(trim(attachment_url), length('chat-media-plus/') + 1)
where kind in ('audio','image','video','file')
  and trim(attachment_url) like 'chat-media-plus/%';

update public.chat_messages
set media_url = substr(trim(media_url), length('chat-voice/') + 1)
where type = 'audio'
  and trim(media_url) like 'chat-voice/%';

update public.chat_messages
set media_url = substr(trim(media_url), length('chat-media-plus/') + 1)
where type in ('audio','image','video','file')
  and trim(media_url) like 'chat-media-plus/%';
