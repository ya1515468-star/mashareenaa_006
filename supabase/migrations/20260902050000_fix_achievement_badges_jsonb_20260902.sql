create or replace function public.get_my_achievement_badges()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_badges jsonb := '[]'::jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.is_my_profile_service('achievement_badges') and not public.is_my_platform_owner() then
    raise exception 'FEATURE_REQUIRED_ACHIEVEMENT_BADGES';
  end if;
  select coalesce(gs.badges, '[]'::jsonb) into v_badges
  from public.gamification_stats gs
  where gs.user_id = v_uid;
  return jsonb_build_object('badges', coalesce(v_badges, '[]'::jsonb));
end $function$;
