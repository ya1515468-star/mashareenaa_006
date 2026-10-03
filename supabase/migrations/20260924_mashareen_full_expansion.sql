-- ═══════════════════════════════════════════════════════════════════════════
-- MASHAREEN — الهجرة الكاملة للتوسع الكبير
-- سوق المنتجين + المناقصات + الطلبات الخارجية
-- + فئات الألبسة + خلفيات الغرف + بانر الموسم
-- المالك يتحكم في كل شيء
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. جدول خلفيات الغرف chat_room_backgrounds
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS chat_room_backgrounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  background_url text NOT NULL,
  uploaded_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- تأكيد إضافة عمود background_url لجدول chat_rooms إن لم يكن موجوداً
ALTER TABLE chat_rooms ADD COLUMN IF NOT EXISTS background_url text;

-- RLS خلفيات الغرف
ALTER TABLE chat_room_backgrounds ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anyone can see room backgrounds"
  ON chat_room_backgrounds FOR SELECT USING (true);
CREATE POLICY "room admins can manage backgrounds"
  ON chat_room_backgrounds FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.uid = auth.uid()
      AND ur.role IN ('owner', 'admin', 'moderator')
    )
  );

-- RPC: set_room_background
CREATE OR REPLACE FUNCTION set_room_background(
  p_room_id uuid,
  p_background_url text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_is_admin boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role IN ('owner','admin','moderator')
  ) INTO v_is_admin;
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;
  UPDATE chat_rooms SET background_url = p_background_url WHERE id = p_room_id;
  INSERT INTO chat_room_backgrounds (room_id, background_url, uploaded_by)
  VALUES (p_room_id, p_background_url, auth.uid());
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. خلفيات الدردشة الخاصة (DM backgrounds)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dm_backgrounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uid uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  thread_id uuid NOT NULL,
  background_url text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (uid, thread_id)
);

ALTER TABLE dm_backgrounds ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users manage own dm backgrounds"
  ON dm_backgrounds FOR ALL
  USING (uid = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. سوق المنتجين — producer_reels
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS producer_reels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uid uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_url text NOT NULL,
  thumbnail_url text,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  category text NOT NULL DEFAULT 'other',
  tags text[] DEFAULT '{}',
  likes_count integer NOT NULL DEFAULT 0,
  views_count integer NOT NULL DEFAULT 0,
  saves_count integer NOT NULL DEFAULT 0,
  comments_count integer NOT NULL DEFAULT 0,
  shares_count integer NOT NULL DEFAULT 0,
  downloads_count integer NOT NULL DEFAULT 0,
  liked_by uuid[] DEFAULT '{}',
  saved_by uuid[] DEFAULT '{}',
  is_approved boolean NOT NULL DEFAULT false,
  is_featured boolean NOT NULL DEFAULT false,
  owner_note text,
  points_cost integer NOT NULL DEFAULT 0,
  published_month text, -- YYYY-MM للتتبع الشهري
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- فهرسة
CREATE INDEX IF NOT EXISTS idx_producer_reels_uid ON producer_reels(uid);
CREATE INDEX IF NOT EXISTS idx_producer_reels_category ON producer_reels(category);
CREATE INDEX IF NOT EXISTS idx_producer_reels_approved ON producer_reels(is_approved);
CREATE INDEX IF NOT EXISTS idx_producer_reels_month ON producer_reels(published_month);

-- RLS
ALTER TABLE producer_reels ENABLE ROW LEVEL SECURITY;
CREATE POLICY "approved reels visible to all"
  ON producer_reels FOR SELECT
  USING (is_approved = true OR uid = auth.uid());
CREATE POLICY "users insert own reels"
  ON producer_reels FOR INSERT
  WITH CHECK (uid = auth.uid());
CREATE POLICY "users update own reels"
  ON producer_reels FOR UPDATE
  USING (uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));
