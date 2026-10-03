-- ═══════════════════════════════════════════════════════════════════════
-- MASHAREEN v2 — الهجرة الكاملة المصحّحة
-- تصحيح: user_roles يستخدم user_id وليس uid
--         الفحص عبر public.is_my_platform_owner() فقط
-- ═══════════════════════════════════════════════════════════════════════

-- ─── حذف الدوال القديمة التي قد تتعارض في نوع الإرجاع ──────────────
-- يجب الحذف قبل CREATE OR REPLACE عند تغيير return type
DROP FUNCTION IF EXISTS _owner_check() CASCADE;
DROP FUNCTION IF EXISTS set_room_background(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS get_my_reel_publish_quota() CASCADE;
DROP FUNCTION IF EXISTS publish_producer_reel(text, text, text, text, text, text[]) CASCADE;
DROP FUNCTION IF EXISTS toggle_reel_like(uuid) CASCADE;
DROP FUNCTION IF EXISTS toggle_reel_save(uuid) CASCADE;
DROP FUNCTION IF EXISTS increment_reel_share(uuid) CASCADE;
DROP FUNCTION IF EXISTS increment_reel_download(uuid) CASCADE;
DROP FUNCTION IF EXISTS increment_reel_view(uuid) CASCADE;
DROP FUNCTION IF EXISTS add_reel_comment(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS owner_moderate_reel(uuid, text, text) CASCADE;
DROP FUNCTION IF EXISTS owner_set_market_season_banner(text, text, text, text, jsonb, boolean) CASCADE;
DROP FUNCTION IF EXISTS owner_update_reel_quota(text, integer) CASCADE;
DROP FUNCTION IF EXISTS owner_update_reel_quota(text, integer, integer) CASCADE;
DROP FUNCTION IF EXISTS owner_upsert_currency_package(uuid, text, text, text, integer, numeric, text, text, text, boolean, integer, boolean, text, integer) CASCADE;
DROP FUNCTION IF EXISTS owner_delete_currency_package(uuid) CASCADE;
DROP FUNCTION IF EXISTS post_factory_listing(text, text, text, text, text[], jsonb, numeric, numeric, text, text, text) CASCADE;
DROP FUNCTION IF EXISTS owner_approve_factory_listing(uuid) CASCADE;
DROP FUNCTION IF EXISTS owner_reject_factory_listing(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS owner_feature_factory_listing(uuid, boolean) CASCADE;
DROP FUNCTION IF EXISTS owner_delete_factory_listing(uuid) CASCADE;
DROP FUNCTION IF EXISTS increment_factory_listing_views(uuid) CASCADE;
DROP FUNCTION IF EXISTS owner_upsert_factory_category(text, text, text, text, text, text, text, integer, boolean) CASCADE;
DROP FUNCTION IF EXISTS post_tender(text, text, text, numeric, numeric, text, text, integer, text, text, timestamptz) CASCADE;
DROP FUNCTION IF EXISTS submit_tender_bid(uuid, numeric, text, integer, text, text) CASCADE;
DROP FUNCTION IF EXISTS owner_moderate_tender(uuid, text, text) CASCADE;
DROP FUNCTION IF EXISTS owner_moderate_tender_bid(uuid, text, text) CASCADE;
DROP FUNCTION IF EXISTS post_external_request(text, text, text, text, text, integer, text, text, text, text[], boolean, numeric, timestamptz) CASCADE;
DROP FUNCTION IF EXISTS respond_to_external_request(uuid, numeric, integer, text, text, text, text) CASCADE;
DROP FUNCTION IF EXISTS owner_moderate_external_request(uuid, text, text) CASCADE;
DROP FUNCTION IF EXISTS owner_moderate_external_bid(uuid, text, text) CASCADE;


-- ═══════════════════════════════════════════════════════════════
-- مصالحة المخطط: إضافة أي أعمدة ناقصة للجداول الموجودة مسبقاً
-- (CREATE TABLE IF NOT EXISTS لا يعدّل الجداول القائمة)
-- ═══════════════════════════════════════════════════════════════

-- مصالحة مخطط chat_room_backgrounds
ALTER TABLE IF EXISTS public.chat_room_backgrounds ADD COLUMN IF NOT EXISTS room_id uuid;
ALTER TABLE IF EXISTS public.chat_room_backgrounds ADD COLUMN IF NOT EXISTS background_url text;
ALTER TABLE IF EXISTS public.chat_room_backgrounds ADD COLUMN IF NOT EXISTS uploaded_by uuid;
ALTER TABLE IF EXISTS public.chat_room_backgrounds ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

-- مصالحة مخطط dm_backgrounds
DO $recon$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='dm_backgrounds')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='dm_backgrounds' AND column_name='uid')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='dm_backgrounds' AND column_name='user_id')
  THEN EXECUTE 'ALTER TABLE IF EXISTS public.dm_backgrounds RENAME COLUMN user_id TO uid';
  END IF;
END $recon$;
ALTER TABLE IF EXISTS public.dm_backgrounds ADD COLUMN IF NOT EXISTS uid uuid;
ALTER TABLE IF EXISTS public.dm_backgrounds ADD COLUMN IF NOT EXISTS thread_id uuid;
ALTER TABLE IF EXISTS public.dm_backgrounds ADD COLUMN IF NOT EXISTS background_url text;
ALTER TABLE IF EXISTS public.dm_backgrounds ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

-- مصالحة مخطط reel_publish_quota
ALTER TABLE IF EXISTS public.reel_publish_quota ADD COLUMN IF NOT EXISTS membership_tier text;
ALTER TABLE IF EXISTS public.reel_publish_quota ADD COLUMN IF NOT EXISTS monthly_limit integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.reel_publish_quota ADD COLUMN IF NOT EXISTS price_points integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.reel_publish_quota ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- مصالحة مخطط producer_reels
DO $recon$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='producer_reels')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='producer_reels' AND column_name='uid')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='producer_reels' AND column_name='user_id')
  THEN EXECUTE 'ALTER TABLE IF EXISTS public.producer_reels RENAME COLUMN user_id TO uid';
  END IF;
END $recon$;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS uid uuid;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS video_url text;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS thumbnail_url text;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '';
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'other';
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}';
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS likes_count integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS views_count integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS saves_count integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS comments_count integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS shares_count integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS downloads_count integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS liked_by uuid[] DEFAULT '{}';
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS saved_by uuid[] DEFAULT '{}';
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS is_approved boolean NOT NULL DEFAULT false;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS owner_note text;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS points_cost integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS published_month text;
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE IF EXISTS public.producer_reels ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- مصالحة مخطط reel_comments
DO $recon$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='reel_comments')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='reel_comments' AND column_name='uid')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='reel_comments' AND column_name='user_id')
  THEN EXECUTE 'ALTER TABLE IF EXISTS public.reel_comments RENAME COLUMN user_id TO uid';
  END IF;
