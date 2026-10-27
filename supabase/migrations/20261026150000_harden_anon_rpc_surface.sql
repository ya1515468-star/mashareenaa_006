-- ============================================================================
-- تقوية سطح RPC المكشوف لدور anon + تثبيت search_path
-- طُبِّقت على المشروع الحيّ aknksnctyqjcsxcwnvdz بتاريخ 2026-10-26 وتم التحقّق.
--
-- الخلفية: 27 دالة SECURITY DEFINER كانت قابلة للنداء من دور anon عبر
-- /rest/v1/rpc/... بينها 6 دوال مشغّلات (_trg_*) لا يجوز نداؤها كـRPC أبدًا.
-- السبب: PostgreSQL يمنح EXECUTE لـPUBLIC تلقائيًا عند CREATE FUNCTION.
-- ملاحظة مهمّة: REVOKE ... FROM anon لا يكفي ولا يُغيّر شيئًا، لأنّ المنحة
-- على PUBLIC لا على anon. الصحيح: REVOKE FROM PUBLIC ثم المنح الصريح.
--
-- ما لم يُلمس عن قصد:
--   • public._is_platform_owner(uuid): مستخدمة في 88 سياسة RLS. سحب EXECUTE
--     منها يُعطّل كل استعلام على تلك الجداول (تعبير السياسة يُقيَّم بصلاحية
--     المستخدم السائل)، فتبقى كما هي.
--   • get_login_visual_variant() و is_name_available(text,text): تُنادَيان
--     فعليًا قبل تسجيل الدخول (شاشة الدخول وشاشة التسجيل)، فيبقى anon عليهما
--     لكن بمنحة صريحة بدل منحة PUBLIC الواسعة.
-- ============================================================================
DO $$
DECLARE
  r record;
  trg_fns text[] := array[
    '_trg_accounts_colored_frame_guard','_trg_cosmetic_ownership',
    '_trg_name_effect_ownership','_trg_service_ownership',
    '_trg_store_inventory_ownership','_trg_wallet_credit_notify'];
  auth_fns text[] := array[
    '_garment_contact_visible','get_my_card_face','get_my_wall_access',
    'set_my_card_face','set_my_message_font',
    'get_garment_business_detail','get_garment_service_ad_detail',
    'trix_double','trix_my_table','trix_my_table_invites','trix_open_tables',
    'trix_start_game','trix_table_create','trix_table_invite','trix_table_join',
    'trix_table_leave','trix_table_respond','trix_table_start','trix_table_view'];
  pre_auth_fns text[] := array['get_login_visual_variant','is_name_available'];
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig, p.proname
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY (trg_fns || auth_fns || pre_auth_fns)
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', r.sig);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon', r.sig);
    IF r.proname = ANY (trg_fns) THEN
      NULL;
    ELSIF r.proname = ANY (pre_auth_fns) THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO anon, authenticated, service_role', r.sig);
    ELSE
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', r.sig);
    END IF;
  END LOOP;
END $$;

-- تثبيت search_path: بدونه يُمكن حقن دالة/جدول بنفس الاسم فيُنفَّذ بصلاحية
-- مالك الدالة (SECURITY DEFINER).
ALTER FUNCTION private._le_hex(v bigint, nb integer)                SET search_path = private, public, pg_temp;
ALTER FUNCTION private.c4_bot_move(b integer[], bot integer)        SET search_path = private, public, pg_temp;
ALTER FUNCTION private.c4_drop(b integer[], p_col integer)          SET search_path = private, public, pg_temp;
ALTER FUNCTION private.c4_score(b integer[], me integer)            SET search_path = private, public, pg_temp;
ALTER FUNCTION private.c4_win(b integer[], idx integer, me integer) SET search_path = private, public, pg_temp;
