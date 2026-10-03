-- Member Badge + User Title authoritative system.
-- Keeps legacy animated_chat_badges/profile.chat_badge_* intact as compatibility mirrors.

create table if not exists public.member_badge_catalog (
  id uuid primary key default gen_random_uuid(),
  badge_key text not null,
  name_ar text not null,
  category text not null default 'general',
  description text,
  asset_path text not null,
  asset_url text not null,
  mime_type text not null default 'image/gif',
  file_size_bytes bigint not null default 0,
  width integer,
  height integer,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id) on delete restrict,
  constraint member_badge_catalog_key_check check (badge_key ~ '^[a-z0-9][a-z0-9_-]{2,80}$'),
  constraint member_badge_catalog_name_check check (char_length(trim(name_ar)) between 1 and 80),
  constraint member_badge_catalog_gif_check check (lower(trim(mime_type)) = 'image/gif'),
  constraint member_badge_catalog_size_check check (file_size_bytes >= 0 and file_size_bytes <= 524288),
  constraint member_badge_catalog_asset_check check (lower(asset_path) like 'badges/v1/%.gif')
);

create unique index if not exists member_badge_catalog_badge_key_uidx
  on public.member_badge_catalog (badge_key);

create table if not exists public.user_member_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_id uuid not null references public.member_badge_catalog(id) on delete restrict,
  assigned_by uuid not null references auth.users(id) on delete restrict,
  assigned_at timestamptz not null default now(),
  is_active boolean not null default true,
  updated_at timestamptz not null default now(),
  source text not null default 'owner_admin',
  request_id uuid,
  metadata jsonb not null default '{}'::jsonb
);

create unique index if not exists user_member_badges_one_active_per_user
  on public.user_member_badges(user_id) where is_active = true;
create index if not exists user_member_badges_user_idx on public.user_member_badges(user_id);
create index if not exists user_member_badges_badge_idx on public.user_member_badges(badge_id);

alter table public.member_badge_catalog enable row level security;
alter table public.user_member_badges enable row level security;

drop policy if exists member_badge_catalog_public_active_read on public.member_badge_catalog;
create policy member_badge_catalog_public_active_read
on public.member_badge_catalog for select to authenticated
using (is_active = true);

-- No direct client INSERT/UPDATE/DELETE policies on either management table.
-- All mutations happen through server-authoritative RPCs.


-- Independent storage bucket. Hard storage limit is 512KB, matching the preferred maximum.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('member-badges','member-badges',true,524288,array['image/gif']::text[])
on conflict (id) do update set
  name=excluded.name,
  public=excluded.public,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

-- Storage write policies are owner-only; public reads are allowed for the public bucket.
drop policy if exists member_badges_public_read on storage.objects;
create policy member_badges_public_read
on storage.objects for select to public
using (bucket_id='member-badges' and name like 'badges/v1/%.gif');

drop policy if exists member_badges_owner_insert on storage.objects;
create policy member_badges_owner_insert
on storage.objects for insert to authenticated
with check (
  bucket_id='member-badges'
  and name like 'badges/v1/%.gif'
  and lower(storage.extension(name))='gif'
  and private.is_platform_owner_storage()
);

drop policy if exists member_badges_owner_update on storage.objects;
create policy member_badges_owner_update
on storage.objects for update to authenticated
using (bucket_id='member-badges' and private.is_platform_owner_storage())
with check (bucket_id='member-badges' and name like 'badges/v1/%.gif' and lower(storage.extension(name))='gif' and private.is_platform_owner_storage());

drop policy if exists member_badges_owner_delete on storage.objects;
create policy member_badges_owner_delete
on storage.objects for delete to authenticated
using (bucket_id='member-badges' and private.is_platform_owner_storage());

create or replace function public.list_member_badges()
returns setof public.member_badge_catalog
language sql
stable
security definer
set search_path = ''
as $$
  select b.*
  from public.member_badge_catalog b
  where b.is_active = true
  order by b.sort_order, b.created_at desc;
$$;

create or replace function public.list_member_badges_for_admin()
returns setof public.member_badge_catalog
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
  return query
    select b.* from public.member_badge_catalog b order by b.sort_order,b.created_at desc;
end;
$$;

