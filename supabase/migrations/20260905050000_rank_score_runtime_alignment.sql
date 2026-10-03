-- Runtime alignment for the small numeric rank shown over chat avatars.
-- The value is server-authoritative XP, not a client-calculated local counter.
create or replace function public.get_live_chat_rank_display(p_uid uuid)
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $$
select case
  when p_uid is null then jsonb_build_object(
    'display_name','عضو','badge_url',null,'verified',false,
    'role_name','عضو','role_code','user','role_priority',0,
    'rank',1,'rank_score',1,'score',1,'xp',1,'rank_level',1,'rank_id','rookie'
  )
  when public._is_platform_owner(p_uid) then jsonb_build_object(
    'display_name',coalesce(p.display_name,p.username,'عضو'),'badge_url',p.chat_badge_url,
    'verified',p.verified,'role_name','مالك المنصة','role_code','dragon','role_priority',1000,
    'rank',0,'rank_score',0,'score',0,'xp',0,'rank_level',null,'rank_id',null,'is_owner',true
  )
  else jsonb_build_object(
    'display_name',coalesce(p.display_name,p.username,'عضو'),'badge_url',p.chat_badge_url,
    'verified',p.verified,'role_name',coalesce(r.name,'عضو'),'role_code',coalesce(r.code,'user'),
    'role_priority',coalesce(r.priority,0),
    'rank',greatest(1,coalesce(gs.rank_level,1)),
    'rank_score',greatest(1,coalesce(gs.xp,0)),
    'score',greatest(1,coalesce(gs.xp,0)),
    'xp',greatest(1,coalesce(gs.xp,0)),
    'rank_level',greatest(1,coalesce(gs.rank_level,1)),
    'rank_id',coalesce(gs.rank_id,'rookie'),'is_owner',false
  )
end
from public.profiles p
left join lateral (
  select r.name,r.code,r.priority
  from public.user_roles ur
  join public.roles r on r.id=ur.role_id
  where ur.user_id=p_uid
  order by coalesce(r.priority,0) desc limit 1
) r on true
left join public.gamification_stats gs on gs.user_id=p_uid
where p.id=p_uid;
$$;

grant execute on function public.get_live_chat_rank_display(uuid) to authenticated;
revoke execute on function public.get_live_chat_rank_display(uuid) from anon;