END $recon$;
ALTER TABLE IF EXISTS public.reel_comments ADD COLUMN IF NOT EXISTS reel_id uuid;
ALTER TABLE IF EXISTS public.reel_comments ADD COLUMN IF NOT EXISTS uid uuid;
ALTER TABLE IF EXISTS public.reel_comments ADD COLUMN IF NOT EXISTS text text;
ALTER TABLE IF EXISTS public.reel_comments ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

-- مصالحة مخطط market_season_banner
ALTER TABLE IF EXISTS public.market_season_banner ADD COLUMN IF NOT EXISTS title text NOT NULL DEFAULT '';
ALTER TABLE IF EXISTS public.market_season_banner ADD COLUMN IF NOT EXISTS season_date text;
ALTER TABLE IF EXISTS public.market_season_banner ADD COLUMN IF NOT EXISTS season_gif_url text;
ALTER TABLE IF EXISTS public.market_season_banner ADD COLUMN IF NOT EXISTS background_url text;
ALTER TABLE IF EXISTS public.market_season_banner ADD COLUMN IF NOT EXISTS title_effects jsonb DEFAULT '{}';
ALTER TABLE IF EXISTS public.market_season_banner ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT false;
ALTER TABLE IF EXISTS public.market_season_banner ADD COLUMN IF NOT EXISTS created_by uuid;
ALTER TABLE IF EXISTS public.market_season_banner ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE IF EXISTS public.market_season_banner ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- مصالحة مخطط currency_packages
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS currency_type text;
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS name text;
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS amount integer;
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS price_usd numeric(10,2);
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS price_display text;
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS icon_url text;
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS badge_label text;
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS is_featured boolean DEFAULT false;
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS sort_order integer DEFAULT 0;
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS display_style text DEFAULT 'card';
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS bonus_amount integer DEFAULT 0;
ALTER TABLE IF EXISTS public.currency_packages ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- مصالحة مخطط factory_categories
ALTER TABLE IF EXISTS public.factory_categories ADD COLUMN IF NOT EXISTS key text;
ALTER TABLE IF EXISTS public.factory_categories ADD COLUMN IF NOT EXISTS name_ar text;
ALTER TABLE IF EXISTS public.factory_categories ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '';
ALTER TABLE IF EXISTS public.factory_categories ADD COLUMN IF NOT EXISTS emoji text NOT NULL DEFAULT '🏭';
ALTER TABLE IF EXISTS public.factory_categories ADD COLUMN IF NOT EXISTS banner_url text;
ALTER TABLE IF EXISTS public.factory_categories ADD COLUMN IF NOT EXISTS bg_color_start text DEFAULT '#1A3A5C';
ALTER TABLE IF EXISTS public.factory_categories ADD COLUMN IF NOT EXISTS bg_color_end text DEFAULT '#0D1F35';
ALTER TABLE IF EXISTS public.factory_categories ADD COLUMN IF NOT EXISTS sort_order integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.factory_categories ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;
ALTER TABLE IF EXISTS public.factory_categories ADD COLUMN IF NOT EXISTS listings_count integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.factory_categories ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

-- مصالحة مخطط factory_listings
DO $recon$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='factory_listings')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='factory_listings' AND column_name='uid')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='factory_listings' AND column_name='user_id')
  THEN EXECUTE 'ALTER TABLE IF EXISTS public.factory_listings RENAME COLUMN user_id TO uid';
  END IF;
END $recon$;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS category_key text;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS uid uuid;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS location text;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS image_urls text[] DEFAULT '{}';
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS specs jsonb DEFAULT '{}';
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS price_min numeric;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS price_max numeric;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS price_unit text;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS whatsapp text;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending';
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS views_count integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS owner_note text;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS owner_name text;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS owner_avatar_url text;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS owner_membership text;
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE IF EXISTS public.factory_listings ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- مصالحة مخطط tenders
DO $recon$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='tenders')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='tenders' AND column_name='uid')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='tenders' AND column_name='user_id')
  THEN EXECUTE 'ALTER TABLE IF EXISTS public.tenders RENAME COLUMN user_id TO uid';
  END IF;
END $recon$;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS uid uuid;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS requirements text;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS budget_min numeric;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS budget_max numeric;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS currency text DEFAULT 'USD';
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS location text;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS quantity integer;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS quantity_unit text DEFAULT 'قطعة';
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'other';
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS deadline timestamptz;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'open';
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS awarded_bid_id uuid;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS bids_count integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS owner_note text;
ALTER TABLE IF EXISTS public.tenders ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

-- مصالحة مخطط tender_bids
DO $recon$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='tender_bids')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='tender_bids' AND column_name='uid')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='tender_bids' AND column_name='user_id')
  THEN EXECUTE 'ALTER TABLE IF EXISTS public.tender_bids RENAME COLUMN user_id TO uid';
  END IF;
END $recon$;
ALTER TABLE IF EXISTS public.tender_bids ADD COLUMN IF NOT EXISTS tender_id uuid;
ALTER TABLE IF EXISTS public.tender_bids ADD COLUMN IF NOT EXISTS uid uuid;
ALTER TABLE IF EXISTS public.tender_bids ADD COLUMN IF NOT EXISTS price numeric;
ALTER TABLE IF EXISTS public.tender_bids ADD COLUMN IF NOT EXISTS currency text DEFAULT 'USD';
ALTER TABLE IF EXISTS public.tender_bids ADD COLUMN IF NOT EXISTS delivery_days integer;
ALTER TABLE IF EXISTS public.tender_bids ADD COLUMN IF NOT EXISTS note text;
ALTER TABLE IF EXISTS public.tender_bids ADD COLUMN IF NOT EXISTS attachment_url text;
ALTER TABLE IF EXISTS public.tender_bids ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending';
ALTER TABLE IF EXISTS public.tender_bids ADD COLUMN IF NOT EXISTS owner_note text;
ALTER TABLE IF EXISTS public.tender_bids ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

-- مصالحة مخطط external_requests
DO $recon$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='external_requests')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='external_requests' AND column_name='uid')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='external_requests' AND column_name='user_id')
  THEN EXECUTE 'ALTER TABLE IF EXISTS public.external_requests RENAME COLUMN user_id TO uid';
  END IF;
END $recon$;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS uid uuid;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS product_type text;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS target_country text;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS delivery_port text;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS quantity integer;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS quantity_unit text DEFAULT 'piece';
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS incoterms text DEFAULT 'FOB';
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS payment_terms text;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS certification text[] DEFAULT '{}';
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS sample_required boolean NOT NULL DEFAULT false;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS budget_usd numeric;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'open';
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS bids_count integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS owner_note text;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS awarded_bid_id uuid;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS deadline timestamptz;
ALTER TABLE IF EXISTS public.external_requests ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

