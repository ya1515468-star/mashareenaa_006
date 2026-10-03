-- Final cosmetic model:
-- 1) Remove legacy visual_effect cosmetics for username/avatar.
-- 2) Remove the avatar visual-effect runtime state and RPCs.
-- 3) Keep username background + username effect as independent cosmetics.
-- 4) The 50 name_template items remain the primary template container; the
--    client composes the selected background/effect INSIDE the template.

BEGIN;

-- Retire any purchased/owned legacy visual effects before deleting the catalog.
DELETE FROM public.profile_cosmetic_purchases
WHERE item_key IN (
  SELECT item_key
  FROM public.profile_cosmetic_catalog
  WHERE category = 'visual_effect'
)
OR item_key LIKE 'visualfx_%';

DELETE FROM public.profile_cosmetic_catalog
WHERE category = 'visual_effect'
   OR item_key LIKE 'visualfx_%';

-- Remove legacy public RPCs that only existed for the deleted visual-effect system.
DROP FUNCTION IF EXISTS public.set_visual_effect(text, text);
DROP FUNCTION IF EXISTS public.update_profile_visual_effect(text, bigint, bigint, boolean, integer, text, boolean);

-- Rebuild public profile cosmetics without the deleted avatar visual-effect field.
DROP FUNCTION IF EXISTS public.get_public_profile_cosmetics(uuid);
CREATE FUNCTION public.get_public_profile_cosmetics(p_user_id uuid)
RETURNS TABLE(
  id uuid,
  username text,
  display_name text,
  email text,
  bio text,
  avatar_url text,
  cover_url text,
  status_text text,
  profile_music_url text,
  profile_music_duration_ms integer,
  profile_music_size_bytes bigint,
  country text,
  city text,
  profession text,
  experiences jsonb,
  social_links jsonb,
  verified boolean,
  visibility text,
  account_type text,
  username_color bigint,
  username_shine boolean,
  username_font_size double precision,
  status_font_size double precision,
  status_bold boolean,
  status_italic boolean,
  status_color bigint,
  animated_avatar_url text,
  chat_badge_url text,
  avatar_frame_key text,
  username_effect text,
  username_background_key text,
  username_background_mode text,
  username_background_color1 text,
  username_background_color2 text,
  username_background_opacity double precision,
  username_background_external_effect text,
  role_code text,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  username_template_key text
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
  select
    p.id,p.username,p.display_name,
    case when auth.uid()=p.id then coalesce(p.email,'') else '' end,
    p.bio,p.avatar_url,p.cover_url,p.status_text,p.profile_music_url,
    p.profile_music_duration_ms,p.profile_music_size_bytes,p.country,p.city,
    p.profession,coalesce(p.experiences,'[]'::jsonb),coalesce(p.social_links,'[]'::jsonb),
    coalesce(p.verified,false),coalesce(p.visibility,'public'),coalesce(p.account_type,'individual'),
    p.username_color,coalesce(p.username_shine,false),p.username_font_size,p.status_font_size,
    coalesce(p.status_bold,false),coalesce(p.status_italic,false),p.status_color,
    p.animated_avatar_url,p.chat_badge_url,p.avatar_frame_key,
    coalesce(gs.username_effect,'none'),p.username_background_key,p.username_background_mode,
    p.username_background_color1,p.username_background_color2,
    coalesce(p.username_background_opacity,.82),p.username_background_external_effect,
    coalesce((select r.code from public.user_roles ur join public.roles r on r.id=ur.role_id
      where ur.user_id=p.id order by r.priority desc,r.code asc limit 1),'user'),
    p.created_at,p.updated_at,p.username_template_key
  from public.profiles p
  left join public.gamification_stats gs on gs.user_id=p.id
  where p.id=p_user_id
    and p.is_active=true
    and p.is_suspended=false
    and (
      p.id=auth.uid()
      or private.has_permission('users.read')
      or public.is_platform_owner(auth.uid())
      or (coalesce(p.visibility,'public')='public'
          and not public.has_profile_service_for_user(p.id,'hide_profile'))
    );
$function$;

-- Rebuild chat identity without the deleted avatar visual-effect runtime state.
CREATE OR REPLACE FUNCTION public.get_user_chat_identity(
  p_user_id uuid,
  p_room_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  v_profile record;
  v_stats record;
  v_global_role_code text;
  v_global_role_name text;
  v_global_role_priority integer:=0;
  v_room_role_code text;
  v_room_role_name text;
  v_room_role_priority integer:=0;
  v_role_code text;
  v_role_name text;
  v_role_priority integer:=0;
  v_rank_id text;
  v_rank_level integer:=1;
  v_manual_rank integer:=0;
  v_xp bigint:=0;
  v_rank_name text;
  v_rank_badge_key text;
  v_badges jsonb:='[]'::jsonb;
begin
  select
    p.id,p.username,p.display_name,p.avatar_url,p.animated_avatar_url,p.chat_badge_url,
    p.username_color,p.username_shine,p.username_font_size,p.username_font_family,
    p.message_color,p.message_font_family,p.status_text,p.status_color,p.status_font_size,
    p.status_bold,p.status_italic,p.username_background_key,p.username_background_mode,
    p.username_background_color1,p.username_background_color2,p.username_background_opacity,
    p.username_background_external_effect,p.avatar_frame_key,p.username_template_key
  into v_profile
  from public.profiles p
  where p.id=p_user_id and p.is_active=true and p.is_suspended=false;

  if p_user_id is null or v_profile.id is null then
    return jsonb_build_object(
      'user_id',p_user_id,'username','عضو','display_name','عضو',
      'role',jsonb_build_object('code','visitor','name','زائر','priority',0,'scope','fallback','room_id',p_room_id),
      'rank',jsonb_build_object('id','rookie','level',1,'xp',0,'manual_rank',0,'name','مبتدئ','badge_key','rank_rookie'),
      'chat_badge',null,'chat_badge_url',null,'achievement_badges','[]'::jsonb,
      'status_text','','status_color',null,'status_font_size',12.5,'status_bold',false,'status_italic',false,
      'username_color',null,'username_shine',false,'username_font_size',22,'username_effect','none',
      'username_template_key',null,'username_font_family','noto_kufi_arabic','message_color',4294967295,
      'message_font_family','cairo','username_background_key',null,'username_background_mode',null,
      'username_background_color1',null,'username_background_color2',null,'username_background_opacity',0.82,
      'username_background_external_effect',null,'avatar_url',null,'animated_avatar_url',null,'avatar_frame_key',null
    );
  end if;

  select gs.xp,gs.rank_level,gs.rank_id,gs.manual_rank,gs.badges,gs.username_effect
    into v_stats
  from public.gamification_stats gs where gs.user_id=p_user_id;

  v_xp:=coalesce(v_stats.xp,0);
  v_rank_level:=greatest(coalesce(v_stats.rank_level,1),1);
  v_rank_id:=lower(coalesce(nullif(trim(v_stats.rank_id),''),'rookie'));
  v_manual_rank:=greatest(coalesce(v_stats.manual_rank,0),0);
  v_badges:=case when jsonb_typeof(coalesce(v_stats.badges,'[]'::jsonb))='array'
    then coalesce(v_stats.badges,'[]'::jsonb) else '[]'::jsonb end;

  if public._is_platform_owner(p_user_id) then
    v_role_code:='dragon'; v_role_name:='مالك المنصة'; v_role_priority:=1000;
  else
    if p_room_id is not null then
      select r.role_key,r.name,coalesce(r.priority,0)
        into v_room_role_code,v_room_role_name,v_room_role_priority
      from public.chat_room_members m
      join public.chat_room_roles r on r.id=m.role_id
      where m.room_id=p_room_id and m.user_id=p_user_id
      order by coalesce(r.priority,0) desc limit 1;
    end if;
    select r.code,r.name,coalesce(r.priority,0)
      into v_global_role_code,v_global_role_name,v_global_role_priority
    from public.user_roles ur join public.roles r on r.id=ur.role_id
    where ur.user_id=p_user_id
    order by coalesce(r.priority,0) desc limit 1;
    if v_room_role_code is not null then
      v_role_code:=v_room_role_code; v_role_name:=v_room_role_name; v_role_priority:=v_room_role_priority;
    elsif v_global_role_code is not null then
      v_role_code:=v_global_role_code; v_role_name:=v_global_role_name; v_role_priority:=v_global_role_priority;
    else
      v_role_code:='user'; v_role_name:='عضو'; v_role_priority:=0;
    end if;
  end if;

  if v_rank_id not in ('rookie','bronze','silver','gold','platinum','diamond','legend') then v_rank_id:='rookie'; end if;
  v_rank_name:=case v_rank_id
    when 'bronze' then 'برونزي' when 'silver' then 'فضي' when 'gold' then 'ذهبي'
    when 'platinum' then 'بلاتيني' when 'diamond' then 'ماسي' when 'legend' then 'أسطورة'
    else 'مبتدئ' end;
  v_rank_badge_key:='rank_'||v_rank_id;

  return jsonb_build_object(
    'user_id',p_user_id,'username',v_profile.username,'display_name',v_profile.display_name,
    'role',jsonb_build_object('code',v_role_code,'name',v_role_name,'priority',v_role_priority,
      'scope',case when v_room_role_code is not null and v_role_code<>'dragon' then 'room' else 'global' end,'room_id',p_room_id),
    'rank',jsonb_build_object('id',v_rank_id,'level',v_rank_level,'xp',v_xp,'manual_rank',v_manual_rank,
      'name',v_rank_name,'badge_key',v_rank_badge_key),
    'chat_badge',case when v_profile.chat_badge_url is null or trim(v_profile.chat_badge_url)='' then null
      else jsonb_build_object('url',v_profile.chat_badge_url) end,
    'chat_badge_url',v_profile.chat_badge_url,'achievement_badges',v_badges,
    'status_text',coalesce(v_profile.status_text,''),'status_color',v_profile.status_color,
    'status_font_size',coalesce(v_profile.status_font_size,12.5),'status_bold',coalesce(v_profile.status_bold,false),
    'status_italic',coalesce(v_profile.status_italic,false),'username_color',v_profile.username_color,
    'username_shine',coalesce(v_profile.username_shine,false),'username_font_size',coalesce(v_profile.username_font_size,22),
    'username_effect',coalesce(nullif(trim(v_stats.username_effect),''),'none'),
    'username_template_key',v_profile.username_template_key,
    'username_font_family',coalesce(nullif(trim(v_profile.username_font_family),''),'noto_kufi_arabic'),
    'message_color',coalesce(v_profile.message_color,4294967295),
    'message_font_family',coalesce(nullif(trim(v_profile.message_font_family),''),'cairo'),
    'username_background_key',v_profile.username_background_key,
    'username_background_mode',v_profile.username_background_mode,
    'username_background_color1',v_profile.username_background_color1,
    'username_background_color2',v_profile.username_background_color2,
    'username_background_opacity',coalesce(v_profile.username_background_opacity,.82),
    'username_background_external_effect',v_profile.username_background_external_effect,
    'avatar_url',v_profile.avatar_url,'animated_avatar_url',v_profile.animated_avatar_url,
    'avatar_frame_key',v_profile.avatar_frame_key
  );
end;
$function$;

-- Remove the old state column after all dependent functions are rebuilt.
ALTER TABLE public.profiles DROP COLUMN IF EXISTS avatar_visual_effect_key;

-- visual_effect is no longer a valid store category. The 50 standalone
-- name templates remain available as category name_template.
ALTER TABLE public.profile_cosmetic_catalog
  DROP CONSTRAINT IF EXISTS profile_cosmetic_catalog_category_check;
ALTER TABLE public.profile_cosmetic_catalog
  ADD CONSTRAINT profile_cosmetic_catalog_category_check
  CHECK (category = ANY (ARRAY['frame','background','name_effect','message_color','name_template']::text[]));

COMMIT;
