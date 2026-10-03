-- Avatar-frame RPC alignment.
-- Keeps the legacy 11-argument RPC as a compatibility wrapper while making
-- the canonical 13-argument RPC accept GIF + static common image formats.

BEGIN;

CREATE OR REPLACE FUNCTION public.admin_create_avatar_frame(
  p_frame_key text,
  p_name_ar text,
  p_gender text,
  p_asset_url text,
  p_storage_path text,
  p_duration_ms integer,
  p_price_points bigint,
  p_price_gems bigint,
  p_allowed_role_codes text[] DEFAULT '{}'::text[],
  p_min_rank_level integer DEFAULT 0,
  p_max_rank_level integer DEFAULT NULL::integer,
  p_animation_mode text DEFAULT 'gif'::text,
  p_frame_effect text DEFAULT 'custom'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_key text := lower(trim(coalesce(p_frame_key,'')));
  v_name text := left(trim(coalesce(p_name_ar,'')),160);
  v_gender text := lower(trim(coalesce(p_gender,'unisex')));
  v_roles text[] := coalesce(p_allowed_role_codes,'{}'::text[]);
  v_mode text := lower(trim(coalesce(p_animation_mode,'gif')));
  v_effect text := left(trim(coalesce(p_frame_effect,'custom')),40);
  v_storage_ext text := lower(reverse(split_part(reverse(trim(coalesce(p_storage_path,''))), '.', 1)));
  v_sort integer;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF v_key='' THEN RAISE EXCEPTION 'FRAME_KEY_REQUIRED'; END IF;
  IF v_name='' THEN RAISE EXCEPTION 'FRAME_NAME_REQUIRED'; END IF;

  IF v_gender IN ('men','man','male','رجال','ذكر','ذكور') THEN
    v_gender := 'male';
  ELSIF v_gender IN ('women','woman','female','نساء','انثى','إناث','أنثى') THEN
    v_gender := 'female';
  ELSIF v_gender IN ('unisex','all','للجميع','both','مشترك','') THEN
    v_gender := 'unisex';
  ELSE
    RAISE EXCEPTION 'INVALID_GENDER';
  END IF;

  IF v_mode NOT IN ('gif','static_effect') THEN
    RAISE EXCEPTION 'INVALID_ANIMATION_MODE';
  END IF;
  IF v_effect='' THEN
    v_effect := CASE WHEN v_mode='static_effect' THEN 'pulse_glow' ELSE 'custom' END;
  END IF;

  IF v_storage_ext NOT IN ('gif','png','jpg','jpeg','webp','bmp') THEN
    RAISE EXCEPTION 'INVALID_STORAGE_PATH';
  END IF;
  IF trim(coalesce(p_storage_path,'')) !~ '^catalog/[A-Za-z0-9_-]+[.](gif|png|jpg|jpeg|webp|bmp)$' THEN
    RAISE EXCEPTION 'INVALID_STORAGE_PATH';
  END IF;
  IF (v_mode='gif' AND v_storage_ext <> 'gif')
     OR (v_mode='static_effect' AND v_storage_ext NOT IN ('png','jpg','jpeg','webp','bmp')) THEN
    RAISE EXCEPTION 'ANIMATION_MODE_STORAGE_MISMATCH';
  END IF;

  IF p_duration_ms IS NULL OR p_duration_ms < 1 OR p_duration_ms > 120000 THEN
    RAISE EXCEPTION 'INVALID_DURATION';
  END IF;
  IF p_price_points IS NULL OR p_price_points < 0
     OR p_price_gems IS NULL OR p_price_gems < 0 THEN
    RAISE EXCEPTION 'INVALID_PRICE';
  END IF;
  IF p_min_rank_level IS NULL OR p_min_rank_level < 0
     OR (p_max_rank_level IS NOT NULL AND p_max_rank_level < p_min_rank_level) THEN
    RAISE EXCEPTION 'INVALID_RANK_RANGE';
  END IF;
  IF p_asset_url IS NULL OR p_asset_url !~ '^https?://' THEN
    RAISE EXCEPTION 'INVALID_ASSET_URL';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM unnest(v_roles) r(code)
    LEFT JOIN public.roles rr ON lower(rr.code)=lower(trim(r.code))
    WHERE nullif(trim(r.code),'') IS NOT NULL
      AND rr.id IS NULL
  ) THEN
    RAISE EXCEPTION 'INVALID_ROLE_CODE';
  END IF;

  SELECT coalesce(max(sort_order),0)+1
    INTO v_sort
    FROM public.avatar_frame_catalog;

  INSERT INTO public.avatar_frame_catalog(
    frame_key, gender, name_ar, sort_order, animation_mode, palette_key,
    min_rank_level, max_rank_level, allowed_role_codes, is_active,
    asset_url, storage_path, duration_ms, created_at, updated_at
  )
  VALUES(
    v_key, v_gender, v_name, v_sort, v_mode, v_effect,
    p_min_rank_level, p_max_rank_level, v_roles, true,
    p_asset_url, p_storage_path, p_duration_ms, now(), now()
  );

  INSERT INTO public.profile_cosmetic_catalog(
    item_key, category, gender, name_ar, animation_mode, palette_key,
    mode_variant, color1, color2, price_points, price_gems, owner_free,
    is_active, sort_order, metadata, created_at, updated_at
  )
  VALUES(
    v_key, 'frame', v_gender, v_name, v_mode, v_effect,
    'remote', '#FFFFFF', NULL, p_price_points, p_price_gems, true,
    true, v_sort,
    jsonb_build_object(
      'frame_key', v_key,
      'asset_url', p_asset_url,
      'storage_path', p_storage_path,
      'duration_ms', p_duration_ms,
      'allowed_role_codes', v_roles,
      'min_rank_level', p_min_rank_level,
      'max_rank_level', p_max_rank_level,
      'animation_mode', v_mode,
      'frame_effect', v_effect
    ),
    now(), now()
  );

  RETURN jsonb_build_object(
    'ok', true,
    'frame_key', v_key,
    'gender', v_gender,
    'sort_order', v_sort,
    'price_points', p_price_points,
    'price_gems', p_price_gems,
    'duration_ms', p_duration_ms,
    'animation_mode', v_mode,
    'frame_effect', v_effect
  );
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'FRAME_ALREADY_EXISTS';
END;
$function$;

