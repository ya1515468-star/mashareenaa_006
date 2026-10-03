-- Server-authoritative numeric chat rank badge.
-- The displayed score is the user's accumulated server-side XP.
-- XP itself is awarded only by server-controlled progression functions for:
--   1) chat interaction (chat_message)
--   2) online presence (presence_session)
--   3) purchases (purchase)
-- The client never writes the score or decides its value.

create or replace function public.get_user_chat_rank_badge(
  p_user_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $$
select case
  when p_user_id is null then jsonb_build_object(
    'score', 0,
    'rank_score', 0,
    'rank', 0,
    'rank_level', null,
    'rank_id', null,
    'is_owner', false
  )
  when public._is_platform_owner(p_user_id) then jsonb_build_object(
    'score', 0,
    'rank_score', 0,
    'rank', 0,
    'rank_level', null,
    'rank_id', null,
    'is_owner', true
  )
  else jsonb_build_object(
    'score', greatest(1, coalesce(gs.xp, 0)),
    'rank_score', greatest(1, coalesce(gs.xp, 0)),
    'rank', greatest(1, coalesce(gs.xp, 0)),
    'rank_level', coalesce(gs.rank_level, 1),
    'rank_id', coalesce(gs.rank_id, 'rookie'),
    'is_owner', false
  )
end
from public.gamification_stats gs
where gs.user_id = p_user_id
union all
select jsonb_build_object(
  'score', 1,
  'rank_score', 1,
  'rank', 1,
  'rank_level', 1,
  'rank_id', 'rookie',
  'is_owner', false
)
where p_user_id is not null
  and not public._is_platform_owner(p_user_id)
  and not exists (
    select 1 from public.gamification_stats x where x.user_id = p_user_id
  )
limit 1;
$$;

revoke all on function public.get_user_chat_rank_badge(uuid) from public, anon;
grant execute on function public.get_user_chat_rank_badge(uuid) to authenticated;

-- Ensure clients can receive rank changes immediately from the existing
-- server-side gamification_stats row updates.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'gamification_stats'
  ) then
    alter publication supabase_realtime add table public.gamification_stats;
  end if;
exception when undefined_object then
  -- Some local/test databases do not have Supabase Realtime installed.
  null;
end;
$$;
