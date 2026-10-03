-- MASHAREENA / DRAGON
-- FINAL REMOTE AVATAR FRAME RECONCILIATION
-- Safe for the CURRENT production schema.
-- This file intentionally does NOT create/drop core tables and does NOT seed frames.
-- The live frame section is populated only through the authoritative upload/RPC path.

BEGIN;

-- -----------------------------------------------------------------------------
-- 1) Require the live production contract. Fail closed if it is not present.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF to_regclass('public.avatar_frame_catalog') IS NULL THEN
    RAISE EXCEPTION 'REQUIRED_TABLE_MISSING: public.avatar_frame_catalog';
  END IF;
  IF to_regclass('public.profile_cosmetic_catalog') IS NULL THEN
    RAISE EXCEPTION 'REQUIRED_TABLE_MISSING: public.profile_cosmetic_catalog';
  END IF;
  IF to_regclass('public.profiles') IS NULL THEN
    RAISE EXCEPTION 'REQUIRED_TABLE_MISSING: public.profiles';
  END IF;
  IF to_regclass('public.store_items') IS NULL THEN
    RAISE EXCEPTION 'REQUIRED_TABLE_MISSING: public.store_items';
  END IF;
  IF to_regclass('storage.buckets') IS NULL THEN
    RAISE EXCEPTION 'REQUIRED_TABLE_MISSING: storage.buckets';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='avatar_frame_key'
  ) THEN
    RAISE EXCEPTION 'REQUIRED_COLUMN_MISSING: public.profiles.avatar_frame_key';
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 2) Normalize existing frame references without deleting historical rows.
-- -----------------------------------------------------------------------------
-- Existing active catalog rows are preserved. No frame is silently retired by this reconciliation.

-- Only clear profile references that point to a missing frame row.
UPDATE public.profiles p
SET avatar_frame_key = NULL,
    updated_at = now()
WHERE p.avatar_frame_key IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.avatar_frame_catalog f
    WHERE f.frame_key = p.avatar_frame_key
  );

-- -----------------------------------------------------------------------------
-- 3) Canonical frame RPC permission surface.
--    Existing function signatures are NOT replaced here, avoiding return-type
--    conflicts such as 42P13. The live functions were verified separately.
-- -----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.admin_create_avatar_frame(
  text,text,text,text,text,integer,bigint,bigint,text[],integer,integer,text,text,jsonb
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_create_avatar_frame(
  text,text,text,text,text,integer,bigint,bigint,text[],integer,integer,text,text,jsonb
) TO authenticated;

REVOKE ALL ON FUNCTION public.get_avatar_frame_config(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_avatar_frame_config(text) TO authenticated;

REVOKE ALL ON FUNCTION public.set_avatar_frame(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_avatar_frame(text) TO authenticated;

-- get_avatar_frame_catalog() is already a live SETOF-returning function.
-- Do NOT CREATE OR REPLACE it: preserving its return type avoids 42P13.
REVOKE ALL ON FUNCTION public.get_avatar_frame_catalog() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_avatar_frame_catalog() TO authenticated;

-- -----------------------------------------------------------------------------
-- 4) Validate the post-change state before COMMIT.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  v_active_frames bigint;
  v_active_products bigint;
  v_active_store_frames bigint;
  v_invalid_equipped bigint;
  v_bucket bigint;
BEGIN
  SELECT count(*) INTO v_active_frames
  FROM public.avatar_frame_catalog
  WHERE is_active = true;

  SELECT count(*) INTO v_active_products
  FROM public.profile_cosmetic_catalog
  WHERE lower(category) = 'frame'
    AND is_active = true;

  SELECT count(*) INTO v_active_store_frames
  FROM public.store_items
  WHERE lower(coalesce(item_type,'')) = 'avatar_frame'
    AND is_active = true;

  SELECT count(*) INTO v_invalid_equipped
  FROM public.profiles p
  WHERE p.avatar_frame_key IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.avatar_frame_catalog f
      WHERE f.frame_key = p.avatar_frame_key
        AND f.is_active = true
    );

  SELECT count(*) INTO v_bucket
  FROM storage.buckets
  WHERE id = 'avatar-frames';

  IF v_invalid_equipped <> 0 THEN
    RAISE EXCEPTION 'FRAME_RECONCILIATION_FAILED: invalid_equipped_frames=%', v_invalid_equipped;
  END IF;
  IF v_bucket <> 1 THEN
    RAISE EXCEPTION 'FRAME_RECONCILIATION_FAILED: avatar_frames_bucket=%', v_bucket;
  END IF;
END $$;


-- ----------------------------------------------------------------------------
-- 5) Canonical Storage limits + MIME contracts and Realtime publication.
--    These changes are additive metadata/policy configuration only.
-- ----------------------------------------------------------------------------
UPDATE storage.buckets SET file_size_limit=8388608,
  allowed_mime_types=array['image/png','image/jpeg','image/webp','image/gif']::text[]
WHERE id='profile-avatars';
UPDATE storage.buckets SET file_size_limit=5242880,
  allowed_mime_types=array['audio/mpeg','audio/wav','audio/x-wav','audio/ogg','audio/mp4','audio/aac','audio/webm']::text[]
