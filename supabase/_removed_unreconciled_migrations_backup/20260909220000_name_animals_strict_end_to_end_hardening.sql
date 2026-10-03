BEGIN;

-- Never use a destructive catalog reset here. Existing ownership must survive future deploys.
-- Preserve legacy catalog rows, but keep unusable legacy/non-GIF animal rows out of the store.
UPDATE public.name_animation_catalog
SET is_active=false, updated_at=now()
WHERE category='animal'
  AND (lower(coalesce(animation_type,'')) <> 'gif' OR nullif(trim(coalesce(storage_path,'')),'') IS NULL);

UPDATE public.name_animation_catalog
SET max_width=LEAST(46, GREATEST(24, coalesce(max_width,44))),
    max_height=LEAST(32, GREATEST(18, coalesce(max_height,30))),
    render_effect=CASE WHEN render_effect IN ('none','float_glow','bounce_glow') THEN render_effect ELSE 'float_glow' END,
    updated_at=now()
WHERE category='animal'
  AND lower(coalesce(animation_type,''))='gif'
  AND nullif(trim(coalesce(storage_path,'')),'') IS NOT NULL;

UPDATE storage.buckets
SET public=true,
    file_size_limit=8*1024*1024,
    allowed_mime_types=ARRAY['image/gif']::text[]
WHERE id='name-animations';

DROP POLICY IF EXISTS name_animations_owner_insert ON storage.objects;
CREATE POLICY name_animations_owner_insert ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id='name-animations'
  AND (storage.foldername(name))[1]='catalog'
  AND lower(storage.extension(name))='gif'
  AND private.is_platform_owner_storage()
);

DROP POLICY IF EXISTS name_animations_owner_update ON storage.objects;
CREATE POLICY name_animations_owner_update ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id='name-animations' AND private.is_platform_owner_storage())
WITH CHECK (
  bucket_id='name-animations'
  AND (storage.foldername(name))[1]='catalog'
  AND lower(storage.extension(name))='gif'
  AND private.is_platform_owner_storage()
);

DROP POLICY IF EXISTS name_animations_owner_delete ON storage.objects;
CREATE POLICY name_animations_owner_delete ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id='name-animations' AND private.is_platform_owner_storage());