CREATE POLICY "owner can delete any reel"
  ON producer_reels FOR DELETE
  USING (uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));

-- تعليقات الريلات
CREATE TABLE IF NOT EXISTS reel_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reel_id uuid NOT NULL REFERENCES producer_reels(id) ON DELETE CASCADE,
  uid uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE reel_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anyone can see reel comments"
  ON reel_comments FOR SELECT USING (true);
CREATE POLICY "users insert own comments"
  ON reel_comments FOR INSERT WITH CHECK (uid = auth.uid());
CREATE POLICY "users delete own comments or owner"
  ON reel_comments FOR DELETE
  USING (uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));

-- بانر الموسم
CREATE TABLE IF NOT EXISTS market_season_banner (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL DEFAULT '',
  season_date text, -- مثال: "شتاء 2025"
  season_gif_url text,
  background_url text,
  title_effects jsonb DEFAULT '{}',
  is_active boolean NOT NULL DEFAULT false,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE market_season_banner ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anyone can see active banner"
  ON market_season_banner FOR SELECT USING (true);
CREATE POLICY "only owner manages banners"
  ON market_season_banner FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));

-- ─────────────────────────────────────────────────────────────────────────────
-- حصة نشر الريلات حسب العضوية
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reel_publish_quota (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membership_tier text NOT NULL UNIQUE, -- free, bronze, silver, gold, vip
  monthly_limit integer NOT NULL DEFAULT 0, -- -1 = unlimited
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- قيم افتراضية
INSERT INTO reel_publish_quota (membership_tier, monthly_limit) VALUES
  ('free', 0),
  ('bronze', 5),
  ('silver', 15),
  ('gold', 30),
  ('vip', -1)
ON CONFLICT (membership_tier) DO NOTHING;

-- RLS
ALTER TABLE reel_publish_quota ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anyone can see quota"
  ON reel_publish_quota FOR SELECT USING (true);
CREATE POLICY "only owner changes quota"
  ON reel_publish_quota FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));

-- ─────────────────────────────────────────────────────────────────────────────
-- RPCs: سوق المنتجين
-- ─────────────────────────────────────────────────────────────────────────────

-- فحص الحصة الشهرية
CREATE OR REPLACE FUNCTION get_my_reel_publish_quota()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tier text;
  v_limit integer;
  v_used integer;
  v_current_month text := to_char(now(), 'YYYY-MM');
BEGIN
  -- جلب العضوية الحالية
  SELECT COALESCE(
    (SELECT tier FROM user_subscriptions
     WHERE uid = auth.uid()
     AND status = 'active'
     AND expires_at > now()
     ORDER BY created_at DESC LIMIT 1),
    'free'
  ) INTO v_tier;

  -- جلب الحد
  SELECT monthly_limit INTO v_limit
  FROM reel_publish_quota WHERE membership_tier = v_tier;
  IF v_limit IS NULL THEN v_limit := 0; END IF;

  -- عدد الريلات المنشورة هذا الشهر
  SELECT COUNT(*) INTO v_used
  FROM producer_reels
  WHERE uid = auth.uid()
  AND published_month = v_current_month;

  RETURN jsonb_build_object(
    'tier', v_tier,
    'monthly_limit', v_limit,
    'used_this_month', v_used,
    'remaining', CASE WHEN v_limit = -1 THEN 9999 ELSE GREATEST(0, v_limit - v_used) END,
    'unlimited', v_limit = -1
  );
END;
$$;

