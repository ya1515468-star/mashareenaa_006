-- Applied LIVE and verified against project aknksnctyqjcsxcwnvdz (mashareena_v2) on 2026-09-12.
-- Adds: hard-delete for name animations, an aggregated "everything this user
-- owns/activated" admin viewer, and a server-driven store-section metadata
-- table (name/icon/background/display-mode) replacing hardcoded tab labels.

CREATE OR REPLACE FUNCTION public.admin_delete_name_animation(p_effect_key text, p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_key text:=lower(trim(coalesce(p_effect_key,''))); v_row public.name_animation_catalog%rowtype;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'REQUEST_ID_REQUIRED'; END IF;
  IF EXISTS (SELECT 1 FROM public.audit_logs WHERE request_id=p_request_id AND action='ANIMAL_DELETED' AND result='success') THEN
    RETURN jsonb_build_object('ok',true,'replayed',true,'effect_key',v_key);
  END IF;
  SELECT * INTO v_row FROM public.name_animation_catalog WHERE effect_key=v_key FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ANIMATION_NOT_FOUND'; END IF;
  DELETE FROM public.user_name_animation_effects WHERE effect_key=v_key;
  DELETE FROM public.name_animation_catalog WHERE effect_key=v_key;
  INSERT INTO public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  VALUES(v_uid,v_uid,'ANIMAL_DELETED','name_animation_catalog',v_key,v_key,p_request_id,'success',jsonb_build_object('deleted_row',to_jsonb(v_row)));
  RETURN jsonb_build_object('ok',true,'effect_key',v_key,'storage_path',v_row.storage_path);
END; $$;
REVOKE ALL ON FUNCTION public.admin_delete_name_animation(text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_name_animation(text,uuid) TO authenticated;

-- Aggregated admin profile viewer for the "gift" flow: identity + location +
-- everything this user owns or has active, in one call.
CREATE OR REPLACE FUNCTION public.admin_get_user_full_profile(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_uid uuid := auth.uid();
  r public.profiles%rowtype;
  v_effect text;
  v_animal jsonb;
  v_badge jsonb;
  v_title jsonb;
  v_animations jsonb;
  v_vip jsonb;
  v_cosmetics jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_user_id IS NULL THEN RAISE EXCEPTION 'USER_ID_REQUIRED'; END IF;

  SELECT * INTO r FROM public.profiles WHERE id = p_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'USER_NOT_FOUND'; END IF;

  SELECT gs.username_effect INTO v_effect FROM public.gamification_stats gs WHERE gs.user_id = p_user_id;
  v_animal := public.get_active_name_animation(p_user_id);
  v_badge := public.get_user_member_badge(p_user_id);
  v_title := public.get_user_title(p_user_id);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'effect_key', t.effect_key, 'name_ar', t.name_ar, 'is_owned', t.is_owned,
    'is_active', t.is_active, 'is_catalog_active', t.is_catalog_active
  ) ORDER BY t.is_owned DESC, t.effect_key), '[]'::jsonb)
  INTO v_animations
  FROM public.admin_get_user_name_animations(p_user_id) t
  WHERE t.is_owned = true;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'feature_key', c.feature_key, 'name_ar', c.name_ar, 'enabled', s.enabled, 'use_count', s.use_count
  ) ORDER BY c.sort_order), '[]'::jsonb)
  INTO v_vip
  FROM public.user_profile_services s
  JOIN public.profile_service_catalog c ON c.feature_key = s.feature_key
  WHERE s.user_id = p_user_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'item_key', pc.item_key, 'purchased_at', pc.purchased_at, 'currency', pc.currency, 'amount', pc.amount
  ) ORDER BY pc.purchased_at DESC), '[]'::jsonb)
  INTO v_cosmetics
  FROM public.profile_cosmetic_purchases pc
  WHERE pc.user_id = p_user_id;

  RETURN jsonb_build_object(
    'id', r.id, 'username', r.username, 'display_name', r.display_name, 'email', r.email,
    'avatar_url', r.avatar_url, 'verified', r.verified, 'is_suspended', r.is_suspended,
    'country', r.country, 'city', r.city, 'latitude', r.location_latitude, 'longitude', r.location_longitude,
    'location_updated_at', r.location_updated_at,
    'active_avatar_frame_key', r.avatar_frame_key, 'active_username_effect', coalesce(v_effect,'none'),
    'active_username_template_key', r.username_template_key, 'active_username_background_key', r.username_background_key,
    'active_name_animation', v_animal, 'active_member_badge', v_badge, 'active_title', v_title,
    'owned_name_animations', v_animations, 'vip_services', v_vip, 'profile_cosmetic_purchases', v_cosmetics
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_user_full_profile(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_get_user_full_profile(uuid) TO authenticated;

-- Server-driven store section metadata (name / icon / background / display mode).
CREATE TABLE IF NOT EXISTS public.chat_store_sections (
  section_key text PRIMARY KEY,
  name_ar text NOT NULL,
  icon_name text NOT NULL DEFAULT 'style',
  background_image_url text,
  display_mode text NOT NULL DEFAULT 'details' CHECK (display_mode IN ('details','small_icons','large_icons')),
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.chat_store_sections (section_key, name_ar, icon_name, sort_order) VALUES
  ('frames', 'الإطارات', 'photo_camera_back', 0),
  ('colored_frames', 'إطارات ملونة', 'palette', 1),
  ('name_background', 'خلفية إطار الاسم', 'wallpaper', 2),
  ('username_effects', 'تأثيرات اسم المستخدم', 'auto_awesome', 3),
  ('live_name', 'اسمك', 'badge', 4),
  ('message_colors', 'ألوان الرسائل', 'color_lens', 5),
  ('vip_services', 'خدمات VIP', 'workspace_premium', 6),
  ('name_templates', 'قالب الاسم', 'style', 7),
  ('name_animals', 'حيوانات فوق الاسم', 'pets', 8)
ON CONFLICT (section_key) DO NOTHING;

ALTER TABLE public.chat_store_sections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS chat_store_sections_read ON public.chat_store_sections;
CREATE POLICY chat_store_sections_read ON public.chat_store_sections
  FOR SELECT TO authenticated
  USING (is_active = true OR public.is_platform_owner(auth.uid()));

GRANT SELECT ON public.chat_store_sections TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.chat_store_sections TO service_role;

CREATE OR REPLACE FUNCTION public.get_chat_store_sections()
RETURNS SETOF public.chat_store_sections
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT * FROM public.chat_store_sections WHERE is_active = true ORDER BY sort_order, section_key;
$$;
REVOKE ALL ON FUNCTION public.get_chat_store_sections() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_chat_store_sections() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_update_chat_store_section(
  p_section_key text, p_name_ar text, p_icon_name text, p_background_image_url text,
  p_display_mode text, p_sort_order integer, p_is_active boolean, p_request_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid := auth.uid(); v_key text := lower(trim(coalesce(p_section_key,'')));
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'REQUEST_ID_REQUIRED'; END IF;
  IF v_key = '' THEN RAISE EXCEPTION 'SECTION_KEY_REQUIRED'; END IF;
  IF nullif(trim(coalesce(p_name_ar,'')),'') IS NULL THEN RAISE EXCEPTION 'NAME_REQUIRED'; END IF;
  IF coalesce(p_display_mode,'') NOT IN ('details','small_icons','large_icons') THEN RAISE EXCEPTION 'INVALID_DISPLAY_MODE'; END IF;
  IF EXISTS (SELECT 1 FROM public.audit_logs WHERE request_id=p_request_id AND action='STORE_SECTION_UPDATED' AND result='success') THEN
    RETURN jsonb_build_object('ok', true, 'replayed', true, 'section_key', v_key);
  END IF;
  INSERT INTO public.chat_store_sections (section_key, name_ar, icon_name, background_image_url, display_mode, sort_order, is_active, updated_at)
  VALUES (v_key, trim(p_name_ar), coalesce(nullif(trim(p_icon_name),''),'style'), nullif(trim(coalesce(p_background_image_url,'')),''), p_display_mode, coalesce(p_sort_order,0), coalesce(p_is_active,true), now())
  ON CONFLICT (section_key) DO UPDATE SET
    name_ar = excluded.name_ar, icon_name = excluded.icon_name, background_image_url = excluded.background_image_url,
    display_mode = excluded.display_mode, sort_order = excluded.sort_order, is_active = excluded.is_active, updated_at = now();
  INSERT INTO public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  VALUES (v_uid, v_uid, 'STORE_SECTION_UPDATED', 'chat_store_sections', v_key, v_key, p_request_id, 'success',
    jsonb_build_object('name_ar',p_name_ar,'icon_name',p_icon_name,'display_mode',p_display_mode,'sort_order',p_sort_order));
  RETURN jsonb_build_object('ok', true, 'section_key', v_key);
END; $$;
REVOKE ALL ON FUNCTION public.admin_update_chat_store_section(text,text,text,text,text,integer,boolean,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_update_chat_store_section(text,text,text,text,text,integer,boolean,uuid) TO authenticated;
