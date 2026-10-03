-- MASHAREENA: server-side GIF name animals + responsive display metadata + username font-size service.
BEGIN;

ALTER TABLE public.name_animation_catalog
  ADD COLUMN IF NOT EXISTS source_width integer,
  ADD COLUMN IF NOT EXISTS source_height integer,
  ADD COLUMN IF NOT EXISTS frame_count integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS render_effect text NOT NULL DEFAULT 'float_glow';

ALTER TABLE public.name_animation_catalog
  DROP CONSTRAINT IF EXISTS name_animation_catalog_frame_count_check;
ALTER TABLE public.name_animation_catalog
  ADD CONSTRAINT name_animation_catalog_frame_count_check CHECK (frame_count >= 1 AND frame_count <= 240);

ALTER TABLE public.name_animation_catalog
  DROP CONSTRAINT IF EXISTS name_animation_catalog_render_effect_check;
ALTER TABLE public.name_animation_catalog
  ADD CONSTRAINT name_animation_catalog_render_effect_check CHECK (render_effect IN ('none','float_glow','bounce_glow'));

UPDATE public.name_animation_catalog
SET source_width = COALESCE(source_width, (animation_json->>'w')::integer),
    source_height = COALESCE(source_height, (animation_json->>'h')::integer),
    frame_count = CASE WHEN (metadata->>'frame_count') ~ '^[0-9]+$' THEN GREATEST(1, LEAST(240, (metadata->>'frame_count')::integer)) ELSE frame_count END,
    render_effect = COALESCE(NULLIF(metadata->>'render_effect',''),'float_glow')
WHERE animation_type = 'lottie';

UPDATE storage.buckets
SET public = true,
    file_size_limit = 8 * 1024 * 1024,
    allowed_mime_types = ARRAY['application/json','text/json','image/gif']::text[]
WHERE id='name-animations';

DROP POLICY IF EXISTS name_animations_owner_insert ON storage.objects;
CREATE POLICY name_animations_owner_insert ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id='name-animations'
  AND (storage.foldername(name))[1]='catalog'
  AND lower(storage.extension(name)) IN ('json','gif')
  AND private.is_platform_owner_storage()
);

DROP POLICY IF EXISTS name_animations_owner_update ON storage.objects;
CREATE POLICY name_animations_owner_update ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id='name-animations' AND private.is_platform_owner_storage())
WITH CHECK (
  bucket_id='name-animations'
  AND private.is_platform_owner_storage()
  AND lower(storage.extension(name)) IN ('json','gif')
);

