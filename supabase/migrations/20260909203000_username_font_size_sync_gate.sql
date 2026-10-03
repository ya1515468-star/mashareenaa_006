BEGIN;

CREATE OR REPLACE FUNCTION public.sync_my_public_profile(
  p_display_name text DEFAULT NULL,
  p_avatar_url text DEFAULT NULL,
  p_status_text text DEFAULT NULL,
  p_bio text DEFAULT NULL,
  p_cover_url text DEFAULT NULL,
  p_profile_music_url text DEFAULT NULL,
  p_country text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_profession text DEFAULT NULL,
  p_experiences jsonb DEFAULT NULL,
  p_social_links jsonb DEFAULT NULL,
  p_visibility text DEFAULT NULL,
  p_account_type text DEFAULT NULL,
  p_username_color bigint DEFAULT NULL,
  p_username_shine boolean DEFAULT NULL,
  p_status_bold boolean DEFAULT NULL,
  p_status_italic boolean DEFAULT NULL,
  p_status_color bigint DEFAULT NULL,
  p_animated_avatar_url text DEFAULT NULL,
  p_profile_music_duration_ms integer DEFAULT NULL,
  p_profile_music_size_bytes bigint DEFAULT NULL,
  p_username_font_size double precision DEFAULT NULL,
  p_status_font_size double precision DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path='public'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_current public.profiles;
  v_music text := nullif(trim(coalesce(p_profile_music_url,'')), '');
  v_social text := coalesce(p_social_links::text,'');
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT * INTO v_current FROM public.profiles WHERE id=v_uid;

  IF p_visibility='private' AND NOT public.is_my_profile_service('hide_profile') THEN
    RAISE EXCEPTION 'FEATURE_REQUIRED_HIDE_PROFILE';
  END IF;
  IF p_profile_music_url IS NOT NULL AND coalesce(v_music,'')<>coalesce(v_current.profile_music_url,'')
     AND NOT public.is_my_profile_service('profile_music') THEN
    RAISE EXCEPTION 'FEATURE_REQUIRED_PROFILE_MUSIC';
  END IF;
  IF (lower(v_social) like '%facebook%' OR lower(v_social) like '%tiktok%')
     AND NOT public.is_my_profile_service('social_links') THEN
    RAISE EXCEPTION 'FEATURE_REQUIRED_SOCIAL_LINKS';
  END IF;

  IF p_username_font_size IS NOT NULL THEN
    IF p_username_font_size < 10 OR p_username_font_size > 26 THEN
      RAISE EXCEPTION 'USERNAME_FONT_SIZE_OUT_OF_RANGE';
    END IF;
    IF p_username_font_size <> coalesce(v_current.username_font_size,22)
       AND NOT public.is_platform_owner(v_uid)
       AND NOT public.is_my_profile_service('username_font_size') THEN
      RAISE EXCEPTION 'PROFILE_SERVICE_REQUIRED';
    END IF;
  END IF;

  IF p_status_font_size IS NOT NULL AND (p_status_font_size<10 OR p_status_font_size>22) THEN
    RAISE EXCEPTION 'INVALID_STATUS_FONT_SIZE';
  END IF;
  IF v_music is not null AND (p_profile_music_duration_ms is null OR p_profile_music_duration_ms<1 OR p_profile_music_duration_ms>15000) THEN
    RAISE EXCEPTION 'PROFILE_MUSIC_TOO_LONG';
  END IF;
  IF v_music is not null AND (p_profile_music_size_bytes is null OR p_profile_music_size_bytes<1 OR p_profile_music_size_bytes>5242880) THEN
    RAISE EXCEPTION 'PROFILE_MUSIC_TOO_LARGE';
  END IF;

  UPDATE public.profiles SET
    display_name=CASE WHEN p_display_name IS NULL OR length(trim(p_display_name)) NOT BETWEEN 1 AND 120 THEN display_name ELSE trim(p_display_name) END,
    avatar_url=CASE WHEN p_avatar_url IS NULL THEN avatar_url ELSE p_avatar_url END,
    cover_url=CASE WHEN p_cover_url IS NULL THEN cover_url ELSE p_cover_url END,
    status_text=CASE WHEN p_status_text IS NULL THEN status_text ELSE nullif(trim(p_status_text),'') END,
    bio=CASE WHEN p_bio IS NULL THEN bio ELSE left(p_bio,4000) END,
    profile_music_url=CASE WHEN p_profile_music_url IS NULL THEN profile_music_url ELSE v_music END,
    profile_music_duration_ms=CASE WHEN p_profile_music_url IS NULL THEN profile_music_duration_ms WHEN v_music IS NULL THEN null ELSE p_profile_music_duration_ms END,
    profile_music_size_bytes=CASE WHEN p_profile_music_url IS NULL THEN profile_music_size_bytes WHEN v_music IS NULL THEN null ELSE p_profile_music_size_bytes END,
    country=CASE WHEN p_country IS NULL THEN country ELSE nullif(trim(p_country),'') END,
    city=CASE WHEN p_city IS NULL THEN city ELSE nullif(trim(p_city),'') END,
    profession=CASE WHEN p_profession IS NULL THEN profession ELSE nullif(trim(p_profession),'') END,
    experiences=coalesce(p_experiences,experiences),
    social_links=coalesce(p_social_links,social_links),
    visibility=coalesce(p_visibility,visibility),
    account_type=coalesce(p_account_type,account_type),
    username_color=coalesce(p_username_color,username_color),
    username_shine=coalesce(p_username_shine,username_shine),
    status_bold=coalesce(p_status_bold,status_bold),
    status_italic=coalesce(p_status_italic,status_italic),
    status_color=coalesce(p_status_color,status_color),
    animated_avatar_url=CASE WHEN p_animated_avatar_url IS NULL THEN animated_avatar_url ELSE nullif(trim(p_animated_avatar_url),'') END,
    username_font_size=coalesce(p_username_font_size,username_font_size),
    status_font_size=coalesce(p_status_font_size,status_font_size),
    updated_at=now()
  WHERE id=v_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_my_public_profile(text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,text,bigint,boolean,boolean,boolean,bigint,text,integer,bigint,double precision,double precision) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_my_public_profile(text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,text,bigint,boolean,boolean,boolean,bigint,text,integer,bigint,double precision,double precision) TO authenticated;

COMMIT;