CREATE OR REPLACE FUNCTION public.admin_update_name_animation(
  p_effect_key text,
  p_name_ar text,
  p_price_points bigint,
  p_price_gems bigint,
  p_owner_free boolean,
  p_is_active boolean,
  p_sort_order integer,
  p_render_effect text,
  p_request_id uuid
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_uid uuid:=auth.uid();
  v_key text:=lower(trim(coalesce(p_effect_key,'')));
  v_old public.name_animation_catalog%rowtype;
  v_new public.name_animation_catalog%rowtype;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'REQUEST_ID_REQUIRED'; END IF;
  IF EXISTS (SELECT 1 FROM public.audit_logs WHERE request_id=p_request_id AND action='ANIMAL_UPDATED' AND result='success') THEN
    RETURN jsonb_build_object('ok',true,'replayed',true,'effect_key',v_key);
  END IF;
  SELECT * INTO v_old FROM public.name_animation_catalog WHERE effect_key=v_key FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ANIMATION_NOT_FOUND'; END IF;
  IF nullif(trim(p_name_ar),'') IS NULL THEN RAISE EXCEPTION 'NAME_REQUIRED'; END IF;
  IF coalesce(p_price_points,-1)<0 OR coalesce(p_price_gems,-1)<0 THEN RAISE EXCEPTION 'INVALID_PRICE'; END IF;
  IF coalesce(p_sort_order,-1)<0 THEN RAISE EXCEPTION 'INVALID_SORT_ORDER'; END IF;
  IF coalesce(p_render_effect,'') NOT IN ('none','float_glow','bounce_glow') THEN RAISE EXCEPTION 'INVALID_RENDER_EFFECT'; END IF;
  UPDATE public.name_animation_catalog SET
    name_ar=left(trim(p_name_ar),160),price_points=p_price_points,price_gems=p_price_gems,owner_free=coalesce(p_owner_free,false),
    is_active=coalesce(p_is_active,false),sort_order=p_sort_order,render_effect=p_render_effect,updated_at=now()
  WHERE effect_key=v_key;
  SELECT * INTO v_new FROM public.name_animation_catalog WHERE effect_key=v_key;
  INSERT INTO public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  VALUES(v_uid,v_uid,'ANIMAL_UPDATED','name_animation_catalog',v_key,v_key,p_request_id,'success',jsonb_build_object('old',to_jsonb(v_old),'new',to_jsonb(v_new)));
  RETURN jsonb_build_object('ok',true,'effect_key',v_key);
END; $$;

CREATE OR REPLACE FUNCTION public.admin_set_name_animation_active(p_effect_key text,p_is_active boolean,p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_key text:=lower(trim(coalesce(p_effect_key,''))); v_old public.name_animation_catalog%rowtype;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'REQUEST_ID_REQUIRED'; END IF;
  IF EXISTS (SELECT 1 FROM public.audit_logs WHERE request_id=p_request_id AND action IN ('ANIMAL_ENABLED','ANIMAL_DISABLED') AND result='success') THEN
    RETURN jsonb_build_object('ok',true,'replayed',true,'effect_key',v_key);
  END IF;
  SELECT * INTO v_old FROM public.name_animation_catalog WHERE effect_key=v_key FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ANIMATION_NOT_FOUND'; END IF;
  UPDATE public.name_animation_catalog SET is_active=coalesce(p_is_active,false),updated_at=now() WHERE effect_key=v_key;
  INSERT INTO public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  VALUES(v_uid,v_uid,CASE WHEN coalesce(p_is_active,false) THEN 'ANIMAL_ENABLED' ELSE 'ANIMAL_DISABLED' END,'name_animation_catalog',v_key,v_key,p_request_id,'success',jsonb_build_object('old_active',v_old.is_active,'new_active',coalesce(p_is_active,false)));
  RETURN jsonb_build_object('ok',true,'effect_key',v_key,'is_active',coalesce(p_is_active,false));
END; $$;

CREATE OR REPLACE FUNCTION public.admin_check_name_animals()
RETURNS TABLE(effect_key text,status text,storage_path text,is_active boolean,asset_url text,source_width integer,source_height integer,frame_count integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(auth.uid()) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  RETURN QUERY
  SELECT c.effect_key,
         CASE
           WHEN c.storage_path IS NULL OR c.storage_path='' THEN 'MISSING_ASSET'
           WHEN c.asset_url IS NULL OR c.asset_url='' THEN 'INVALID_URL'
           ELSE 'VALID'
         END,
         c.storage_path,c.is_active,c.asset_url,c.source_width,c.source_height,c.frame_count
  FROM public.name_animation_catalog c
  WHERE c.category='animal'
  ORDER BY c.sort_order,c.effect_key;
END; $$;

CREATE OR REPLACE FUNCTION public.repair_my_active_name_animation()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_key text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT e.effect_key INTO v_key
  FROM public.user_name_animation_effects e
  JOIN public.name_animation_catalog c ON c.effect_key=e.effect_key
  WHERE e.user_id=v_uid AND e.is_active=true AND c.is_active=true AND c.animation_type='gif' AND c.storage_path IS NOT NULL
  LIMIT 1;
  IF v_key IS NULL THEN
    UPDATE public.user_name_animation_effects SET is_active=false,activated_at=null WHERE user_id=v_uid AND is_active=true;
    RETURN jsonb_build_object('ok',true,'effect_key',null,'repaired',true);
  END IF;
  UPDATE public.user_name_animation_effects SET is_active=false,activated_at=null WHERE user_id=v_uid AND is_active=true AND effect_key<>v_key;
  RETURN jsonb_build_object('ok',true,'effect_key',v_key,'repaired',false);
END; $$;

CREATE OR REPLACE FUNCTION public.admin_get_user_name_animations(p_user_id uuid)
RETURNS TABLE(effect_key text,name_ar text,is_owned boolean,is_active boolean,storage_path text,asset_url text,is_catalog_active boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(auth.uid()) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_user_id IS NULL THEN RAISE EXCEPTION 'USER_ID_REQUIRED'; END IF;
  RETURN QUERY
  SELECT c.effect_key,c.name_ar,(e.user_id IS NOT NULL),coalesce(e.is_active,false),c.storage_path,c.asset_url,c.is_active
  FROM public.name_animation_catalog c
  LEFT JOIN public.user_name_animation_effects e ON e.effect_key=c.effect_key AND e.user_id=p_user_id
  WHERE c.category='animal'
  ORDER BY c.sort_order,c.effect_key;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_force_user_name_animation(p_user_id uuid,p_effect_key text,p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_key text:=lower(trim(coalesce(p_effect_key,'')));
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'REQUEST_ID_REQUIRED'; END IF;
  IF p_user_id IS NULL THEN RAISE EXCEPTION 'USER_ID_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=p_user_id) THEN RAISE EXCEPTION 'USER_NOT_FOUND'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.name_animation_catalog WHERE effect_key=v_key AND is_active=true AND animation_type='gif') THEN RAISE EXCEPTION 'ANIMATION_NOT_AVAILABLE'; END IF;
  UPDATE public.user_name_animation_effects SET is_active=false,activated_at=null WHERE user_id=p_user_id;
  INSERT INTO public.user_name_animation_effects(user_id,effect_key,is_active,activated_at)
  VALUES(p_user_id,v_key,true,now())
  ON CONFLICT(user_id,effect_key) DO UPDATE SET is_active=true,activated_at=excluded.activated_at;
  INSERT INTO public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  VALUES(v_uid,v_uid,'ANIMAL_FORCE_EQUIP','user_name_animation_effects',v_key,p_user_id::text,p_request_id,'success',jsonb_build_object('user_id',p_user_id,'effect_key',v_key));
  RETURN jsonb_build_object('ok',true,'user_id',p_user_id,'effect_key',v_key);
END; $$;

CREATE OR REPLACE FUNCTION public.admin_clear_user_name_animation(p_user_id uuid,p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'REQUEST_ID_REQUIRED'; END IF;
  UPDATE public.user_name_animation_effects SET is_active=false,activated_at=null WHERE user_id=p_user_id;
  INSERT INTO public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
  VALUES(v_uid,v_uid,'ANIMAL_FORCE_CLEAR','user_name_animation_effects',p_user_id::text,p_user_id::text,p_request_id,'success',jsonb_build_object('user_id',p_user_id));
  RETURN jsonb_build_object('ok',true,'user_id',p_user_id,'effect_key',null);
END; $$;

REVOKE ALL ON FUNCTION public.admin_update_name_animation(text,text,bigint,bigint,boolean,boolean,integer,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_update_name_animation(text,text,bigint,bigint,boolean,boolean,integer,text,uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_set_name_animation_active(text,boolean,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_set_name_animation_active(text,boolean,uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_check_name_animals() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_check_name_animals() TO authenticated;
REVOKE ALL ON FUNCTION public.repair_my_active_name_animation() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.repair_my_active_name_animation() TO authenticated;
REVOKE ALL ON FUNCTION public.admin_get_user_name_animations(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_get_user_name_animations(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_force_user_name_animation(uuid,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_force_user_name_animation(uuid,text,uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_clear_user_name_animation(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_clear_user_name_animation(uuid,uuid) TO authenticated;

COMMIT;
