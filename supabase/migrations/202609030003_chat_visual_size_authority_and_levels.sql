-- Centralized 1-10 visual sizing controls.
-- Global defaults are owned by the platform owner.
-- Delegated/highest-role users can override their own size; the owner can
-- override any user.

create table if not exists public.chat_visual_size_settings (
  id boolean primary key default true check (id = true),
  frame_level smallint not null default 5 check (frame_level between 1 and 10),
  smiley_level smallint not null default 5 check (smiley_level between 1 and 10),
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

insert into public.chat_visual_size_settings(id, frame_level, smiley_level)
values (true, 5, 5)
on conflict (id) do nothing;

create table if not exists public.chat_visual_size_overrides (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  frame_level smallint not null check (frame_level between 1 and 10),
  smiley_level smallint not null check (smiley_level between 1 and 10),
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.chat_visual_size_authority (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  granted_by uuid not null references auth.users(id),
  granted_at timestamptz not null default now()
);

alter table public.chat_visual_size_settings enable row level security;
alter table public.chat_visual_size_overrides enable row level security;
alter table public.chat_visual_size_authority enable row level security;

create or replace function public._can_manage_chat_visual_size(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    public._is_platform_owner(p_uid)
    or exists (
      select 1
      from public.user_roles ur
      join public.roles r on r.id = ur.role_id
      where ur.user_id = p_uid and coalesce(r.priority,0) >= 300
    )
    or exists (
      select 1 from public.chat_visual_size_authority a where a.user_id = p_uid
    ), false
  )
$$;

grant execute on function public._can_manage_chat_visual_size(uuid) to authenticated;
revoke execute on function public._can_manage_chat_visual_size(uuid) from anon;

create or replace function public.get_chat_visual_size_config(p_user_id uuid default auth.uid())
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := coalesce(p_user_id, auth.uid());
  v_global public.chat_visual_size_settings;
  v_override public.chat_visual_size_overrides;
  v_owner boolean;
  v_high_role boolean;
  v_delegated boolean;
  v_frame smallint;
  v_smiley smallint;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_uid is null then raise exception 'USER_REQUIRED'; end if;

  select * into v_global from public.chat_visual_size_settings where id=true;
  select * into v_override from public.chat_visual_size_overrides where user_id=v_uid;

  v_owner := public._is_platform_owner(auth.uid());
  v_high_role := exists (
    select 1 from public.user_roles ur
    join public.roles r on r.id=ur.role_id
    where ur.user_id=auth.uid() and coalesce(r.priority,0) >= 300
  );
  v_delegated := exists (
    select 1 from public.chat_visual_size_authority a where a.user_id=auth.uid()
  );

  v_frame := coalesce(v_override.frame_level, v_global.frame_level, 5);
  v_smiley := coalesce(v_override.smiley_level, v_global.smiley_level, 5);

  return jsonb_build_object(
    'user_id', v_uid,
    'frame_level', v_frame,
    'smiley_level', v_smiley,
    'global_frame_level', coalesce(v_global.frame_level,5),
    'global_smiley_level', coalesce(v_global.smiley_level,5),
    'has_override', v_override.user_id is not null,
    'is_platform_owner', v_owner,
    'has_highest_role', v_high_role,
    'is_delegated', v_delegated,
    'can_manage_self', (auth.uid() = v_uid and (v_owner or v_high_role or v_delegated)),
    'can_manage_any', v_owner
  );
end;
$$;

grant execute on function public.get_chat_visual_size_config(uuid) to authenticated;
revoke execute on function public.get_chat_visual_size_config(uuid) from anon;

grant execute on function public.get_chat_visual_size_config() to authenticated;
revoke execute on function public.get_chat_visual_size_config() from anon;

create or replace function public.set_global_chat_visual_size(p_frame_level integer, p_smiley_level integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public._is_platform_owner(auth.uid()) then raise exception 'FORBIDDEN'; end if;
  if p_frame_level not between 1 and 10 or p_smiley_level not between 1 and 10 then
    raise exception 'LEVEL_MUST_BE_1_TO_10';
  end if;
  update public.chat_visual_size_settings
  set frame_level=p_frame_level::smallint,
      smiley_level=p_smiley_level::smallint,
      updated_by=auth.uid(), updated_at=now()
  where id=true;
end;
$$;

grant execute on function public.set_global_chat_visual_size(integer,integer) to authenticated;
revoke execute on function public.set_global_chat_visual_size(integer,integer) from anon;

create or replace function public.set_my_chat_visual_size(p_frame_level integer, p_smiley_level integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public._can_manage_chat_visual_size(auth.uid()) then raise exception 'FORBIDDEN'; end if;
  if p_frame_level not between 1 and 10 or p_smiley_level not between 1 and 10 then
    raise exception 'LEVEL_MUST_BE_1_TO_10';
  end if;
  insert into public.chat_visual_size_overrides(user_id,frame_level,smiley_level,updated_by,updated_at)
  values(auth.uid(),p_frame_level::smallint,p_smiley_level::smallint,auth.uid(),now())
  on conflict(user_id) do update set frame_level=excluded.frame_level,smiley_level=excluded.smiley_level,updated_by=excluded.updated_by,updated_at=now();
end;
$$;

grant execute on function public.set_my_chat_visual_size(integer,integer) to authenticated;
revoke execute on function public.set_my_chat_visual_size(integer,integer) from anon;

create or replace function public.set_user_chat_visual_size(p_user_id uuid, p_frame_level integer, p_smiley_level integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public._is_platform_owner(auth.uid()) then raise exception 'FORBIDDEN'; end if;
  if p_user_id is null then raise exception 'USER_REQUIRED'; end if;
  if p_frame_level not between 1 and 10 or p_smiley_level not between 1 and 10 then
    raise exception 'LEVEL_MUST_BE_1_TO_10';
  end if;
  insert into public.chat_visual_size_overrides(user_id,frame_level,smiley_level,updated_by,updated_at)
  values(p_user_id,p_frame_level::smallint,p_smiley_level::smallint,auth.uid(),now())
  on conflict(user_id) do update set frame_level=excluded.frame_level,smiley_level=excluded.smiley_level,updated_by=excluded.updated_by,updated_at=now();
end;
$$;

grant execute on function public.set_user_chat_visual_size(uuid,integer,integer) to authenticated;
revoke execute on function public.set_user_chat_visual_size(uuid,integer,integer) from anon;

create or replace function public.set_chat_visual_size_authority(p_user_id uuid, p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public._is_platform_owner(auth.uid()) then raise exception 'FORBIDDEN'; end if;
  if p_user_id is null or not exists(select 1 from public.profiles p where p.id=p_user_id) then raise exception 'USER_NOT_FOUND'; end if;
  if p_enabled then
    insert into public.chat_visual_size_authority(user_id,granted_by,granted_at)
    values(p_user_id,auth.uid(),now())
    on conflict(user_id) do update set granted_by=excluded.granted_by,granted_at=now();
  else
    delete from public.chat_visual_size_authority where user_id=p_user_id;
  end if;
end;
$$;

grant execute on function public.set_chat_visual_size_authority(uuid,boolean) to authenticated;
revoke execute on function public.set_chat_visual_size_authority(uuid,boolean) from anon;

create or replace function public.get_chat_visual_size_authorities()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id', a.user_id,
    'granted_by', a.granted_by,
    'granted_at', a.granted_at,
    'username', p.username,
    'display_name', p.display_name
  ) order by p.username), '[]'::jsonb)
  from public.chat_visual_size_authority a
  join public.profiles p on p.id=a.user_id
  where public._is_platform_owner(auth.uid())
$$;

grant execute on function public.get_chat_visual_size_authorities() to authenticated;
revoke execute on function public.get_chat_visual_size_authorities() from anon;