-- نشر ريل
CREATE OR REPLACE FUNCTION publish_producer_reel(
  p_video_url text,
  p_thumbnail_url text,
  p_title text,
  p_description text,
  p_category text,
  p_tags text[],
  p_points_cost integer
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_quota jsonb;
  v_remaining integer;
  v_reel_id uuid;
  v_current_month text := to_char(now(), 'YYYY-MM');
BEGIN
  -- فحص الحصة
  SELECT get_my_reel_publish_quota() INTO v_quota;
  v_remaining := (v_quota->>'remaining')::integer;
  IF v_remaining <= 0 THEN
    RAISE EXCEPTION 'quota_exceeded: استنفدت حصتك الشهرية. يمكنك ترقية عضويتك للحصول على مزيد من الريلات.';
  END IF;

  -- إدراج الريل
  INSERT INTO producer_reels (
    uid, video_url, thumbnail_url, title, description,
    category, tags, points_cost, published_month, is_approved
  ) VALUES (
    auth.uid(), p_video_url, p_thumbnail_url, p_title, p_description,
    p_category, p_tags, p_points_cost, v_current_month, false
  ) RETURNING id INTO v_reel_id;

  RETURN v_reel_id;
END;
$$;

-- إعجاب/إلغاء إعجاب
CREATE OR REPLACE FUNCTION toggle_reel_like(p_reel_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_liked boolean;
BEGIN
  SELECT v_uid = ANY(liked_by) INTO v_liked FROM producer_reels WHERE id = p_reel_id;
  IF v_liked THEN
    UPDATE producer_reels
    SET liked_by = array_remove(liked_by, v_uid),
        likes_count = GREATEST(0, likes_count - 1)
    WHERE id = p_reel_id;
    RETURN false;
  ELSE
    UPDATE producer_reels
    SET liked_by = array_append(liked_by, v_uid),
        likes_count = likes_count + 1
    WHERE id = p_reel_id;
    RETURN true;
  END IF;
END;
$$;

-- حفظ/إلغاء حفظ
CREATE OR REPLACE FUNCTION toggle_reel_save(p_reel_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_saved boolean;
BEGIN
  SELECT v_uid = ANY(saved_by) INTO v_saved FROM producer_reels WHERE id = p_reel_id;
  IF v_saved THEN
    UPDATE producer_reels
    SET saved_by = array_remove(saved_by, v_uid),
        saves_count = GREATEST(0, saves_count - 1)
    WHERE id = p_reel_id;
    RETURN false;
  ELSE
    UPDATE producer_reels
    SET saved_by = array_append(saved_by, v_uid),
        saves_count = saves_count + 1
    WHERE id = p_reel_id;
    RETURN true;
  END IF;
END;
$$;

-- مشاركة
CREATE OR REPLACE FUNCTION increment_reel_share(p_reel_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE producer_reels SET shares_count = shares_count + 1 WHERE id = p_reel_id;
END;
$$;

-- تحميل
CREATE OR REPLACE FUNCTION increment_reel_download(p_reel_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE producer_reels SET downloads_count = downloads_count + 1 WHERE id = p_reel_id;
END;
$$;

-- مشاهدة
CREATE OR REPLACE FUNCTION increment_reel_view(p_reel_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE producer_reels SET views_count = views_count + 1 WHERE id = p_reel_id;
END;
$$;

-- تعليق
CREATE OR REPLACE FUNCTION add_reel_comment(p_reel_id uuid, p_text text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO reel_comments (reel_id, uid, text) VALUES (p_reel_id, auth.uid(), p_text) RETURNING id INTO v_id;
  UPDATE producer_reels SET comments_count = comments_count + 1 WHERE id = p_reel_id;
  RETURN v_id;
END;
$$;

-- ─── صلاحيات المالك لسوق المنتجين ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION owner_moderate_reel(
  p_reel_id uuid,
  p_action text, -- 'approve', 'reject', 'feature', 'unfeature', 'delete'
  p_note text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner') THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;
  CASE p_action
    WHEN 'approve' THEN
      UPDATE producer_reels SET is_approved = true, owner_note = p_note WHERE id = p_reel_id;
    WHEN 'reject' THEN
      UPDATE producer_reels SET is_approved = false, owner_note = p_note WHERE id = p_reel_id;
    WHEN 'feature' THEN
      UPDATE producer_reels SET is_featured = true WHERE id = p_reel_id;
    WHEN 'unfeature' THEN
      UPDATE producer_reels SET is_featured = false WHERE id = p_reel_id;
    WHEN 'delete' THEN
      DELETE FROM producer_reels WHERE id = p_reel_id;
    ELSE RAISE EXCEPTION 'unknown_action';
  END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION owner_set_market_season_banner(
  p_title text,
  p_season_date text,
  p_season_gif_url text,
  p_background_url text,
  p_title_effects jsonb,
  p_is_active boolean
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner') THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;
  -- إلغاء تفعيل كل البانرات الأخرى
  UPDATE market_season_banner SET is_active = false;
  INSERT INTO market_season_banner (
    title, season_date, season_gif_url, background_url, title_effects, is_active, created_by
  ) VALUES (
    p_title, p_season_date, p_season_gif_url, p_background_url, p_title_effects, p_is_active, auth.uid()
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION owner_update_reel_quota(
  p_tier text,
  p_limit integer
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner') THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;
  INSERT INTO reel_publish_quota (membership_tier, monthly_limit, updated_at)
  VALUES (p_tier, p_limit, now())
  ON CONFLICT (membership_tier) DO UPDATE
  SET monthly_limit = p_limit, updated_at = now();
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. المناقصات — tenders
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tenders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uid uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL,
  requirements text,
  budget_min numeric,
  budget_max numeric,
  currency text DEFAULT 'USD',
  location text,
  quantity integer,
  quantity_unit text DEFAULT 'قطعة',
  category text NOT NULL DEFAULT 'other',
  deadline timestamptz,
  status text NOT NULL DEFAULT 'open', -- open, closed, cancelled, awarded
  awarded_bid_id uuid,
  bids_count integer NOT NULL DEFAULT 0,
  is_featured boolean NOT NULL DEFAULT false,
  owner_note text,
  min_membership text DEFAULT 'free', -- الحد الأدنى للعضوية للتقديم
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tenders_status ON tenders(status);
CREATE INDEX IF NOT EXISTS idx_tenders_category ON tenders(category);
CREATE INDEX IF NOT EXISTS idx_tenders_uid ON tenders(uid);

ALTER TABLE tenders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anyone sees open tenders"
  ON tenders FOR SELECT USING (true);
CREATE POLICY "authenticated users post tenders"
  ON tenders FOR INSERT WITH CHECK (uid = auth.uid() AND auth.uid() IS NOT NULL);
CREATE POLICY "owner or creator update tender"
  ON tenders FOR UPDATE
  USING (uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));
CREATE POLICY "owner or creator delete tender"
  ON tenders FOR DELETE
  USING (uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));

-- عروض المناقصات
CREATE TABLE IF NOT EXISTS tender_bids (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tender_id uuid NOT NULL REFERENCES tenders(id) ON DELETE CASCADE,
  uid uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  price numeric NOT NULL,
  currency text DEFAULT 'USD',
  delivery_days integer,
  note text,
  attachment_url text,
  status text NOT NULL DEFAULT 'pending', -- pending, accepted, rejected
  owner_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tender_id, uid) -- عرض واحد لكل مناقصة
);

ALTER TABLE tender_bids ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tenderer sees own bids, owner sees all"
  ON tender_bids FOR SELECT
  USING (
    uid = auth.uid()
    OR EXISTS (SELECT 1 FROM tenders WHERE id = tender_id AND uid = auth.uid())
    OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner')
  );
CREATE POLICY "users submit bids"
  ON tender_bids FOR INSERT WITH CHECK (uid = auth.uid());
CREATE POLICY "owner or creator update bids"
  ON tender_bids FOR UPDATE
  USING (uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));
CREATE POLICY "owner or creator delete bids"
  ON tender_bids FOR DELETE
  USING (uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));

-- RPCs المناقصات
CREATE OR REPLACE FUNCTION post_tender(
  p_title text,
  p_description text,
  p_requirements text,
  p_budget_min numeric,
  p_budget_max numeric,
  p_currency text,
  p_location text,
  p_quantity integer,
  p_quantity_unit text,
  p_category text,
  p_deadline timestamptz,
  p_min_membership text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO tenders (
    uid, title, description, requirements,
    budget_min, budget_max, currency, location,
    quantity, quantity_unit, category, deadline, min_membership
  ) VALUES (
    auth.uid(), p_title, p_description, p_requirements,
    p_budget_min, p_budget_max, p_currency, p_location,
    p_quantity, p_quantity_unit, p_category, p_deadline, p_min_membership
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION submit_tender_bid(
  p_tender_id uuid,
  p_price numeric,
  p_currency text,
  p_delivery_days integer,
  p_note text,
  p_attachment_url text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id uuid;
  v_status text;
  v_min_membership text;
  v_user_tier text;
BEGIN
  -- فحص حالة المناقصة
  SELECT status, min_membership INTO v_status, v_min_membership
  FROM tenders WHERE id = p_tender_id;
  IF v_status != 'open' THEN RAISE EXCEPTION 'tender_not_open'; END IF;

  -- فحص لا يتقدم على مناقصته الخاصة
  IF EXISTS (SELECT 1 FROM tenders WHERE id = p_tender_id AND uid = auth.uid()) THEN
    RAISE EXCEPTION 'cannot_bid_own_tender';
  END IF;

  INSERT INTO tender_bids (
    tender_id, uid, price, currency, delivery_days, note, attachment_url
  ) VALUES (
    p_tender_id, auth.uid(), p_price, p_currency, p_delivery_days, p_note, p_attachment_url
  ) RETURNING id INTO v_id;

  UPDATE tenders SET bids_count = bids_count + 1 WHERE id = p_tender_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION owner_moderate_tender(
  p_tender_id uuid,
  p_action text, -- 'close', 'cancel', 'feature', 'unfeature', 'delete'
  p_note text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner') THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;
  CASE p_action
    WHEN 'close' THEN UPDATE tenders SET status = 'closed', owner_note = p_note WHERE id = p_tender_id;
    WHEN 'cancel' THEN UPDATE tenders SET status = 'cancelled', owner_note = p_note WHERE id = p_tender_id;
    WHEN 'feature' THEN UPDATE tenders SET is_featured = true WHERE id = p_tender_id;
    WHEN 'unfeature' THEN UPDATE tenders SET is_featured = false WHERE id = p_tender_id;
    WHEN 'delete' THEN DELETE FROM tenders WHERE id = p_tender_id;
    ELSE RAISE EXCEPTION 'unknown_action';
  END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION owner_moderate_tender_bid(
  p_bid_id uuid,
  p_action text, -- 'accept', 'reject', 'delete'
  p_note text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_tender_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner') THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;
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
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. الطلبات الخارجية — external_requests
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS external_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uid uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL,
  product_type text, -- نوع المنتج
  target_country text NOT NULL,
  delivery_port text,
  quantity integer,
  quantity_unit text DEFAULT 'piece',
  incoterms text DEFAULT 'FOB', -- FOB, CIF, EXW, DDP, CFR
  payment_terms text, -- LC, TT, DA, DP
  certification text[], -- ISO, OEKO-TEX, etc.
  sample_required boolean NOT NULL DEFAULT false,
  budget_usd numeric,
  status text NOT NULL DEFAULT 'open', -- open, closed, awarded, cancelled
  bids_count integer NOT NULL DEFAULT 0,
  is_featured boolean NOT NULL DEFAULT false,
  owner_note text,
  awarded_bid_id uuid,
  deadline timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_external_requests_status ON external_requests(status);
CREATE INDEX IF NOT EXISTS idx_external_requests_country ON external_requests(target_country);
CREATE INDEX IF NOT EXISTS idx_external_requests_uid ON external_requests(uid);

ALTER TABLE external_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anyone sees external requests"
  ON external_requests FOR SELECT USING (true);
CREATE POLICY "users post requests"
  ON external_requests FOR INSERT WITH CHECK (uid = auth.uid());
CREATE POLICY "owner or creator update"
  ON external_requests FOR UPDATE
  USING (uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));
CREATE POLICY "owner or creator delete"
  ON external_requests FOR DELETE
  USING (uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));

-- عروض الطلبات الخارجية
CREATE TABLE IF NOT EXISTS external_request_bids (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES external_requests(id) ON DELETE CASCADE,
  uid uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  price_usd numeric NOT NULL,
  delivery_days integer,
  note text,
  attachment_url text, -- ملف PDF العرض التجاري
  incoterms_offered text,
  payment_terms_offered text,
  status text NOT NULL DEFAULT 'pending',
  owner_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (request_id, uid)
);

ALTER TABLE external_request_bids ENABLE ROW LEVEL SECURITY;
CREATE POLICY "requester and owner see bids"
  ON external_request_bids FOR SELECT
  USING (
    uid = auth.uid()
    OR EXISTS (SELECT 1 FROM external_requests WHERE id = request_id AND uid = auth.uid())
    OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner')
  );
CREATE POLICY "users submit export bids"
  ON external_request_bids FOR INSERT WITH CHECK (uid = auth.uid());
CREATE POLICY "owner or bidder update"
  ON external_request_bids FOR UPDATE
  USING (uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));
CREATE POLICY "owner or bidder delete"
  ON external_request_bids FOR DELETE
  USING (uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));

-- RPCs الطلبات الخارجية
CREATE OR REPLACE FUNCTION post_external_request(
  p_title text,
  p_description text,
  p_product_type text,
  p_target_country text,
  p_delivery_port text,
  p_quantity integer,
  p_quantity_unit text,
  p_incoterms text,
  p_payment_terms text,
  p_certification text[],
  p_sample_required boolean,
  p_budget_usd numeric,
  p_deadline timestamptz
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO external_requests (
    uid, title, description, product_type, target_country,
    delivery_port, quantity, quantity_unit, incoterms,
    payment_terms, certification, sample_required, budget_usd, deadline
  ) VALUES (
    auth.uid(), p_title, p_description, p_product_type, p_target_country,
    p_delivery_port, p_quantity, p_quantity_unit, p_incoterms,
    p_payment_terms, p_certification, p_sample_required, p_budget_usd, p_deadline
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION respond_to_external_request(
  p_request_id uuid,
  p_price_usd numeric,
  p_delivery_days integer,
  p_note text,
  p_attachment_url text,
  p_incoterms_offered text,
  p_payment_terms_offered text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM external_requests WHERE id = p_request_id AND uid = auth.uid()) THEN
    RAISE EXCEPTION 'cannot_respond_own_request';
  END IF;
  INSERT INTO external_request_bids (
    request_id, uid, price_usd, delivery_days, note,
    attachment_url, incoterms_offered, payment_terms_offered
  ) VALUES (
    p_request_id, auth.uid(), p_price_usd, p_delivery_days, p_note,
    p_attachment_url, p_incoterms_offered, p_payment_terms_offered
  ) RETURNING id INTO v_id;
  UPDATE external_requests SET bids_count = bids_count + 1 WHERE id = p_request_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION owner_moderate_external_request(
  p_request_id uuid,
  p_action text, -- 'close', 'feature', 'unfeature', 'delete'
  p_note text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner') THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;
  CASE p_action
    WHEN 'close' THEN UPDATE external_requests SET status = 'closed', owner_note = p_note WHERE id = p_request_id;
    WHEN 'feature' THEN UPDATE external_requests SET is_featured = true WHERE id = p_request_id;
    WHEN 'unfeature' THEN UPDATE external_requests SET is_featured = false WHERE id = p_request_id;
    WHEN 'delete' THEN DELETE FROM external_requests WHERE id = p_request_id;
    ELSE RAISE EXCEPTION 'unknown_action';
  END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION owner_moderate_external_bid(
  p_bid_id uuid,
  p_action text, -- 'accept', 'reject', 'delete'
  p_note text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_request_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner') THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;
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
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. فئات الألبسة — garment_categories & garment_listings
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS garment_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text NOT NULL UNIQUE,
  name_ar text NOT NULL,
  description text NOT NULL DEFAULT '',
  emoji text NOT NULL DEFAULT '🏷️',
  banner_url text,
  bg_gradient_start text DEFAULT '#1A3A5C',
  bg_gradient_end text DEFAULT '#0D1F35',
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  listings_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- إدراج الفئات الافتراضية
INSERT INTO garment_categories (key, name_ar, description, emoji, sort_order)
VALUES
  ('packaging', 'أمبلاج', 'خدمات التغليف والأمبلاج لقطاع الألبسة', '📦', 1),
  ('cutting', 'قطاعة', 'خدمات القطع والتفصيل بأحدث المعدات', '✂️', 2),
  ('washing', 'غسيل', 'محطات الغسيل الصناعي ومعالجة الأقمشة', '🫧', 3),
  ('dyeing', 'صباغة', 'محطات الصباغة والتلوين', '🎨', 4),
  ('embroidery', 'تطريز', 'تطريز آلي ويدوي', '🪡', 5),
  ('ironing', 'كوي', 'خدمات الكوي والتشطيب', '🔥', 6),
  ('printing', 'طباعة', 'طباعة رقمية وحريرية على الأقمشة', '🖨️', 7),
  ('fabric', 'أقمشة', 'بيع وتوريد الأقمشة', '🧵', 8),
  ('accessories', 'إكسسوار', 'مستلزمات الخياطة والإكسسوارات', '💎', 9),
  ('pattern', 'باترون', 'تصميم وبيع الباترونات', '📐', 10),
  ('workshop', 'ورشات', 'ورشات خياطة للتعاقد والإنتاج', '🏭', 11),
  ('other', 'أخرى', 'خدمات ومنتجات متنوعة', '🏷️', 12)
ON CONFLICT (key) DO NOTHING;

ALTER TABLE garment_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anyone sees active categories"
  ON garment_categories FOR SELECT USING (is_active = true OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));
CREATE POLICY "only owner manages categories"
  ON garment_categories FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));

-- جدول إعلانات الأقسام
CREATE TABLE IF NOT EXISTS garment_listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_key text NOT NULL,
  uid uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL,
  location text,
  image_urls text[] DEFAULT '{}',
  specs jsonb DEFAULT '{}',
  price_min numeric,
  price_max numeric,
  price_unit text,
  whatsapp text,
  phone text,
  is_featured boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'pending', -- pending, approved, rejected
  views_count integer NOT NULL DEFAULT 0,
  owner_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  -- بيانات المنشئ (مُنسوخة)
  owner_name text,
  owner_avatar_url text,
  owner_membership text
);

CREATE INDEX IF NOT EXISTS idx_garment_listings_category ON garment_listings(category_key);
CREATE INDEX IF NOT EXISTS idx_garment_listings_status ON garment_listings(status);
CREATE INDEX IF NOT EXISTS idx_garment_listings_uid ON garment_listings(uid);

ALTER TABLE garment_listings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "approved listings visible to all"
  ON garment_listings FOR SELECT
  USING (status = 'approved' OR uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));
CREATE POLICY "users insert own listings"
  ON garment_listings FOR INSERT WITH CHECK (uid = auth.uid());
CREATE POLICY "users update own or owner"
  ON garment_listings FOR UPDATE
  USING (uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));
CREATE POLICY "users delete own or owner"
  ON garment_listings FOR DELETE
  USING (uid = auth.uid() OR EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner'));

-- RPC نشر إعلان
CREATE OR REPLACE FUNCTION post_garment_listing(
  p_category_key text,
  p_title text,
  p_description text,
  p_location text,
  p_image_urls text[],
  p_specs jsonb,
  p_price_min numeric,
  p_price_max numeric,
  p_price_unit text,
  p_whatsapp text,
  p_phone text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id uuid;
  v_name text;
  v_avatar text;
  v_membership text;
BEGIN
  -- جلب بيانات المستخدم
  SELECT
    COALESCE(display_name, username),
    avatar_url
  INTO v_name, v_avatar
  FROM profiles WHERE uid = auth.uid();

  SELECT COALESCE(
    (SELECT tier FROM user_subscriptions WHERE uid = auth.uid() AND status = 'active' ORDER BY created_at DESC LIMIT 1),
    'free'
  ) INTO v_membership;

  INSERT INTO garment_listings (
    category_key, uid, title, description, location,
    image_urls, specs, price_min, price_max, price_unit,
    whatsapp, phone, owner_name, owner_avatar_url, owner_membership
  ) VALUES (
    p_category_key, auth.uid(), p_title, p_description, p_location,
    p_image_urls, p_specs, p_price_min, p_price_max, p_price_unit,
    p_whatsapp, p_phone, v_name, v_avatar, v_membership
  ) RETURNING id INTO v_id;

  -- تحديث عداد الفئة
  UPDATE garment_categories SET listings_count = listings_count + 1 WHERE key = p_category_key;

  RETURN v_id;
END;
$$;

-- RPCs الإدارة
CREATE OR REPLACE FUNCTION owner_approve_garment_listing(p_listing_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner') THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;
  UPDATE garment_listings SET status = 'approved' WHERE id = p_listing_id;
END;
$$;

CREATE OR REPLACE FUNCTION owner_reject_garment_listing(p_listing_id uuid, p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner') THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;
  UPDATE garment_listings SET status = 'rejected', owner_note = p_reason WHERE id = p_listing_id;
END;
$$;

CREATE OR REPLACE FUNCTION owner_delete_garment_listing(p_listing_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner') THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;
  DELETE FROM garment_listings WHERE id = p_listing_id;
END;
$$;

CREATE OR REPLACE FUNCTION increment_garment_listing_views(p_listing_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE garment_listings SET views_count = views_count + 1 WHERE id = p_listing_id;
END;
$$;

CREATE OR REPLACE FUNCTION owner_upsert_garment_category(
  p_key text, p_name_ar text, p_description text,
  p_banner_url text, p_bg_gradient_start text, p_bg_gradient_end text,
  p_sort_order integer, p_is_active boolean
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_roles WHERE uid = auth.uid() AND role = 'owner') THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;
  INSERT INTO garment_categories (
    key, name_ar, description, banner_url, bg_gradient_start, bg_gradient_end, sort_order, is_active
  ) VALUES (
    p_key, p_name_ar, p_description, p_banner_url, p_bg_gradient_start, p_bg_gradient_end, p_sort_order, p_is_active
  )
  ON CONFLICT (key) DO UPDATE
  SET name_ar = p_name_ar, description = p_description, banner_url = p_banner_url,
      bg_gradient_start = p_bg_gradient_start, bg_gradient_end = p_bg_gradient_end,
      sort_order = p_sort_order, is_active = p_is_active;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. view للإدارة
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW garment_listings_admin_view AS
SELECT gl.*, gc.name_ar as category_name, gc.emoji
FROM garment_listings gl
LEFT JOIN garment_categories gc ON gc.key = gl.category_key;

-- ─────────────────────────────────────────────────────────────────────────────
-- DONE
-- ─────────────────────────────────────────────────────────────────────────────
