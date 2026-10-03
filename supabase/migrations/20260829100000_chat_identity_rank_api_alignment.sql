-- Legacy rank API now reads the same server-authoritative progression rank.
create or replace function public.get_user_display_rank(
  p_user_id uuid,
  p_room_id uuid default null
)
returns jsonb
language sql
stable
set search_path to 'public'
as $$
select case
  when p_user_id is null then jsonb_build_object(
    'id','visitor','code','visitor','name','زائر','priority',0,'rank',0,
    'rank_level',1,'rank_id','rookie','scope','global','room_id',p_room_id
  )
  when public._is_platform_owner(p_user_id) then jsonb_build_object(
    'id','dragon','code','dragon','name','مالك المنصة','priority',1000,
    'rank',0,'rank_level',null,'rank_id',null,'scope','global','room_id',p_room_id
  )
  else jsonb_build_object(
    'id',coalesce(rr.code,'visitor'),'code',coalesce(rr.code,'visitor'),
    'name',coalesce(rr.name,'عضو'),'priority',coalesce(rr.priority,0),
    'rank',coalesce(gs.rank_level,1),'rank_level',coalesce(gs.rank_level,1),
    'rank_id',coalesce(gs.rank_id,'rookie'),
    'scope',case when cr.user_id is not null then 'room' else 'global' end,
    'room_id',p_room_id
  )
end
from (select p_user_id as user_id) x
left join public.gamification_stats gs on gs.user_id=x.user_id
left join lateral (
  select r.code,r.name,r.priority
  from public.user_roles ur join public.roles r on r.id=ur.role_id
  where ur.user_id=x.user_id
  order by coalesce(r.priority,0) desc
  limit 1
) rr on true
left join lateral (
  select m.user_id
  from public.chat_room_members m
  join public.chat_room_roles r2 on r2.id=m.role_id
  where p_room_id is not null and m.room_id=p_room_id and m.user_id=x.user_id
  order by coalesce(r2.priority,0) desc
  limit 1
) cr on true;
$$;