-- مصالحة مخطط external_request_bids
DO $recon$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='external_request_bids')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='external_request_bids' AND column_name='uid')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='external_request_bids' AND column_name='user_id')
  THEN EXECUTE 'ALTER TABLE IF EXISTS public.external_request_bids RENAME COLUMN user_id TO uid';
  END IF;
END $recon$;
ALTER TABLE IF EXISTS public.external_request_bids ADD COLUMN IF NOT EXISTS request_id uuid;
ALTER TABLE IF EXISTS public.external_request_bids ADD COLUMN IF NOT EXISTS uid uuid;
ALTER TABLE IF EXISTS public.external_request_bids ADD COLUMN IF NOT EXISTS price_usd numeric;
ALTER TABLE IF EXISTS public.external_request_bids ADD COLUMN IF NOT EXISTS delivery_days integer;
ALTER TABLE IF EXISTS public.external_request_bids ADD COLUMN IF NOT EXISTS note text;
ALTER TABLE IF EXISTS public.external_request_bids ADD COLUMN IF NOT EXISTS attachment_url text;
ALTER TABLE IF EXISTS public.external_request_bids ADD COLUMN IF NOT EXISTS incoterms_offered text;
ALTER TABLE IF EXISTS public.external_request_bids ADD COLUMN IF NOT EXISTS payment_terms_offered text;
ALTER TABLE IF EXISTS public.external_request_bids ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending';
ALTER TABLE IF EXISTS public.external_request_bids ADD COLUMN IF NOT EXISTS owner_note text;
ALTER TABLE IF EXISTS public.external_request_bids ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();


-- ═══════════════════════════════════════════════════════════════
-- مصالحة عمود id: ضمان وجود DEFAULT gen_random_uuid()
-- (جداول قديمة قد تكون بلا default فتفشل عمليات INSERT)
-- ═══════════════════════════════════════════════════════════════
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $idfix$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.table_name
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.column_name  = 'id'
      AND c.data_type    = 'uuid'
      AND c.column_default IS NULL
      AND c.table_name IN ('chat_room_backgrounds','dm_backgrounds','reel_publish_quota','producer_reels','reel_comments','market_season_banner','currency_packages','factory_categories','factory_listings','tenders','tender_bids','external_requests','external_request_bids')
  LOOP
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN id SET DEFAULT gen_random_uuid()', r.table_name);
    RAISE NOTICE 'id default set on %', r.table_name;
  END LOOP;
END $idfix$;

-- إسقاط NOT NULL عن أي أعمدة قديمة غير موجودة في المخطط الجديد
-- حتى لا تفشل عمليات INSERT بسبب أعمدة موروثة
DO $oldcols$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.table_name, c.column_name
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name IN ('chat_room_backgrounds','dm_backgrounds','reel_publish_quota','producer_reels','reel_comments','market_season_banner','currency_packages','factory_categories','factory_listings','tenders','tender_bids','external_requests','external_request_bids')
      AND c.is_nullable = 'NO'
      AND c.column_default IS NULL
      AND c.column_name NOT IN ('id')
  LOOP
    BEGIN
      EXECUTE format('ALTER TABLE public.%I ALTER COLUMN %I DROP NOT NULL', r.table_name, r.column_name);
    EXCEPTION WHEN others THEN NULL;
    END;
  END LOOP;
END $oldcols$;

-- ─── دالة مساعدة موحّدة للفحص (تستخدم في كل RLS) ───────────────────
-- نعيد تعريفها بشكل آمن لكي تكون متاحة للسياسات أدناه
CREATE OR REPLACE FUNCTION _owner_check() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT public.is_my_platform_owner()
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 1. خلفيات الغرف
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE chat_rooms ADD COLUMN IF NOT EXISTS background_url text;