CREATE OR REPLACE FUNCTION public.admin_create_name_animation_asset(
  p_effect_key text,
  p_name_ar text,
  p_category text,
  p_asset_url text,
  p_storage_path text,
  p_size_bytes bigint,
  p_asset_type text,
  p_fps integer,
  p_duration_ms integer,
  p_source_width integer,
  p_source_height integer,
  p_frame_count integer,
  p_max_width double precision,
  p_max_height double precision,
  p_price_points bigint,
  p_price_gems bigint,
  p_owner_free boolean,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_key text := lower(trim(coalesce(p_effect_key,'')));
  v_type text := lower(trim(coalesce(p_asset_type,'')));
  v_sort integer;
  v_transparent boolean := true;
BEGIN
  IF v_uid IS NULL OR NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF v_key = '' OR v_key !~ '^[a-z0-9_]+$' THEN RAISE EXCEPTION 'INVALID_EFFECT_KEY'; END IF;
  IF trim(coalesce(p_name_ar,'')) = '' THEN RAISE EXCEPTION 'NAME_REQUIRED'; END IF;
  IF v_type NOT IN ('gif','json') THEN RAISE EXCEPTION 'INVALID_ASSET_TYPE'; END IF;
  IF p_asset_url IS NULL OR p_asset_url !~ '^https?://' THEN RAISE EXCEPTION 'INVALID_ASSET_URL'; END IF;
  IF p_storage_path IS NULL OR p_storage_path !~ '^catalog/[A-Za-z0-9_-]+\.(gif|json)$' THEN RAISE EXCEPTION 'INVALID_STORAGE_PATH'; END IF;
  IF p_size_bytes IS NULL OR p_size_bytes < 1 OR p_size_bytes > 8*1024*1024 THEN RAISE EXCEPTION 'INVALID_SIZE'; END IF;
  IF p_fps < 1 OR p_fps > 30 OR p_duration_ms < 1200 OR p_duration_ms > 2400 THEN RAISE EXCEPTION 'INVALID_ANIMATION_TIMING'; END IF;
  IF p_frame_count < 1 OR p_frame_count > 240 THEN RAISE EXCEPTION 'INVALID_FRAME_COUNT'; END IF;
  IF v_type='gif' AND (p_source_width IS NULL OR p_source_height IS NULL OR p_source_width < 1 OR p_source_height < 1 OR p_source_width > 2048 OR p_source_height > 2048) THEN
    RAISE EXCEPTION 'INVALID_GIF_DIMENSIONS';
  END IF;
  IF p_max_width < 24 OR p_max_width > 52 OR p_max_height < 20 OR p_max_height > 42 THEN RAISE EXCEPTION 'INVALID_ANIMATION_BOUNDS'; END IF;
  IF p_price_points < 0 OR p_price_gems < 0 THEN RAISE EXCEPTION 'INVALID_PRICE'; END IF;

  SELECT coalesce(max(sort_order),0)+1 INTO v_sort FROM public.name_animation_catalog;

  INSERT INTO public.name_animation_catalog(
    effect_key,name_ar,category,asset_url,storage_path,size_bytes,animation_type,fps,duration_ms,
    max_width,max_height,transparent,loop,price_points,price_gems,owner_free,is_active,sort_order,
    metadata,source_width,source_height,frame_count,render_effect
  )
  VALUES (
    v_key,left(trim(p_name_ar),160),coalesce(nullif(trim(p_category),''),'animal'),p_asset_url,p_storage_path,
    p_size_bytes,v_type,p_fps,p_duration_ms,p_max_width,p_max_height,v_transparent,true,
    p_price_points,p_price_gems,coalesce(p_owner_free,false),true,v_sort,coalesce(p_metadata,'{}'::jsonb),
    p_source_width,p_source_height,p_frame_count,'float_glow'
  )
  ON CONFLICT(effect_key) DO UPDATE SET
    name_ar=excluded.name_ar,category=excluded.category,asset_url=excluded.asset_url,storage_path=excluded.storage_path,
    size_bytes=excluded.size_bytes,animation_type=excluded.animation_type,fps=excluded.fps,duration_ms=excluded.duration_ms,
    max_width=excluded.max_width,max_height=excluded.max_height,transparent=excluded.transparent,loop=excluded.loop,
    price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,
    metadata=excluded.metadata,source_width=excluded.source_width,source_height=excluded.source_height,
    frame_count=excluded.frame_count,render_effect=excluded.render_effect,updated_at=now();

  RETURN jsonb_build_object('ok',true,'effect_key',v_key,'asset_type',v_type,'source_width',p_source_width,'source_height',p_source_height,'frame_count',p_frame_count);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_create_name_animation_asset(text,text,text,text,text,bigint,text,integer,integer,integer,integer,integer,double precision,double precision,bigint,bigint,boolean,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_create_name_animation_asset(text,text,text,text,text,bigint,text,integer,integer,integer,integer,integer,double precision,double precision,bigint,bigint,boolean,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_active_name_animation(p_user_id uuid)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
  SELECT CASE WHEN c.effect_key IS NULL THEN NULL ELSE jsonb_build_object(
    'effect_key',c.effect_key,'name_ar',c.name_ar,'category',c.category,'asset_path',c.asset_path,
    'asset_url',c.asset_url,'storage_path',c.storage_path,'size_bytes',c.size_bytes,
    'animation_type',c.animation_type,'fps',c.fps,'duration_ms',c.duration_ms,'max_width',c.max_width,
    'max_height',c.max_height,'transparent',c.transparent,'loop',c.loop,'price_points',c.price_points,
    'price_gems',c.price_gems,'owner_free',c.owner_free,'is_active',c.is_active,'sort_order',c.sort_order,
    'metadata',c.metadata,'animation_json',c.animation_json,'source_width',c.source_width,'source_height',c.source_height,
    'frame_count',c.frame_count,'render_effect',c.render_effect
  ) END
  FROM public.user_name_animation_effects e
  JOIN public.name_animation_catalog c ON c.effect_key=e.effect_key AND c.is_active=true
  WHERE e.user_id=p_user_id AND e.is_active=true
  LIMIT 1;
$$;

-- Enforce the purchased VIP/service gate on server before changing name size.
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_username_font_size_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_username_font_size_check CHECK (username_font_size >= 10 AND username_font_size <= 26);

CREATE OR REPLACE FUNCTION public.set_my_username_font_size(p_font_size numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path='public'
AS $$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF p_font_size IS NULL OR p_font_size < 10 OR p_font_size > 26 THEN RAISE EXCEPTION 'USERNAME_FONT_SIZE_OUT_OF_RANGE'; END IF;
  IF NOT public.is_platform_owner(v_uid) AND NOT EXISTS (
    SELECT 1 FROM public.user_profile_services ups
    WHERE ups.user_id=v_uid AND ups.feature_key='username_font_size' AND ups.enabled=true
  ) THEN
    RAISE EXCEPTION 'PROFILE_SERVICE_REQUIRED';
  END IF;
  UPDATE public.profiles SET username_font_size=round(p_font_size,1),updated_at=now() WHERE id=v_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'PROFILE_NOT_FOUND'; END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.set_my_username_font_size(numeric) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.set_my_username_font_size(numeric) TO authenticated;

INSERT INTO public.profile_service_catalog(feature_key,name_ar,description_ar,category,price_points,price_gems,is_active,sort_order,usage_surface,usage_hint_ar,icon_key,action_key,runtime_surface)
VALUES('username_font_size','تصغير حجم اسم المستخدم','التحكم في حجم اسم المستخدم وحفظه خادميًا ليطبّق على البروفايل والشات.','profile_services',600,6,true,121,'both','تصغير/تكبير اسم المستخدم على الخادم','format_size','configure_service','profile')
ON CONFLICT(feature_key) DO UPDATE SET
  name_ar=excluded.name_ar,description_ar=excluded.description_ar,price_points=excluded.price_points,price_gems=excluded.price_gems,
  is_active=true,sort_order=excluded.sort_order,usage_surface=excluded.usage_surface,usage_hint_ar=excluded.usage_hint_ar,
  icon_key=excluded.icon_key,action_key=excluded.action_key,runtime_surface=excluded.runtime_surface,updated_at=now();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='name_animation_catalog'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.name_animation_catalog;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='user_name_animation_effects'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_name_animation_effects;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='user_profile_services'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_profile_services;
  END IF;
END $$;

COMMIT;
