-- Applied LIVE and verified against project aknksnctyqjcsxcwnvdz (mashareena_v2) on 2026-09-13.
-- Extends the "edit/delete/gift" pattern (built for name animations earlier)
-- to the shared profile_cosmetic_catalog table, which covers frames,
-- backgrounds, name effects, message colors, and name templates all at
-- once, plus a separate gift path for VIP profile services.

CREATE OR REPLACE FUNCTION public.admin_update_profile_cosmetic(
  p_item_key text, p_name_ar text, p_price_points bigint, p_price_gems bigint,
  p_is_active boolean, p_sort_order integer, p_request_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid := auth.uid(); v_key text := lower(trim(coalesce(p_item_key,''))); v_old public.profile_cosmetic_catalog%rowtype;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'REQUEST_ID_REQUIRED'; END IF;
  IF EXISTS (SELECT 1 FROM public.audit_logs WHERE request_id=p_request_id AND action='PROFILE_COSMETIC_UPDATED' AND result='success') THEN
    RETURN jsonb_build_object('ok',true,'replayed',true,'item_key',v_key);
  END IF;
  SELECT * INTO v_old FROM public.profile_cosmetic_catalog WHERE item_key=v_key FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ITEM_NOT_FOUND'; END IF;
  IF nullif(trim(coalesce(p_name_ar,'')),'') IS NULL THEN RAISE EXCEPTION 'NAME_REQUIRED'; END IF;
  IF coalesce(p_price_points,-1)<0 OR coalesce(p_price_gems,-1)<0 THEN RAISE EXCEPTION 'INVALID_PRICE'; END IF;
  IF coalesce(p_sort_order,-1)<0 THEN RAISE EXCEPTION 'INVALID_SORT_ORDER'; END IF;
  UPDATE public.profile_cosmetic_catalog SET
    name_ar=left(trim(p_name_ar),160), price_points=p_price_points, price_gems=p_price_gems,
    is_active=coalesce(p_is_active,false), sort_order=p_sort_order, updated_at=now()
  WHERE item_key=v_key;
  IF v_old.category='frame' THEN
    UPDATE public.avatar_frame_catalog SET name_ar=left(trim(p_name_ar),160), sort_order=p_sort_order, updated_at=now() WHERE frame_key=v_key;
  END IF;
  INSERT INTO public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  VALUES(v_uid,v_uid,'PROFILE_COSMETIC_UPDATED','profile_cosmetic_catalog',v_key,v_key,p_request_id,'success',
    jsonb_build_object('category',v_old.category,'old',to_jsonb(v_old),'name_ar',p_name_ar,'price_points',p_price_points,'price_gems',p_price_gems,'is_active',p_is_active,'sort_order',p_sort_order));
  RETURN jsonb_build_object('ok',true,'item_key',v_key);
END; $$;
REVOKE ALL ON FUNCTION public.admin_update_profile_cosmetic(text,text,bigint,bigint,boolean,integer,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_update_profile_cosmetic(text,text,bigint,bigint,boolean,integer,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_delete_profile_cosmetic(p_item_key text, p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid := auth.uid(); v_key text := lower(trim(coalesce(p_item_key,''))); v_row public.profile_cosmetic_catalog%rowtype;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'REQUEST_ID_REQUIRED'; END IF;
  IF EXISTS (SELECT 1 FROM public.audit_logs WHERE request_id=p_request_id AND action='PROFILE_COSMETIC_DELETED' AND result='success') THEN
    RETURN jsonb_build_object('ok',true,'replayed',true,'item_key',v_key);
  END IF;
  SELECT * INTO v_row FROM public.profile_cosmetic_catalog WHERE item_key=v_key FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ITEM_NOT_FOUND'; END IF;
  IF v_row.category='frame' THEN RAISE EXCEPTION 'USE_FRAME_DELETE_FUNCTION'; END IF;
  IF v_row.category='background' THEN UPDATE public.profiles SET username_background_key=NULL WHERE username_background_key=v_key; END IF;
  IF v_row.category='name_effect' THEN UPDATE public.gamification_stats SET username_effect='none' WHERE username_effect=v_key; END IF;
  IF v_row.category='message_color' THEN UPDATE public.profiles SET message_color_key=NULL WHERE message_color_key=v_key; END IF;
  IF v_row.category='name_template' THEN UPDATE public.profiles SET username_template_key=NULL WHERE username_template_key=v_key; END IF;
  DELETE FROM public.profile_cosmetic_purchases WHERE item_key=v_key;
  DELETE FROM public.profile_cosmetic_catalog WHERE item_key=v_key;
  INSERT INTO public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  VALUES(v_uid,v_uid,'PROFILE_COSMETIC_DELETED','profile_cosmetic_catalog',v_key,v_key,p_request_id,'success',jsonb_build_object('deleted_row',to_jsonb(v_row)));
  RETURN jsonb_build_object('ok',true,'item_key',v_key);
END; $$;
REVOKE ALL ON FUNCTION public.admin_delete_profile_cosmetic(text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_profile_cosmetic(text,uuid) TO authenticated;

-- Note: currency markers use 'owner_free' / 'owner_access' because those are
-- the only special values the pre-existing CHECK constraints on
-- profile_cosmetic_purchases / user_profile_services allow — confirmed live
-- after an initial attempt with 'owner_gift' was rejected by the database.
CREATE OR REPLACE FUNCTION public.admin_force_user_profile_cosmetic(p_user_id uuid, p_item_key text, p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid := auth.uid(); v_key text := lower(trim(coalesce(p_item_key,'')));
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'REQUEST_ID_REQUIRED'; END IF;
  IF p_user_id IS NULL THEN RAISE EXCEPTION 'USER_ID_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=p_user_id) THEN RAISE EXCEPTION 'USER_NOT_FOUND'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profile_cosmetic_catalog WHERE item_key=v_key AND is_active=true) THEN RAISE EXCEPTION 'ITEM_NOT_FOUND'; END IF;
  INSERT INTO public.profile_cosmetic_purchases(user_id, item_key, currency, amount)
  VALUES (p_user_id, v_key, 'owner_free', 0)
  ON CONFLICT (user_id, item_key) DO NOTHING;
  INSERT INTO public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  VALUES (v_uid, v_uid, 'PROFILE_COSMETIC_GIFTED', 'profile_cosmetic_catalog', v_key, p_user_id::text, p_request_id, 'success', jsonb_build_object('user_id',p_user_id,'item_key',v_key));
  RETURN jsonb_build_object('ok', true, 'user_id', p_user_id, 'item_key', v_key);
END; $$;
REVOKE ALL ON FUNCTION public.admin_force_user_profile_cosmetic(uuid,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_force_user_profile_cosmetic(uuid,text,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_force_user_profile_service(p_user_id uuid, p_feature_key text, p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid := auth.uid(); v_key text := lower(trim(coalesce(p_feature_key,'')));
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'REQUEST_ID_REQUIRED'; END IF;
  IF p_user_id IS NULL THEN RAISE EXCEPTION 'USER_ID_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=p_user_id) THEN RAISE EXCEPTION 'USER_NOT_FOUND'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profile_service_catalog WHERE feature_key=v_key AND is_active=true) THEN RAISE EXCEPTION 'ITEM_NOT_FOUND'; END IF;
  INSERT INTO public.user_profile_services(user_id, feature_key, currency, amount, enabled, purchased_at, updated_at)
  VALUES (p_user_id, v_key, 'owner_access', 0, true, now(), now())
  ON CONFLICT (user_id, feature_key) DO UPDATE SET enabled = true, updated_at = now();
  INSERT INTO public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  VALUES (v_uid, v_uid, 'PROFILE_SERVICE_GIFTED', 'user_profile_services', v_key, p_user_id::text, p_request_id, 'success', jsonb_build_object('user_id',p_user_id,'feature_key',v_key));
  RETURN jsonb_build_object('ok', true, 'user_id', p_user_id, 'feature_key', v_key);
END; $$;
REVOKE ALL ON FUNCTION public.admin_force_user_profile_service(uuid,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_force_user_profile_service(uuid,text,uuid) TO authenticated;