WHERE id='profile-music';
UPDATE storage.buckets SET file_size_limit=15728640,
  allowed_mime_types=array['image/png','image/jpeg','image/webp','image/gif']::text[]
WHERE id='profile-patterns';
UPDATE storage.buckets SET file_size_limit=5242880,
  allowed_mime_types=array['audio/mpeg','audio/wav','audio/x-wav','audio/ogg','audio/mp4','audio/aac','audio/webm']::text[]
WHERE id='chat-sounds';
UPDATE storage.buckets SET file_size_limit=8388608,
  allowed_mime_types=array['image/gif','image/png','image/jpeg','image/webp']::text[]
WHERE id='chat-welcome-images';
UPDATE storage.buckets SET file_size_limit=8388608,
  allowed_mime_types=array['image/gif','image/png','image/jpeg','image/webp']::text[]
WHERE id='chat-badges';
UPDATE storage.buckets SET file_size_limit=26214400,
  allowed_mime_types=array['image/png','image/jpeg','image/webp','image/gif','video/mp4','video/webm','video/quicktime','audio/mpeg','audio/wav','audio/ogg','audio/mp4','audio/aac','audio/webm','application/pdf','application/zip','application/octet-stream']::text[]
WHERE id='media';
UPDATE storage.buckets SET file_size_limit=26214400,
  allowed_mime_types=array['image/png','image/jpeg','image/webp','image/gif','video/mp4','video/webm','video/quicktime','audio/mpeg','audio/wav','audio/ogg','audio/mp4','audio/aac','audio/webm','application/pdf','application/zip','application/octet-stream']::text[]
WHERE id='store-media';
UPDATE storage.buckets SET file_size_limit=8388608,
  allowed_mime_types=array['image/gif','image/png','image/jpeg','image/webp','image/bmp']::text[]
WHERE id='avatar-frames';

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'profiles','avatar_frame_catalog','profile_cosmetic_catalog',
    'profile_cosmetic_purchases','user_profile_services','user_inventory',
    'chat_rooms','chat_room_members','public_chat_messages','chat_messages',
    'chat_threads','chat_typing','user_presence','animated_chat_badges'
  ] LOOP
    IF to_regclass('public.'||t) IS NOT NULL
       AND NOT EXISTS (
         SELECT 1 FROM pg_publication_tables
         WHERE pubname='supabase_realtime'
           AND schemaname='public'
           AND tablename=t
       ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;


-- ----------------------------------------------------------------------------
-- 6) Canonical public RPC security wrappers.
--    Public wrappers delegate to private, auth-aware implementations. The
--    private functions enforce auth.uid() and row/room checks. These wrappers
--    are SECURITY DEFINER so authenticated callers do not need direct EXECUTE
--    on private functions. Anonymous callers remain blocked.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_room_permission(p_room_id uuid, p_user_id uuid, p_permission text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$ SELECT private.has_room_permission($1,$2,$3); $$;

CREATE OR REPLACE FUNCTION public.has_permission(requested_permission text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$ SELECT private.has_permission($1); $$;

CREATE OR REPLACE FUNCTION public.get_room_notification_sounds(p_room_id uuid)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$ SELECT private.get_room_notification_sounds($1); $$;

CREATE OR REPLACE FUNCTION public.get_my_chat_notification_preferences()
RETURNS public.chat_notification_preferences
LANGUAGE sql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$ SELECT private.get_my_chat_notification_preferences(); $$;

CREATE OR REPLACE FUNCTION public.get_my_chat_theme(p_room_id uuid)
RETURNS jsonb
LANGUAGE sql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$ SELECT private.get_my_chat_theme($1); $$;

CREATE OR REPLACE FUNCTION public.get_my_security_state()
RETURNS jsonb
LANGUAGE sql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$ SELECT private.get_my_security_state(); $$;

CREATE OR REPLACE FUNCTION public.get_chat_username_frame_color()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$ SELECT private.get_chat_username_frame_color(); $$;

CREATE OR REPLACE FUNCTION public.set_my_presence(p_is_online boolean, p_current_room_id uuid DEFAULT NULL::uuid)
RETURNS void
LANGUAGE sql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$ SELECT private.set_my_presence($1,$2); $$;

CREATE OR REPLACE FUNCTION public.is_platform_owner()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$ SELECT public._is_platform_owner(auth.uid()); $$;

REVOKE ALL ON FUNCTION public.has_room_permission(uuid,uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_permission(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_room_notification_sounds(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_my_chat_notification_preferences() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_my_chat_theme(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_my_security_state() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_chat_username_frame_color() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_my_presence(boolean,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_platform_owner() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.has_room_permission(uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_permission(text) TO authenticated;
GRANT EXECUTE ON FUNCTION private.has_permission(text) TO authenticated;
GRANT EXECUTE ON FUNCTION private.has_room_permission(uuid,uuid,text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.get_room_notification_sounds(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_chat_notification_preferences() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_chat_theme(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_security_state() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_username_frame_color() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_presence(boolean,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_platform_owner() TO authenticated;

COMMIT;


-- Animated chat badge runtime contract is maintained separately at
-- supabase/tests/animated_chat_badges_runtime_contract.sql.
-- No schema mutation is performed by this verification marker.
