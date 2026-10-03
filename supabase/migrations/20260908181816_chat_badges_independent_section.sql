-- Independent server-authoritative animated badge catalog + explicit user assignment.
alter table public.profiles add column if not exists chat_badge_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='profiles_chat_badge_id_fkey'
      and conrelid='public.profiles'::regclass
  ) then
    alter table public.profiles add constraint profiles_chat_badge_id_fkey
      foreign key (chat_badge_id) references public.animated_chat_badges(id) on delete set null;
  end if;
end $$;

create index if not exists profiles_chat_badge_id_idx on public.profiles(chat_badge_id);

update public.profiles p
set chat_badge_id=b.id
from public.animated_chat_badges b
where p.chat_badge_id is null and nullif(trim(p.chat_badge_url),'') is not null and b.image_url=p.chat_badge_url;

create or replace function public.list_chat_badges_for_admin()
returns setof public.animated_chat_badges
language plpgsql security definer set search_path=''
as $function$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
  return query select b.* from public.animated_chat_badges b order by b.sort_order,b.created_at desc;
end;
$function$;

create or replace function public.update_animated_chat_badge(
  p_badge_id uuid,
  p_name_ar text,
  p_image_url text,
  p_storage_path text,
  p_sort_order integer default 0
)
returns void
language plpgsql security definer set search_path=''
as $function$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
  if p_badge_id is null then raise exception 'BADGE_REQUIRED'; end if;
  if nullif(trim(p_name_ar),'') is null then raise exception 'NAME_REQUIRED'; end if;
  if nullif(trim(p_image_url),'') is null then raise exception 'IMAGE_REQUIRED'; end if;
  if nullif(trim(p_storage_path),'') is null then raise exception 'STORAGE_PATH_REQUIRED'; end if;
  if lower(trim(p_storage_path)) not like 'catalog/%.gif' then raise exception 'GIF_REQUIRED'; end if;
  update public.animated_chat_badges
  set name_ar=left(trim(p_name_ar),80), image_url=left(trim(p_image_url),2048),
      storage_path=left(trim(p_storage_path),1024), sort_order=greatest(0,coalesce(p_sort_order,0)), updated_at=now()
  where id=p_badge_id;
  if not found then raise exception 'BADGE_NOT_FOUND'; end if;
  update public.profiles
  set chat_badge_url=case when chat_badge_id=p_badge_id then left(trim(p_image_url),2048) else chat_badge_url end,
      updated_at=case when chat_badge_id=p_badge_id then now() else updated_at end
  where chat_badge_id=p_badge_id;
end;
$function$;

create or replace function public.create_animated_chat_badge(
  p_name_ar text, p_image_url text, p_storage_path text, p_sort_order integer default 0
)
returns uuid
language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid:=auth.uid(); v_id uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
  if nullif(trim(p_name_ar),'') is null then raise exception 'NAME_REQUIRED'; end if;
  if nullif(trim(p_image_url),'') is null then raise exception 'IMAGE_REQUIRED'; end if;
  if nullif(trim(p_storage_path),'') is null then raise exception 'STORAGE_PATH_REQUIRED'; end if;
  if lower(trim(p_storage_path)) not like 'catalog/%.gif' then raise exception 'GIF_REQUIRED'; end if;
  insert into public.animated_chat_badges(name_ar,image_url,storage_path,sort_order,is_active,created_by)
  values(left(trim(p_name_ar),80),left(trim(p_image_url),2048),left(trim(p_storage_path),1024),greatest(0,coalesce(p_sort_order,0)),true,v_uid)
  returning id into v_id;
  return v_id;
end;
$function$;

create or replace function public.assign_chat_badge_to_user(p_user_id uuid,p_badge_id uuid)
returns void
language plpgsql security definer set search_path=''
as $function$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
  if p_user_id is null then raise exception 'USER_REQUIRED'; end if;
  if p_badge_id is not null and not exists (
    select 1 from public.animated_chat_badges b where b.id=p_badge_id and b.is_active=true
  ) then raise exception 'BADGE_NOT_AVAILABLE'; end if;
  if not exists (
    select 1 from public.profiles p where p.id=p_user_id and p.is_active=true and p.is_suspended=false
  ) then raise exception 'USER_NOT_AVAILABLE'; end if;
  update public.profiles
  set chat_badge_id=p_badge_id,
      chat_badge_url=case when p_badge_id is null then null else (select b.image_url from public.animated_chat_badges b where b.id=p_badge_id) end,
      updated_at=now()
  where id=p_user_id;
  if not found then raise exception 'USER_NOT_FOUND'; end if;
end;
$function$;

create or replace function public.set_my_chat_badge(p_badge_id uuid)
returns void language plpgsql security definer set search_path=''
as $function$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_badge_id is not null and not exists (
    select 1 from public.animated_chat_badges b where b.id=p_badge_id and b.is_active=true
  ) then raise exception 'BADGE_NOT_AVAILABLE'; end if;
  update public.profiles
  set chat_badge_id=p_badge_id,
      chat_badge_url=case when p_badge_id is null then null else (select b.image_url from public.animated_chat_badges b where b.id=p_badge_id) end,
      updated_at=now()
  where id=auth.uid();
  if not found then raise exception 'USER_NOT_FOUND'; end if;
end;
$function$;

create or replace function public.get_my_chat_badge()
returns jsonb language sql stable security definer set search_path=''
as $function$
  select jsonb_build_object('chat_badge_url',coalesce(p.chat_badge_url,''),'badge_id',coalesce(p.chat_badge_id::text,''),'badge_name',coalesce(b.name_ar,''))
  from public.profiles p left join public.animated_chat_badges b on b.id=p.chat_badge_id where p.id=auth.uid();
$function$;