-- Legacy callers remain supported. The wrapper derives animation mode from the
-- actual storage extension instead of requiring .gif for every frame.
CREATE OR REPLACE FUNCTION public.admin_create_avatar_frame(
  p_frame_key text,
  p_name_ar text,
  p_gender text,
  p_asset_url text,
  p_storage_path text,
  p_duration_ms integer,
  p_price_points bigint,
  p_price_gems bigint,
  p_allowed_role_codes text[] DEFAULT '{}'::text[],
  p_min_rank_level integer DEFAULT 0,
  p_max_rank_level integer DEFAULT NULL::integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ext text := lower(reverse(split_part(reverse(trim(coalesce(p_storage_path,''))), '.', 1)));
  v_mode text;
  v_effect text;
  v_duration integer;
BEGIN
  IF v_ext = 'gif' THEN
    v_mode := 'gif';
    v_effect := 'custom';
    v_duration := GREATEST(COALESCE(p_duration_ms, 0), 16);
  ELSIF v_ext IN ('png','jpg','jpeg','webp','bmp') THEN
    v_mode := 'static_effect';
    v_effect := 'pulse_glow';
    v_duration := GREATEST(COALESCE(p_duration_ms, 0), 1000);
  ELSE
    RAISE EXCEPTION 'INVALID_STORAGE_PATH';
  END IF;

  RETURN public.admin_create_avatar_frame(
    p_frame_key,
    p_name_ar,
    p_gender,
    p_asset_url,
    p_storage_path,
    v_duration,
    p_price_points,
    p_price_gems,
    p_allowed_role_codes,
    p_min_rank_level,
    p_max_rank_level,
    v_mode,
    v_effect
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_create_avatar_frame(
  text,text,text,text,text,integer,bigint,bigint,text[],integer,integer
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_create_avatar_frame(
  text,text,text,text,text,integer,bigint,bigint,text[],integer,integer
) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_create_avatar_frame(
  text,text,text,text,text,integer,bigint,bigint,text[],integer,integer,text,text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_create_avatar_frame(
  text,text,text,text,text,integer,bigint,bigint,text[],integer,integer,text,text
) TO authenticated;

COMMIT;