CREATE TABLE IF NOT EXISTS chat_room_backgrounds (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id       uuid NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  background_url text NOT NULL,
  uploaded_by   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE chat_room_backgrounds ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "room_bg_select" ON chat_room_backgrounds;
DROP POLICY IF EXISTS "room_bg_manage" ON chat_room_backgrounds;
CREATE POLICY "room_bg_select" ON chat_room_backgrounds FOR SELECT USING (true);
CREATE POLICY "room_bg_manage" ON chat_room_backgrounds FOR ALL
  USING (public.is_my_platform_owner());

CREATE OR REPLACE FUNCTION set_room_background(
  p_room_id uuid, p_background_url text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  UPDATE chat_rooms SET background_url = p_background_url WHERE id = p_room_id;
  INSERT INTO chat_room_backgrounds(room_id, background_url, uploaded_by)
  VALUES(p_room_id, p_background_url, auth.uid());
END;$$;

-- خلفيات الخاص
CREATE TABLE IF NOT EXISTS dm_backgrounds (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uid          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  thread_id    uuid NOT NULL,
  background_url text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(uid, thread_id)
);
ALTER TABLE dm_backgrounds ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dm_bg_own" ON dm_backgrounds;
CREATE POLICY "dm_bg_own" ON dm_backgrounds FOR ALL USING (uid = auth.uid());

-- ─────────────────────────────────────────────────────────────────────
-- 2. حصص نشر الريلات
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reel_publish_quota (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membership_tier  text NOT NULL UNIQUE,
  monthly_limit    integer NOT NULL DEFAULT 0,  -- -1 = unlimited
  price_points     integer NOT NULL DEFAULT 0,   -- سعر النشر بالنقاط
  updated_at       timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE reel_publish_quota ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "quota_select" ON reel_publish_quota;
DROP POLICY IF EXISTS "quota_owner" ON reel_publish_quota;
CREATE POLICY "quota_select" ON reel_publish_quota FOR SELECT USING (true);
CREATE POLICY "quota_owner"  ON reel_publish_quota FOR ALL USING (public.is_my_platform_owner());

INSERT INTO reel_publish_quota (membership_tier, monthly_limit, price_points) VALUES
  ('free',   0,   0),
  ('bronze',  5, 100),
  ('silver', 15,  80),
  ('gold',   30,  50),
  ('vip',    -1,   0)
ON CONFLICT (membership_tier) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────
-- 3. سوق المنتجين — ريلات فيديو فقط
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS producer_reels (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uid              uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_url        text NOT NULL,
  thumbnail_url    text,
  title            text NOT NULL,
  description      text NOT NULL DEFAULT '',
  category         text NOT NULL DEFAULT 'other',
  tags             text[] DEFAULT '{}',
  likes_count      integer NOT NULL DEFAULT 0,
  views_count      integer NOT NULL DEFAULT 0,
  saves_count      integer NOT NULL DEFAULT 0,
  comments_count   integer NOT NULL DEFAULT 0,
  shares_count     integer NOT NULL DEFAULT 0,
  downloads_count  integer NOT NULL DEFAULT 0,
  liked_by         uuid[] DEFAULT '{}',
  saved_by         uuid[] DEFAULT '{}',
  is_approved      boolean NOT NULL DEFAULT false,
  is_featured      boolean NOT NULL DEFAULT false,
  owner_note       text,
  points_cost      integer NOT NULL DEFAULT 0,
  published_month  text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_producer_reels_uid      ON producer_reels(uid);
CREATE INDEX IF NOT EXISTS idx_producer_reels_category ON producer_reels(category);
CREATE INDEX IF NOT EXISTS idx_producer_reels_approved ON producer_reels(is_approved);
CREATE INDEX IF NOT EXISTS idx_producer_reels_month    ON producer_reels(published_month);

ALTER TABLE producer_reels ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "reels_select" ON producer_reels;
DROP POLICY IF EXISTS "reels_insert" ON producer_reels;
DROP POLICY IF EXISTS "reels_update" ON producer_reels;
DROP POLICY IF EXISTS "reels_delete" ON producer_reels;
CREATE POLICY "reels_select" ON producer_reels FOR SELECT
  USING (is_approved = true OR uid = auth.uid() OR public.is_my_platform_owner());
CREATE POLICY "reels_insert" ON producer_reels FOR INSERT WITH CHECK (uid = auth.uid());
CREATE POLICY "reels_update" ON producer_reels FOR UPDATE
  USING (uid = auth.uid() OR public.is_my_platform_owner());
CREATE POLICY "reels_delete" ON producer_reels FOR DELETE
  USING (uid = auth.uid() OR public.is_my_platform_owner());

-- تعليقات الريلات
CREATE TABLE IF NOT EXISTS reel_comments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reel_id     uuid NOT NULL REFERENCES producer_reels(id) ON DELETE CASCADE,
  uid         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE reel_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "reel_cmt_select" ON reel_comments;
DROP POLICY IF EXISTS "reel_cmt_insert" ON reel_comments;
DROP POLICY IF EXISTS "reel_cmt_delete" ON reel_comments;
CREATE POLICY "reel_cmt_select" ON reel_comments FOR SELECT USING (true);
CREATE POLICY "reel_cmt_insert" ON reel_comments FOR INSERT WITH CHECK (uid = auth.uid());
CREATE POLICY "reel_cmt_delete" ON reel_comments FOR DELETE
  USING (uid = auth.uid() OR public.is_my_platform_owner());

-- بانر موسم السوق
CREATE TABLE IF NOT EXISTS market_season_banner (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title           text NOT NULL DEFAULT '',
  season_date     text,
  season_gif_url  text,
  background_url  text,
  title_effects   jsonb DEFAULT '{}',
  is_active       boolean NOT NULL DEFAULT false,
  created_by      uuid REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE market_season_banner ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "banner_select" ON market_season_banner;
DROP POLICY IF EXISTS "banner_owner"  ON market_season_banner;
CREATE POLICY "banner_select" ON market_season_banner FOR SELECT USING (true);
CREATE POLICY "banner_owner"  ON market_season_banner FOR ALL USING (public.is_my_platform_owner());

-- ─── RPCs سوق المنتجين ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_my_reel_publish_quota()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_tier text; v_limit integer; v_price integer; v_used integer;
  v_month text := to_char(now(), 'YYYY-MM');
BEGIN
  SELECT COALESCE(
    (SELECT s.tier FROM user_subscriptions s
     WHERE s.user_id = auth.uid() AND s.status = 'active' AND s.expires_at > now()
     ORDER BY s.created_at DESC LIMIT 1), 'free'
  ) INTO v_tier;
  SELECT monthly_limit, price_points INTO v_limit, v_price
  FROM reel_publish_quota WHERE membership_tier = v_tier;
  IF v_limit IS NULL THEN v_limit := 0; v_price := 0; END IF;
  SELECT COUNT(*) INTO v_used
  FROM producer_reels WHERE uid = auth.uid() AND published_month = v_month;
  RETURN jsonb_build_object(
    'tier', v_tier,
    'monthly_limit', v_limit,
    'price_points', v_price,
    'used_this_month', v_used,
    'remaining', CASE WHEN v_limit = -1 THEN 9999 ELSE GREATEST(0, v_limit - v_used) END,
    'unlimited', v_limit = -1
  );
END;$$;

CREATE OR REPLACE FUNCTION publish_producer_reel(
  p_video_url text, p_thumbnail_url text, p_title text,
  p_description text, p_category text, p_tags text[]
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_quota jsonb; v_remaining integer; v_price integer;
  v_reel_id uuid; v_month text := to_char(now(), 'YYYY-MM');
BEGIN
  SELECT get_my_reel_publish_quota() INTO v_quota;
  v_remaining := (v_quota->>'remaining')::integer;
  v_price     := (v_quota->>'price_points')::integer;
  IF v_remaining <= 0 THEN
    RAISE EXCEPTION 'quota_exceeded';
  END IF;
  -- خصم النقاط إن كان السعر > 0
  IF v_price > 0 THEN
    PERFORM spend_points(v_price, 'reel_publish');
  END IF;
  INSERT INTO producer_reels(uid, video_url, thumbnail_url, title, description,
    category, tags, points_cost, published_month, is_approved)
  VALUES(auth.uid(), p_video_url, p_thumbnail_url, p_title, p_description,
    p_category, p_tags, v_price, v_month, false)
  RETURNING id INTO v_reel_id;
  RETURN v_reel_id;
END;$$;

CREATE OR REPLACE FUNCTION toggle_reel_like(p_reel_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_uid uuid := auth.uid(); v_liked boolean;
BEGIN
  SELECT v_uid = ANY(liked_by) INTO v_liked FROM producer_reels WHERE id = p_reel_id;
  IF v_liked THEN
    UPDATE producer_reels SET liked_by = array_remove(liked_by, v_uid),
      likes_count = GREATEST(0, likes_count - 1) WHERE id = p_reel_id;
    RETURN false;
  ELSE
    UPDATE producer_reels SET liked_by = array_append(liked_by, v_uid),
      likes_count = likes_count + 1 WHERE id = p_reel_id;
    RETURN true;
  END IF;
END;$$;

CREATE OR REPLACE FUNCTION toggle_reel_save(p_reel_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_uid uuid := auth.uid(); v_saved boolean;
BEGIN
  SELECT v_uid = ANY(saved_by) INTO v_saved FROM producer_reels WHERE id = p_reel_id;
  IF v_saved THEN
    UPDATE producer_reels SET saved_by = array_remove(saved_by, v_uid),
      saves_count = GREATEST(0, saves_count - 1) WHERE id = p_reel_id;
    RETURN false;
  ELSE
    UPDATE producer_reels SET saved_by = array_append(saved_by, v_uid),
      saves_count = saves_count + 1 WHERE id = p_reel_id;
    RETURN true;
  END IF;
END;$$;

CREATE OR REPLACE FUNCTION increment_reel_share(p_reel_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN UPDATE producer_reels SET shares_count = shares_count + 1 WHERE id = p_reel_id; END;$$;

CREATE OR REPLACE FUNCTION increment_reel_download(p_reel_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN UPDATE producer_reels SET downloads_count = downloads_count + 1 WHERE id = p_reel_id; END;$$;

CREATE OR REPLACE FUNCTION increment_reel_view(p_reel_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN UPDATE producer_reels SET views_count = views_count + 1 WHERE id = p_reel_id; END;$$;

CREATE OR REPLACE FUNCTION add_reel_comment(p_reel_id uuid, p_text text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO reel_comments(reel_id, uid, text)
  VALUES(p_reel_id, auth.uid(), p_text) RETURNING id INTO v_id;
  UPDATE producer_reels SET comments_count = comments_count + 1 WHERE id = p_reel_id;
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION owner_moderate_reel(
  p_reel_id uuid, p_action text, p_note text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  CASE p_action
    WHEN 'approve'   THEN UPDATE producer_reels SET is_approved = true,  owner_note = p_note WHERE id = p_reel_id;
    WHEN 'reject'    THEN UPDATE producer_reels SET is_approved = false, owner_note = p_note WHERE id = p_reel_id;
    WHEN 'feature'   THEN UPDATE producer_reels SET is_featured = true  WHERE id = p_reel_id;
    WHEN 'unfeature' THEN UPDATE producer_reels SET is_featured = false WHERE id = p_reel_id;
    WHEN 'delete'    THEN DELETE FROM producer_reels WHERE id = p_reel_id;
    ELSE RAISE EXCEPTION 'unknown_action';
  END CASE;
END;$$;

CREATE OR REPLACE FUNCTION owner_set_market_season_banner(
  p_title text, p_season_date text, p_season_gif_url text,
  p_background_url text, p_title_effects jsonb, p_is_active boolean
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  UPDATE market_season_banner SET is_active = false;
  INSERT INTO market_season_banner(title, season_date, season_gif_url,
    background_url, title_effects, is_active, created_by)
  VALUES(p_title, p_season_date, p_season_gif_url,
    p_background_url, p_title_effects, p_is_active, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION owner_update_reel_quota(
  p_tier text, p_limit integer, p_price_points integer DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  INSERT INTO reel_publish_quota(membership_tier, monthly_limit, price_points, updated_at)
  VALUES(p_tier, p_limit, COALESCE(p_price_points, 0), now())
  ON CONFLICT(membership_tier) DO UPDATE
  SET monthly_limit = p_limit,
      price_points  = COALESCE(p_price_points, reel_publish_quota.price_points),
      updated_at    = now();
END;$$;

-- ─────────────────────────────────────────────────────────────────────
-- 4. متجر النقاط والجواهر — قسم داخل متجر الشات
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS currency_packages (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  currency_type text NOT NULL,       -- 'points' | 'gems'
  name          text NOT NULL,
  description   text,
  amount        integer NOT NULL,    -- كمية النقاط/الجواهر
  price_usd     numeric(10,2) NOT NULL,
  price_display text,                -- عرض السعر النصي
  icon_url      text,                -- أيقونة رمزية مرفوعة
  badge_label   text,                -- شارة مثل "الأوفر" / "الأشهر"
  is_featured   boolean DEFAULT false,
  sort_order    integer DEFAULT 0,
  is_active     boolean DEFAULT true,
  display_style text DEFAULT 'card', -- 'card' | 'banner' | 'compact'
  bonus_amount  integer DEFAULT 0,   -- مكافأة إضافية
  created_at    timestamptz DEFAULT now()
);
ALTER TABLE currency_packages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "cpkg_select" ON currency_packages;
DROP POLICY IF EXISTS "cpkg_owner"  ON currency_packages;
CREATE POLICY "cpkg_select" ON currency_packages FOR SELECT USING (is_active = true OR public.is_my_platform_owner());
CREATE POLICY "cpkg_owner"  ON currency_packages FOR ALL   USING (public.is_my_platform_owner());

-- بيانات أولية للباقات
INSERT INTO currency_packages (currency_type, name, amount, price_usd, price_display, badge_label, sort_order) VALUES
  ('points', 'باقة بداية',     500,    0.99, '$0.99',  NULL,       1),
  ('points', 'باقة عادية',    2000,    3.49, '$3.49',  'شعبي',     2),
  ('points', 'باقة ذهبية',    5000,    7.99, '$7.99',  'الأوفر',   3),
  ('points', 'باقة ماسية',   15000,   19.99, '$19.99', 'المميز',   4),
  ('gems',   'حجر واحد',         5,    0.99, '$0.99',  NULL,       1),
  ('gems',   'حفنة جواهر',      25,    3.99, '$3.99',  'شعبي',     2),
  ('gems',   'كنز الجواهر',     75,    9.99, '$9.99',  'الأوفر',   3),
  ('gems',   'خزينة الجواهر', 200,    24.99, '$24.99', 'الأفخم',  4)
ON CONFLICT DO NOTHING;

-- RPC إدارة الباقات (المالك)
CREATE OR REPLACE FUNCTION owner_upsert_currency_package(
  p_id uuid DEFAULT NULL,
  p_currency_type text DEFAULT 'points',
  p_name text DEFAULT '',
  p_description text DEFAULT '',
  p_amount integer DEFAULT 0,
  p_price_usd numeric DEFAULT 0,
  p_price_display text DEFAULT '',
  p_icon_url text DEFAULT NULL,
  p_badge_label text DEFAULT NULL,
  p_is_featured boolean DEFAULT false,
  p_sort_order integer DEFAULT 0,
  p_is_active boolean DEFAULT true,
  p_display_style text DEFAULT 'card',
  p_bonus_amount integer DEFAULT 0
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  IF p_id IS NOT NULL THEN
    UPDATE currency_packages SET
      currency_type = p_currency_type, name = p_name, description = p_description,
      amount = p_amount, price_usd = p_price_usd, price_display = p_price_display,
      icon_url = p_icon_url, badge_label = p_badge_label, is_featured = p_is_featured,
      sort_order = p_sort_order, is_active = p_is_active, display_style = p_display_style,
      bonus_amount = p_bonus_amount
    WHERE id = p_id RETURNING id INTO v_id;
  ELSE
    INSERT INTO currency_packages(currency_type, name, description, amount, price_usd,
      price_display, icon_url, badge_label, is_featured, sort_order, is_active, display_style, bonus_amount)
    VALUES(p_currency_type, p_name, p_description, p_amount, p_price_usd,
      p_price_display, p_icon_url, p_badge_label, p_is_featured, p_sort_order, p_is_active, p_display_style, p_bonus_amount)
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION owner_delete_currency_package(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  DELETE FROM currency_packages WHERE id = p_id;
END;$$;

-- ─────────────────────────────────────────────────────────────────────
-- 5. المصانع — قطاع الألبسة الموحّد
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS factory_categories (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key           text NOT NULL UNIQUE,
  name_ar       text NOT NULL,
  description   text NOT NULL DEFAULT '',
  emoji         text NOT NULL DEFAULT '🏭',
  banner_url    text,
  bg_color_start text DEFAULT '#1A3A5C',
  bg_color_end   text DEFAULT '#0D1F35',
  sort_order    integer NOT NULL DEFAULT 0,
  is_active     boolean NOT NULL DEFAULT true,
  listings_count integer NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now()
);
INSERT INTO factory_categories(key, name_ar, description, emoji, sort_order) VALUES
  ('packaging',  'أمبلاج',   'خدمات التغليف والأمبلاج',             '📦', 1),
  ('cutting',    'قطاعة',    'خدمات القطع والتفصيل',               '✂️', 2),
  ('washing',    'غسيل',     'محطات الغسيل الصناعي',               '🫧', 3),
  ('dyeing',     'صباغة',    'محطات الصباغة والتلوين',             '🎨', 4),
  ('embroidery', 'تطريز',    'تطريز آلي ويدوي',                    '🪡', 5),
  ('ironing',    'كوي',      'خدمات الكوي والتشطيب',               '🔥', 6),
  ('printing',   'طباعة',    'طباعة رقمية وحريرية',                '🖨️',7),
  ('fabric',     'أقمشة',    'بيع وتوريد الأقمشة',                '🧵', 8),
  ('accessories','إكسسوار',  'مستلزمات الخياطة',                   '💎', 9),
  ('pattern',    'باترون',   'تصميم وبيع الباترونات',              '📐',10),
  ('workshop',   'ورشات',    'ورشات خياطة للتعاقد والإنتاج',       '🏭',11),
  ('other',      'أخرى',     'خدمات ومنتجات متنوعة',               '🏷️',12)
ON CONFLICT(key) DO NOTHING;

ALTER TABLE factory_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "fcat_select" ON factory_categories;
DROP POLICY IF EXISTS "fcat_owner"  ON factory_categories;
CREATE POLICY "fcat_select" ON factory_categories FOR SELECT
  USING (is_active = true OR public.is_my_platform_owner());
CREATE POLICY "fcat_owner" ON factory_categories FOR ALL
  USING (public.is_my_platform_owner());

-- إعلانات المصانع
CREATE TABLE IF NOT EXISTS factory_listings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_key    text NOT NULL REFERENCES factory_categories(key),
  uid             uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title           text NOT NULL,
  description     text NOT NULL,
  location        text,
  image_urls      text[] DEFAULT '{}',
  specs           jsonb DEFAULT '{}',
  price_min       numeric,
  price_max       numeric,
  price_unit      text,
  whatsapp        text,
  phone           text,
  is_featured     boolean NOT NULL DEFAULT false,
  status          text NOT NULL DEFAULT 'pending', -- pending|approved|rejected
  views_count     integer NOT NULL DEFAULT 0,
  owner_note      text,
  -- snapshot بيانات المنشئ
  owner_name      text,
  owner_avatar_url text,
  owner_membership text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_factory_listings_cat    ON factory_listings(category_key);
CREATE INDEX IF NOT EXISTS idx_factory_listings_status ON factory_listings(status);
CREATE INDEX IF NOT EXISTS idx_factory_listings_uid    ON factory_listings(uid);

ALTER TABLE factory_listings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "fl_select" ON factory_listings;
DROP POLICY IF EXISTS "fl_insert" ON factory_listings;
DROP POLICY IF EXISTS "fl_update" ON factory_listings;
DROP POLICY IF EXISTS "fl_delete" ON factory_listings;
CREATE POLICY "fl_select" ON factory_listings FOR SELECT
  USING (status = 'approved' OR uid = auth.uid() OR public.is_my_platform_owner());
CREATE POLICY "fl_insert" ON factory_listings FOR INSERT WITH CHECK (uid = auth.uid());
CREATE POLICY "fl_update" ON factory_listings FOR UPDATE
  USING (uid = auth.uid() OR public.is_my_platform_owner());
CREATE POLICY "fl_delete" ON factory_listings FOR DELETE
  USING (uid = auth.uid() OR public.is_my_platform_owner());

-- RPCs المصانع
CREATE OR REPLACE FUNCTION post_factory_listing(
  p_category_key text, p_title text, p_description text,
  p_location text, p_image_urls text[], p_specs jsonb,
  p_price_min numeric, p_price_max numeric, p_price_unit text,
  p_whatsapp text, p_phone text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_id uuid; v_name text; v_avatar text; v_membership text;
BEGIN
  SELECT COALESCE(display_name, username), avatar_url
  INTO v_name, v_avatar FROM profiles WHERE user_id = auth.uid() LIMIT 1;
  SELECT COALESCE(
    (SELECT tier FROM user_subscriptions WHERE user_id = auth.uid()
     AND status='active' ORDER BY created_at DESC LIMIT 1), 'free'
  ) INTO v_membership;
  INSERT INTO factory_listings(category_key, uid, title, description, location,
    image_urls, specs, price_min, price_max, price_unit, whatsapp, phone,
    owner_name, owner_avatar_url, owner_membership)
  VALUES(p_category_key, auth.uid(), p_title, p_description, p_location,
    p_image_urls, p_specs, p_price_min, p_price_max, p_price_unit, p_whatsapp, p_phone,
    v_name, v_avatar, v_membership)
  RETURNING id INTO v_id;
  UPDATE factory_categories SET listings_count = listings_count + 1 WHERE key = p_category_key;
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION owner_approve_factory_listing(p_listing_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  UPDATE factory_listings SET status = 'approved' WHERE id = p_listing_id;
END;$$;

CREATE OR REPLACE FUNCTION owner_reject_factory_listing(p_listing_id uuid, p_reason text DEFAULT '')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  UPDATE factory_listings SET status = 'rejected', owner_note = p_reason WHERE id = p_listing_id;
END;$$;

CREATE OR REPLACE FUNCTION owner_feature_factory_listing(p_listing_id uuid, p_featured boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  UPDATE factory_listings SET is_featured = p_featured WHERE id = p_listing_id;
END;$$;

CREATE OR REPLACE FUNCTION owner_delete_factory_listing(p_listing_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  DELETE FROM factory_listings WHERE id = p_listing_id;
END;$$;

CREATE OR REPLACE FUNCTION increment_factory_listing_views(p_listing_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN UPDATE factory_listings SET views_count = views_count + 1 WHERE id = p_listing_id; END;$$;

CREATE OR REPLACE FUNCTION owner_upsert_factory_category(
  p_key text, p_name_ar text, p_description text,
  p_emoji text, p_banner_url text,
  p_bg_color_start text, p_bg_color_end text,
  p_sort_order integer, p_is_active boolean
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  INSERT INTO factory_categories(key, name_ar, description, emoji, banner_url,
    bg_color_start, bg_color_end, sort_order, is_active)
  VALUES(p_key, p_name_ar, p_description, p_emoji, p_banner_url,
    p_bg_color_start, p_bg_color_end, p_sort_order, p_is_active)
  ON CONFLICT(key) DO UPDATE SET
    name_ar = p_name_ar, description = p_description, emoji = p_emoji,
    banner_url = p_banner_url, bg_color_start = p_bg_color_start,
    bg_color_end = p_bg_color_end, sort_order = p_sort_order, is_active = p_is_active;
END;$$;

-- View للإدارة
CREATE OR REPLACE VIEW factory_listings_admin_view AS
SELECT fl.*, fc.name_ar AS category_name, fc.emoji
FROM factory_listings fl
LEFT JOIN factory_categories fc ON fc.key = fl.category_key;

-- ─────────────────────────────────────────────────────────────────────
-- 6. المناقصات
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tenders (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uid            uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title          text NOT NULL,
  description    text NOT NULL,
  requirements   text,
  budget_min     numeric,
  budget_max     numeric,
  currency       text DEFAULT 'USD',
  location       text,
  quantity       integer,
  quantity_unit  text DEFAULT 'قطعة',
  category       text NOT NULL DEFAULT 'other',
  deadline       timestamptz,
  status         text NOT NULL DEFAULT 'open', -- open|closed|cancelled|awarded
  awarded_bid_id uuid,
  bids_count     integer NOT NULL DEFAULT 0,
  is_featured    boolean NOT NULL DEFAULT false,
  owner_note     text,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_tenders_status   ON tenders(status);
CREATE INDEX IF NOT EXISTS idx_tenders_category ON tenders(category);

ALTER TABLE tenders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tender_select" ON tenders;
DROP POLICY IF EXISTS "tender_insert" ON tenders;
DROP POLICY IF EXISTS "tender_update" ON tenders;
DROP POLICY IF EXISTS "tender_delete" ON tenders;
CREATE POLICY "tender_select" ON tenders FOR SELECT USING (true);
CREATE POLICY "tender_insert" ON tenders FOR INSERT WITH CHECK (uid = auth.uid());
CREATE POLICY "tender_update" ON tenders FOR UPDATE
  USING (uid = auth.uid() OR public.is_my_platform_owner());
CREATE POLICY "tender_delete" ON tenders FOR DELETE
  USING (uid = auth.uid() OR public.is_my_platform_owner());

CREATE TABLE IF NOT EXISTS tender_bids (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tender_id     uuid NOT NULL REFERENCES tenders(id) ON DELETE CASCADE,
  uid           uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  price         numeric NOT NULL,
  currency      text DEFAULT 'USD',
  delivery_days integer,
  note          text,
  attachment_url text,
  status        text NOT NULL DEFAULT 'pending',
  owner_note    text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tender_id, uid)
);
ALTER TABLE tender_bids ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tbid_select" ON tender_bids;
DROP POLICY IF EXISTS "tbid_insert" ON tender_bids;
DROP POLICY IF EXISTS "tbid_update" ON tender_bids;
DROP POLICY IF EXISTS "tbid_delete" ON tender_bids;
CREATE POLICY "tbid_select" ON tender_bids FOR SELECT
  USING (uid = auth.uid()
    OR EXISTS (SELECT 1 FROM tenders WHERE id = tender_id AND uid = auth.uid())
    OR public.is_my_platform_owner());
CREATE POLICY "tbid_insert" ON tender_bids FOR INSERT WITH CHECK (uid = auth.uid());
CREATE POLICY "tbid_update" ON tender_bids FOR UPDATE
  USING (uid = auth.uid() OR public.is_my_platform_owner());
CREATE POLICY "tbid_delete" ON tender_bids FOR DELETE
  USING (uid = auth.uid() OR public.is_my_platform_owner());

CREATE OR REPLACE FUNCTION post_tender(
  p_title text, p_description text, p_requirements text,
  p_budget_min numeric, p_budget_max numeric, p_currency text,
  p_location text, p_quantity integer, p_quantity_unit text,
  p_category text, p_deadline timestamptz
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO tenders(uid, title, description, requirements, budget_min, budget_max,
    currency, location, quantity, quantity_unit, category, deadline)
  VALUES(auth.uid(), p_title, p_description, p_requirements, p_budget_min, p_budget_max,
    p_currency, p_location, p_quantity, p_quantity_unit, p_category, p_deadline)
  RETURNING id INTO v_id;
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION submit_tender_bid(
  p_tender_id uuid, p_price numeric, p_currency text,
  p_delivery_days integer, p_note text, p_attachment_url text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_id uuid; v_status text;
BEGIN
  SELECT status INTO v_status FROM tenders WHERE id = p_tender_id;
  IF v_status != 'open' THEN RAISE EXCEPTION 'tender_not_open'; END IF;
  IF EXISTS (SELECT 1 FROM tenders WHERE id = p_tender_id AND uid = auth.uid()) THEN
    RAISE EXCEPTION 'cannot_bid_own_tender';
  END IF;
  INSERT INTO tender_bids(tender_id, uid, price, currency, delivery_days, note, attachment_url)
  VALUES(p_tender_id, auth.uid(), p_price, p_currency, p_delivery_days, p_note, p_attachment_url)
  RETURNING id INTO v_id;
  UPDATE tenders SET bids_count = bids_count + 1 WHERE id = p_tender_id;
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION owner_moderate_tender(
  p_tender_id uuid, p_action text, p_note text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  CASE p_action
    WHEN 'close'     THEN UPDATE tenders SET status = 'closed',    owner_note = p_note WHERE id = p_tender_id;
    WHEN 'cancel'    THEN UPDATE tenders SET status = 'cancelled', owner_note = p_note WHERE id = p_tender_id;
    WHEN 'feature'   THEN UPDATE tenders SET is_featured = true   WHERE id = p_tender_id;
    WHEN 'unfeature' THEN UPDATE tenders SET is_featured = false  WHERE id = p_tender_id;
    WHEN 'delete'    THEN DELETE FROM tenders WHERE id = p_tender_id;
    ELSE RAISE EXCEPTION 'unknown_action';
  END CASE;
END;$$;

CREATE OR REPLACE FUNCTION owner_moderate_tender_bid(
  p_bid_id uuid, p_action text, p_note text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_tender_id uuid;
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  SELECT tender_id INTO v_tender_id FROM tender_bids WHERE id = p_bid_id;
  CASE p_action
    WHEN 'accept' THEN
      UPDATE tender_bids SET status = 'accepted', owner_note = p_note WHERE id = p_bid_id;
      UPDATE tenders SET status = 'awarded', awarded_bid_id = p_bid_id WHERE id = v_tender_id;
    WHEN 'reject' THEN
      UPDATE tender_bids SET status = 'rejected', owner_note = p_note WHERE id = p_bid_id;
    WHEN 'delete' THEN
      DELETE FROM tender_bids WHERE id = p_bid_id;
      UPDATE tenders SET bids_count = GREATEST(0, bids_count - 1) WHERE id = v_tender_id;
    ELSE RAISE EXCEPTION 'unknown_action';
  END CASE;
END;$$;

-- ─────────────────────────────────────────────────────────────────────
-- 7. الطلبات الخارجية
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS external_requests (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uid             uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title           text NOT NULL,
  description     text NOT NULL,
  product_type    text,
  target_country  text NOT NULL,
  delivery_port   text,
  quantity        integer,
  quantity_unit   text DEFAULT 'piece',
  incoterms       text DEFAULT 'FOB',
  payment_terms   text,
  certification   text[] DEFAULT '{}',
  sample_required boolean NOT NULL DEFAULT false,
  budget_usd      numeric,
  status          text NOT NULL DEFAULT 'open',
  bids_count      integer NOT NULL DEFAULT 0,
  is_featured     boolean NOT NULL DEFAULT false,
  owner_note      text,
  awarded_bid_id  uuid,
  deadline        timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ext_req_status  ON external_requests(status);
CREATE INDEX IF NOT EXISTS idx_ext_req_country ON external_requests(target_country);

ALTER TABLE external_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "er_select" ON external_requests;
DROP POLICY IF EXISTS "er_insert" ON external_requests;
DROP POLICY IF EXISTS "er_update" ON external_requests;
DROP POLICY IF EXISTS "er_delete" ON external_requests;
CREATE POLICY "er_select" ON external_requests FOR SELECT USING (true);
CREATE POLICY "er_insert" ON external_requests FOR INSERT WITH CHECK (uid = auth.uid());
CREATE POLICY "er_update" ON external_requests FOR UPDATE
  USING (uid = auth.uid() OR public.is_my_platform_owner());
CREATE POLICY "er_delete" ON external_requests FOR DELETE
  USING (uid = auth.uid() OR public.is_my_platform_owner());

CREATE TABLE IF NOT EXISTS external_request_bids (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id           uuid NOT NULL REFERENCES external_requests(id) ON DELETE CASCADE,
  uid                  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  price_usd            numeric NOT NULL,
  delivery_days        integer,
  note                 text,
  attachment_url       text,
  incoterms_offered    text,
  payment_terms_offered text,
  status               text NOT NULL DEFAULT 'pending',
  owner_note           text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE(request_id, uid)
);
ALTER TABLE external_request_bids ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "erb_select" ON external_request_bids;
DROP POLICY IF EXISTS "erb_insert" ON external_request_bids;
DROP POLICY IF EXISTS "erb_update" ON external_request_bids;
DROP POLICY IF EXISTS "erb_delete" ON external_request_bids;
CREATE POLICY "erb_select" ON external_request_bids FOR SELECT
  USING (uid = auth.uid()
    OR EXISTS (SELECT 1 FROM external_requests WHERE id = request_id AND uid = auth.uid())
    OR public.is_my_platform_owner());
CREATE POLICY "erb_insert" ON external_request_bids FOR INSERT WITH CHECK (uid = auth.uid());
CREATE POLICY "erb_update" ON external_request_bids FOR UPDATE
  USING (uid = auth.uid() OR public.is_my_platform_owner());
CREATE POLICY "erb_delete" ON external_request_bids FOR DELETE
  USING (uid = auth.uid() OR public.is_my_platform_owner());

CREATE OR REPLACE FUNCTION post_external_request(
  p_title text, p_description text, p_product_type text,
  p_target_country text, p_delivery_port text,
  p_quantity integer, p_quantity_unit text, p_incoterms text,
  p_payment_terms text, p_certification text[],
  p_sample_required boolean, p_budget_usd numeric, p_deadline timestamptz
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO external_requests(uid, title, description, product_type, target_country,
    delivery_port, quantity, quantity_unit, incoterms, payment_terms, certification,
    sample_required, budget_usd, deadline)
  VALUES(auth.uid(), p_title, p_description, p_product_type, p_target_country,
    p_delivery_port, p_quantity, p_quantity_unit, p_incoterms, p_payment_terms,
    p_certification, p_sample_required, p_budget_usd, p_deadline)
  RETURNING id INTO v_id;
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION respond_to_external_request(
  p_request_id uuid, p_price_usd numeric, p_delivery_days integer,
  p_note text, p_attachment_url text,
  p_incoterms_offered text, p_payment_terms_offered text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM external_requests WHERE id = p_request_id AND uid = auth.uid()) THEN
    RAISE EXCEPTION 'cannot_respond_own_request';
  END IF;
  INSERT INTO external_request_bids(request_id, uid, price_usd, delivery_days, note,
    attachment_url, incoterms_offered, payment_terms_offered)
  VALUES(p_request_id, auth.uid(), p_price_usd, p_delivery_days, p_note,
    p_attachment_url, p_incoterms_offered, p_payment_terms_offered)
  RETURNING id INTO v_id;
  UPDATE external_requests SET bids_count = bids_count + 1 WHERE id = p_request_id;
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION owner_moderate_external_request(
  p_request_id uuid, p_action text, p_note text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  CASE p_action
    WHEN 'close'     THEN UPDATE external_requests SET status = 'closed', owner_note = p_note WHERE id = p_request_id;
    WHEN 'feature'   THEN UPDATE external_requests SET is_featured = true  WHERE id = p_request_id;
    WHEN 'unfeature' THEN UPDATE external_requests SET is_featured = false WHERE id = p_request_id;
    WHEN 'delete'    THEN DELETE FROM external_requests WHERE id = p_request_id;
    ELSE RAISE EXCEPTION 'unknown_action';
  END CASE;
END;$$;

CREATE OR REPLACE FUNCTION owner_moderate_external_bid(
  p_bid_id uuid, p_action text, p_note text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_request_id uuid;
BEGIN
  IF NOT public.is_my_platform_owner() THEN RAISE EXCEPTION 'permission_denied'; END IF;
  SELECT request_id INTO v_request_id FROM external_request_bids WHERE id = p_bid_id;
  CASE p_action
    WHEN 'accept' THEN
      UPDATE external_request_bids SET status = 'accepted', owner_note = p_note WHERE id = p_bid_id;
      UPDATE external_requests SET status = 'awarded', awarded_bid_id = p_bid_id WHERE id = v_request_id;
    WHEN 'reject' THEN
      UPDATE external_request_bids SET status = 'rejected', owner_note = p_note WHERE id = p_bid_id;
    WHEN 'delete' THEN
      DELETE FROM external_request_bids WHERE id = p_bid_id;
      UPDATE external_requests SET bids_count = GREATEST(0, bids_count - 1) WHERE id = v_request_id;
    ELSE RAISE EXCEPTION 'unknown_action';
  END CASE;
END;$$;

-- ─────────────────────────────────────────────────────────────────────
-- DONE
-- ─────────────────────────────────────────────────────────────────────
