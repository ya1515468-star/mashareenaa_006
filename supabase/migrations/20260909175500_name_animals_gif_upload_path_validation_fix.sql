CREATE OR REPLACE FUNCTION public.admin_create_name_animation_asset(
  p_effect_key text,p_name_ar text,p_category text,p_asset_url text,p_storage_path text,p_size_bytes bigint,p_asset_type text,
  p_fps integer,p_duration_ms integer,p_source_width integer,p_source_height integer,p_frame_count integer,p_max_width double precision,
  p_max_height double precision,p_price_points bigint,p_price_gems bigint,p_owner_free boolean,p_metadata jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_key text := lower(trim(coalesce(p_effect_key,'')));
  v_type text := lower(trim(coalesce(p_asset_type,'')));
  v_file text := split_part(coalesce(p_storage_path,''), '/', 2);
  v_sort integer;
BEGIN
  IF v_uid IS NULL OR NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF v_key = '' OR v_key !~ '^[a-z0-9_]+$' THEN RAISE EXCEPTION 'INVALID_EFFECT_KEY'; END IF;
  IF trim(coalesce(p_name_ar,'')) = '' THEN RAISE EXCEPTION 'NAME_REQUIRED'; END IF;
  IF v_type <> 'gif' THEN RAISE EXCEPTION 'GIF_REQUIRED'; END IF;
  IF p_asset_url IS NULL OR p_asset_url !~ '^https?://' THEN RAISE EXCEPTION 'INVALID_ASSET_URL'; END IF;
  IF split_part(coalesce(p_storage_path,''), '/', 1) <> 'catalog'
     OR v_file = ''
     OR strpos(v_file, '/') > 0
     OR lower(right(v_file,4)) <> '.gif'
     OR v_file LIKE '%..%'
     OR v_file !~ '^[A-Za-z0-9_-]+[.]gif$' THEN
    RAISE EXCEPTION 'INVALID_STORAGE_PATH';
  END IF;
  IF p_size_bytes IS NULL OR p_size_bytes < 1 OR p_size_bytes > 8 * 1024 * 1024 THEN RAISE EXCEPTION 'INVALID_SIZE'; END IF;
  IF p_fps < 1 OR p_fps > 30 OR p_duration_ms < 1200 OR p_duration_ms > 2400 THEN RAISE EXCEPTION 'INVALID_ANIMATION_TIMING'; END IF;
  IF p_frame_count < 1 OR p_frame_count > 240 THEN RAISE EXCEPTION 'INVALID_FRAME_COUNT'; END IF;
  IF p_source_width IS NULL OR p_source_height IS NULL OR p_source_width < 1 OR p_source_height < 1 OR p_source_width > 2048 OR p_source_height > 2048 THEN RAISE EXCEPTION 'INVALID_GIF_DIMENSIONS'; END IF;
  IF p_price_points < 0 OR p_price_gems < 0 THEN RAISE EXCEPTION 'INVALID_PRICE'; END IF;
  SELECT coalesce(max(sort_order),0)+1 INTO v_sort FROM public.name_animation_catalog;
  INSERT INTO public.name_animation_catalog(
    effect_key,name_ar,category,asset_url,storage_path,size_bytes,animation_type,fps,duration_ms,max_width,max_height,
    transparent,loop,price_points,price_gems,owner_free,is_active,sort_order,metadata,source_width,source_height,frame_count,render_effect)
  VALUES(
    v_key,left(trim(p_name_ar),160),'animal',p_asset_url,p_storage_path,p_size_bytes,'gif',p_fps,p_duration_ms,44,30,true,true,
    p_price_points,p_price_gems,coalesce(p_owner_free,false),true,v_sort,
    jsonb_build_object('placement','above_name','anchor','bottom_center','source_width',p_source_width,'source_height',p_source_height,'frame_count',p_frame_count,'render_effect','float_glow','source_format','gif') || coalesce(p_metadata,'{}'::jsonb),
    p_source_width,p_source_height,p_frame_count,'float_glow')
  ON CONFLICT(effect_key) DO UPDATE SET
    name_ar=excluded.name_ar,category=excluded.category,asset_url=excluded.asset_url,storage_path=excluded.storage_path,size_bytes=excluded.size_bytes,
    animation_type='gif',fps=excluded.fps,duration_ms=excluded.duration_ms,max_width=44,max_height=30,transparent=true,loop=true,
    price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,metadata=excluded.metadata,
    source_width=excluded.source_width,source_height=excluded.source_height,frame_count=excluded.frame_count,render_effect='float_glow',updated_at=now();
  RETURN jsonb_build_object('ok',true,'effect_key',v_key,'asset_type','gif','storage_path',p_storage_path,'source_width',p_source_width,'source_height',p_source_height,'frame_count',p_frame_count,'max_width',44,'max_height',30);
END; $$;
REVOKE ALL ON FUNCTION public.admin_create_name_animation_asset(text,text,text,text,text,bigint,text,integer,integer,integer,integer,integer,double precision,double precision,bigint,bigint,boolean,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_create_name_animation_asset(text,text,text,text,text,bigint,text,integer,integer,integer,integer,integer,double precision,double precision,bigint,bigint,boolean,jsonb) TO authenticated;