create or replace function public.create_member_badge(
  p_badge_key text,
  p_name_ar text,
  p_category text,
  p_description text,
  p_asset_path text,
  p_asset_url text,
  p_file_size_bytes bigint,
  p_width integer,
  p_height integer,
  p_metadata jsonb default '{}'::jsonb,
  p_sort_order integer default 0,
  p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid; v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
  if nullif(trim(p_badge_key),'') is null then raise exception 'BADGE_KEY_REQUIRED'; end if;
  if nullif(trim(p_name_ar),'') is null then raise exception 'NAME_REQUIRED'; end if;
  if nullif(trim(p_asset_path),'') is null or lower(trim(p_asset_path)) not like 'badges/v1/%.gif' then raise exception 'GIF_REQUIRED'; end if;
  if nullif(trim(p_asset_url),'') is null then raise exception 'ASSET_URL_REQUIRED'; end if;
  if coalesce(p_file_size_bytes,0) <= 0 or p_file_size_bytes > 524288 then raise exception 'GIF_TOO_LARGE'; end if;
  if exists(select 1 from public.member_badge_catalog where badge_key=lower(trim(p_badge_key))) then raise exception 'BADGE_KEY_EXISTS'; end if;

  insert into public.member_badge_catalog(
    badge_key,name_ar,category,description,asset_path,asset_url,mime_type,
    file_size_bytes,width,height,is_active,sort_order,metadata,created_by
  ) values (
    lower(trim(p_badge_key)),left(trim(p_name_ar),80),coalesce(nullif(trim(p_category),''),'general'),nullif(trim(p_description),''),
    trim(p_asset_path),left(trim(p_asset_url),2048),'image/gif',p_file_size_bytes,p_width,p_height,true,
    greatest(0,coalesce(p_sort_order,0)),coalesce(p_metadata,'{}'::jsonb),v_uid
  ) returning id into v_id;

  insert into public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  values(v_uid,v_uid,'member_badge_create','member_badge_catalog',v_id::text,v_id::text,p_request_id,'success',jsonb_build_object('badge_key',lower(trim(p_badge_key))));
  return v_id;
end;
$$;

create or replace function public.update_member_badge_catalog(
  p_badge_id uuid,
  p_badge_key text,
  p_name_ar text,
  p_category text,
  p_description text,
  p_asset_path text,
  p_asset_url text,
  p_file_size_bytes bigint,
  p_width integer,
  p_height integer,
  p_metadata jsonb default '{}'::jsonb,
  p_sort_order integer default 0,
  p_request_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
  if p_badge_id is null then raise exception 'BADGE_REQUIRED'; end if;
  if nullif(trim(p_badge_key),'') is null then raise exception 'BADGE_KEY_REQUIRED'; end if;
  if nullif(trim(p_name_ar),'') is null then raise exception 'NAME_REQUIRED'; end if;
  if nullif(trim(p_asset_path),'') is null or lower(trim(p_asset_path)) not like 'badges/v1/%.gif' then raise exception 'GIF_REQUIRED'; end if;
  if nullif(trim(p_asset_url),'') is null then raise exception 'ASSET_URL_REQUIRED'; end if;
  if coalesce(p_file_size_bytes,0) <= 0 or p_file_size_bytes > 524288 then raise exception 'GIF_TOO_LARGE'; end if;

  update public.member_badge_catalog
  set badge_key=lower(trim(p_badge_key)), name_ar=left(trim(p_name_ar),80),
      category=coalesce(nullif(trim(p_category),''),'general'), description=nullif(trim(p_description),''),
      asset_path=trim(p_asset_path), asset_url=left(trim(p_asset_url),2048), mime_type='image/gif',
      file_size_bytes=p_file_size_bytes,width=p_width,height=p_height,sort_order=greatest(0,coalesce(p_sort_order,0)),
      metadata=coalesce(p_metadata,'{}'::jsonb),updated_at=now()
  where id=p_badge_id;
  if not found then raise exception 'BADGE_NOT_FOUND'; end if;

  -- Keep the compatibility mirror in sync for profiles using the old field.
  update public.profiles p set chat_badge_url=b.asset_url, updated_at=now()
  from public.user_member_badges u join public.member_badge_catalog b on b.id=u.badge_id
  where u.user_id=p.id and u.badge_id=p_badge_id and u.is_active=true;

  insert into public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  values(v_uid,v_uid,'member_badge_update','member_badge_catalog',p_badge_id::text,p_badge_id::text,p_request_id,'success',jsonb_build_object('badge_key',lower(trim(p_badge_key))));
end;
$$;

create or replace function public.set_member_badge_active(
  p_badge_id uuid, p_is_active boolean, p_request_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
  update public.member_badge_catalog set is_active=coalesce(p_is_active,false),updated_at=now() where id=p_badge_id;
  if not found then raise exception 'BADGE_NOT_FOUND'; end if;
  if not coalesce(p_is_active,false) then
    update public.user_member_badges set is_active=false,updated_at=now() where badge_id=p_badge_id and is_active=true;
    update public.profiles p set chat_badge_id=null,chat_badge_url=null,updated_at=now()
    where p.chat_badge_id=p_badge_id;
  end if;
  insert into public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  values(v_uid,v_uid,case when coalesce(p_is_active,false) then 'member_badge_activate' else 'member_badge_archive' end,'member_badge_catalog',p_badge_id::text,p_badge_id::text,p_request_id,'success','{}'::jsonb);
end;
$$;

create or replace function public.get_user_member_badge(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_build_object(
      'user_id',u.user_id::text,
      'id',b.id::text,
      'badge_key',b.badge_key,
      'name_ar',b.name_ar,
      'category',b.category,
      'description',b.description,
      'asset_url',b.asset_url,
      'asset_path',b.asset_path,
      'mime_type',b.mime_type,
      'file_size_bytes',b.file_size_bytes,
      'width',b.width,
      'height',b.height,
      'metadata',b.metadata,
      'placement','above_name_template',
      'active',true
    ),
    '{}'::jsonb
  )
  from public.user_member_badges u
  join public.member_badge_catalog b on b.id=u.badge_id
  where u.user_id=coalesce(p_user_id,auth.uid()) and u.is_active=true and b.is_active=true
  order by u.updated_at desc
  limit 1;
$$;

create or replace function public.set_user_member_badge(
  p_user_id uuid, p_badge_key text, p_request_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid:=auth.uid(); v_badge_id uuid; v_asset_url text; v_locked boolean:=false;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
  if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
  if exists(select 1 from public.audit_logs where action='member_badge_assign' and request_id=p_request_id and result='success') then return; end if;
  perform pg_advisory_xact_lock(hashtextextended(coalesce(p_user_id::text,''),0));
  select id,asset_url into v_badge_id,v_asset_url from public.member_badge_catalog where badge_key=lower(trim(p_badge_key)) and is_active=true;
  if v_badge_id is null then raise exception 'BADGE_NOT_AVAILABLE'; end if;
  if not exists(select 1 from public.profiles where id=p_user_id and is_active=true and is_suspended=false) then raise exception 'USER_NOT_AVAILABLE'; end if;
  update public.user_member_badges set is_active=false,updated_at=now() where user_id=p_user_id and is_active=true;
  insert into public.user_member_badges(user_id,badge_id,assigned_by,is_active,source,request_id,metadata)
  values(p_user_id,v_badge_id,v_uid,true,'owner_admin',p_request_id,'{}'::jsonb);
  update public.profiles set chat_badge_id=v_badge_id,chat_badge_url=v_asset_url,updated_at=now() where id=p_user_id;
  insert into public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  values(v_uid,v_uid,'member_badge_assign','user_member_badges',p_user_id::text,p_user_id::text,p_request_id,'success',jsonb_build_object('badge_id',v_badge_id::text,'badge_key',lower(trim(p_badge_key))));
end;
$$;

create or replace function public.clear_user_member_badge(p_user_id uuid,p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
  if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
  if exists(select 1 from public.audit_logs where action='member_badge_clear' and request_id=p_request_id and result='success') then return; end if;
  perform pg_advisory_xact_lock(hashtextextended(coalesce(p_user_id::text,''),0));
  update public.user_member_badges set is_active=false,updated_at=now() where user_id=p_user_id and is_active=true;
  update public.profiles set chat_badge_id=null,chat_badge_url=null,updated_at=now() where id=p_user_id;
  insert into public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  values(v_uid,v_uid,'member_badge_clear','user_member_badges',p_user_id::text,p_user_id::text,p_request_id,'success','{}'::jsonb);
end;
$$;

revoke execute on function public.list_member_badges() from public,anon;
grant execute on function public.list_member_badges() to authenticated;
revoke execute on function public.list_member_badges_for_admin() from public,anon;
grant execute on function public.list_member_badges_for_admin() to authenticated;
revoke execute on function public.create_member_badge(text,text,text,text,text,text,bigint,integer,integer,jsonb,integer,uuid) from public,anon;
grant execute on function public.create_member_badge(text,text,text,text,text,text,bigint,integer,integer,jsonb,integer,uuid) to authenticated;
revoke execute on function public.update_member_badge_catalog(uuid,text,text,text,text,text,text,bigint,integer,integer,jsonb,integer,uuid) from public,anon;
grant execute on function public.update_member_badge_catalog(uuid,text,text,text,text,text,text,bigint,integer,integer,jsonb,integer,uuid) to authenticated;
revoke execute on function public.set_member_badge_active(uuid,boolean,uuid) from public,anon;
grant execute on function public.set_member_badge_active(uuid,boolean,uuid) to authenticated;
revoke execute on function public.get_user_member_badge(uuid) from public,anon;
grant execute on function public.get_user_member_badge(uuid) to authenticated;
revoke execute on function public.set_user_member_badge(uuid,text,uuid) from public,anon;
grant execute on function public.set_user_member_badge(uuid,text,uuid) to authenticated;
revoke execute on function public.clear_user_member_badge(uuid,uuid) from public,anon;
grant execute on function public.clear_user_member_badge(uuid,uuid) to authenticated;

-- User titles, kept independent from badges and name templates.
create table if not exists public.user_title_catalog (
  id uuid primary key default gen_random_uuid(),
  title_key text not null unique,
  name_ar text not null,
  icon_url text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id) on delete restrict,
  constraint user_title_key_check check (title_key ~ '^[a-z0-9][a-z0-9_-]{2,80}$'),
  constraint user_title_name_check check (char_length(trim(name_ar)) between 1 and 80)
);

create table if not exists public.user_titles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  title_key text references public.user_title_catalog(title_key) on delete restrict,
  assigned_by uuid not null references auth.users(id) on delete restrict,
  assigned_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  request_id uuid
);

alter table public.user_title_catalog enable row level security;
alter table public.user_titles enable row level security;
drop policy if exists user_title_catalog_read on public.user_title_catalog;
create policy user_title_catalog_read on public.user_title_catalog for select to authenticated using (is_active=true);

create or replace function public.list_user_titles()
returns setof public.user_title_catalog language sql stable security definer set search_path='' as $$
 select * from public.user_title_catalog where is_active=true order by sort_order,created_at desc;
$$;

create or replace function public.get_user_title(p_user_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_build_object('user_id',u.user_id::text,'key',c.title_key,'name_ar',c.name_ar,'active',true),'{}'::jsonb)
 from public.user_titles u join public.user_title_catalog c on c.title_key=u.title_key
 where u.user_id=coalesce(p_user_id,auth.uid()) and u.is_active=true and c.is_active=true;
$$;

create or replace function public.set_user_title(p_user_id uuid,p_title_key text,p_request_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
 if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
 if exists(select 1 from public.audit_logs where action='user_title_set' and request_id=p_request_id and result='success') then return; end if;
 perform pg_advisory_xact_lock(hashtextextended(coalesce(p_user_id::text,''),1));
 if p_title_key is null then
   update public.user_titles set is_active=false,title_key=null,updated_at=now(),request_id=p_request_id where user_id=p_user_id;
 else
   if not exists(select 1 from public.user_title_catalog where title_key=lower(trim(p_title_key)) and is_active=true) then raise exception 'TITLE_NOT_AVAILABLE'; end if;
   insert into public.user_titles(user_id,title_key,assigned_by,is_active,request_id)
   values(p_user_id,lower(trim(p_title_key)),v_uid,true,p_request_id)
   on conflict(user_id) do update set title_key=excluded.title_key,assigned_by=excluded.assigned_by,is_active=true,updated_at=now(),request_id=excluded.request_id;
 end if;
 insert into public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
 values(v_uid,v_uid,'user_title_set','user_titles',p_user_id::text,p_user_id::text,p_request_id,'success',jsonb_build_object('title_key',p_title_key));
end;
$$;

revoke execute on function public.list_user_titles() from public,anon; grant execute on function public.list_user_titles() to authenticated;
revoke execute on function public.get_user_title(uuid) from public,anon; grant execute on function public.get_user_title(uuid) to authenticated;
revoke execute on function public.set_user_title(uuid,text,uuid) from public,anon; grant execute on function public.set_user_title(uuid,text,uuid) to authenticated;

-- Welcome message gets the current server title, without mixing it into the account name.
create or replace function public.announce_chat_welcome(p_room_id uuid, p_request_id uuid default gen_random_uuid())
returns uuid language plpgsql security definer set search_path='public' as $function$
declare
  v_uid uuid:=auth.uid(); v_message_id uuid; v_existing uuid; v_display_name text; v_title text; v_template text; v_image_url text; v_enabled boolean; v_text text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
  if not exists(select 1 from public.chat_rooms r where r.id=p_room_id and r.is_active=true) then raise exception 'ROOM_NOT_FOUND'; end if;
  if not exists(select 1 from public.chat_room_members m where m.room_id=p_room_id and m.user_id=v_uid and coalesce(m.is_banned,false)=false)
     and not coalesce((select r.is_public from public.chat_rooms r where r.id=p_room_id),false) then raise exception 'FORBIDDEN'; end if;
  select m.id into v_existing from public.public_chat_messages m where m.room_id=p_room_id and m.metadata->>'welcome_request_id'=p_request_id::text limit 1;
  if v_existing is not null then return v_existing; end if;
  if public.is_my_profile_service('hide_join_announcement') then
    perform public.record_profile_service_use('hide_join_announcement',jsonb_build_object('action','welcome_announcement_suppressed','room_id',p_room_id));
    return null;
  end if;
  insert into public.chat_welcome_settings(room_id) values(p_room_id) on conflict(room_id) do nothing;
  select message_template,image_url,is_enabled into v_template,v_image_url,v_enabled from public.chat_welcome_settings where room_id=p_room_id;
  if coalesce(v_enabled,true)=false then return null; end if;
  select coalesce(nullif(trim(p.display_name),''),nullif(trim(p.username),''),'عضو') into v_display_name from public.profiles p where p.id=v_uid;
  select c.name_ar into v_title from public.user_titles u join public.user_title_catalog c on c.title_key=u.title_key where u.user_id=v_uid and u.is_active=true and c.is_active=true;
  if position('{username}' in coalesce(v_template,'')) > 0 then
    v_text:=replace(v_template,'{username}',coalesce(v_display_name,'عضو'));
  elsif nullif(trim(v_template),'') is not null then
    v_text:='✨ أهلًا وسهلًا يا '||coalesce(v_display_name,'عضو')||coalesce(case when v_title is not null then ' ('||v_title||')' else '' end,'')||' في MASHAREENA 👑، '||trim(v_template);
  else
    v_text:='✨ أهلًا وسهلًا يا '||coalesce(v_display_name,'عضو')||coalesce(case when v_title is not null then ' ('||v_title||')' else '' end,'')||' في MASHAREENA 👑، نورت الغرفة. 🌟';
  end if;
  insert into public.public_chat_messages(user_id,room_id,display_name,username,avatar_url,message,body,kind,metadata)
  values(v_uid,p_room_id,'بوت الترحيب','welcome_bot',null,v_text,v_text,'system',jsonb_build_object('system_event','welcome_bot','welcome_request_id',p_request_id::text,'target_user_id',v_uid::text,'target_username',v_display_name,'target_title',coalesce(v_title,''),'image_url',coalesce(v_image_url,''))) returning id into v_message_id;
  insert into public.chat_global_events(event_type,actor_uid,room_id,payload,expires_at)
  values('welcome_bot',v_uid,p_room_id,jsonb_build_object('message',v_text,'target_user_id',v_uid::text,'target_username',v_display_name,'target_title',coalesce(v_title,''),'actor_name',v_display_name,'image_url',coalesce(v_image_url,''),'duration_seconds',8),now()+interval '8 seconds');
  return v_message_id;
end;$function$;
