-- Generic content engagement store. content_id is text so existing UUID-based content
-- tables do not need invasive schema changes.
create table if not exists public.content_engagement_events (
  event_id uuid primary key default gen_random_uuid(),
  content_id text not null,
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  owner_user_id uuid references auth.users(id) on delete set null,
  event_type text not null,
  request_id uuid not null,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  constraint content_engagement_event_type_check check (event_type in ('interaction','share'))
);
create unique index if not exists content_engagement_event_once_idx on public.content_engagement_events(content_id,actor_user_id,event_type);
create index if not exists content_engagement_events_content_idx on public.content_engagement_events(content_id,event_type);
create table if not exists public.content_engagement_counts (
  content_id text primary key,
  interaction_count bigint not null default 0,
  share_count bigint not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.content_engagement_events enable row level security;
alter table public.content_engagement_counts enable row level security;
drop policy if exists content_engagement_counts_read on public.content_engagement_counts;
create policy content_engagement_counts_read on public.content_engagement_counts for select to authenticated using (true);
create or replace function public.record_content_engagement(p_content_id text,p_event_type text,p_owner_user_id uuid,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_count bigint; v_inserted boolean:=false;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
 if nullif(trim(p_content_id),'') is null then raise exception 'CONTENT_REQUIRED'; end if;
 if p_event_type not in ('interaction','share') then raise exception 'EVENT_TYPE_INVALID'; end if;
 insert into public.content_engagement_events(content_id,actor_user_id,owner_user_id,event_type,request_id)
 values(trim(p_content_id),v_uid,p_owner_user_id,p_event_type,p_request_id)
 on conflict(content_id,actor_user_id,event_type) do nothing;
 v_inserted := found;
 insert into public.content_engagement_counts(content_id) values(trim(p_content_id)) on conflict(content_id) do nothing;
 if v_inserted then
   if p_event_type='interaction' then
     update public.content_engagement_counts set interaction_count=interaction_count+1,updated_at=now() where content_id=trim(p_content_id) returning interaction_count into v_count;
   else
     update public.content_engagement_counts set share_count=share_count+1,updated_at=now() where content_id=trim(p_content_id) returning share_count into v_count;
   end if;
 end if;
 select case when p_event_type='interaction' then interaction_count else share_count end into v_count from public.content_engagement_counts where content_id=trim(p_content_id);
 return jsonb_build_object('content_id',trim(p_content_id),'interaction_count',(select interaction_count from public.content_engagement_counts where content_id=trim(p_content_id)),'share_count',(select share_count from public.content_engagement_counts where content_id=trim(p_content_id)),'changed',v_inserted);
end; $$;
revoke execute on function public.record_content_engagement(text,text,uuid,uuid) from public,anon; grant execute on function public.record_content_engagement(text,text,uuid,uuid) to authenticated;
create or replace function public.get_content_engagement(p_content_id text) returns jsonb language sql stable security definer set search_path='' as $$ select coalesce((select jsonb_build_object('content_id',content_id,'interaction_count',interaction_count,'share_count',share_count,'total_engagement',interaction_count+share_count) from public.content_engagement_counts where content_id=trim(p_content_id)),jsonb_build_object('content_id',trim(p_content_id),'interaction_count',0,'share_count',0,'total_engagement',0)); $$;
revoke execute on function public.get_content_engagement(text) from public,anon; grant execute on function public.get_content_engagement(text) to authenticated;
