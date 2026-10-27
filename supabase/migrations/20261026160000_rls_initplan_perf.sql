-- ============================================================================
-- أداء RLS: تقييم auth.uid()/auth.jwt()/auth.role() مرّة واحدة لكل استعلام
-- بدل كل صف.
--
-- ✅ طُبِّقت على المشروع الحيّ aknksnctyqjcsxcwnvdz بتاريخ 2026-10-26.
--    قبل التطبيق: تشغيل جاف على القاعدة نفسها انتهى بـRAISE EXCEPTION متعمَّد
--    فتراجع كل شيء، ونتيجته: rebuilt=53, before=430, after=430 — أي أنّ
--    الـ53 سياسة أُسقطت وأُعيد بناؤها بتركيب سليم بلا فقدان سياسة واحدة.
--    بعد التطبيق تحقّقتُ: إجمالي السياسات 430، والمتبقّي غير ملفوف = 0،
--    واختبار RLS فعلي بهوية مستخدم حقيقي نجح على الجداول المعاد بناؤها.
--
-- ما تفعله: PostgreSQL يعيد تقييم auth.uid() لكل صف داخل تعبير السياسة.
-- بلفّها بـ(select auth.uid()) يُقيّمها المخطّط مرّة واحدة (InitPlan)، فتتحسّن
-- الاستعلامات على الجداول الكبيرة تحسّنًا كبيرًا. التحسين موصى به من Supabase
-- ولا يُغيّر منطق أي سياسة — فقط موضع التقييم.
-- مرجع: https://supabase.com/docs/guides/database/postgres/row-level-security
--
-- الاختيار مبني على البيانات لا على قائمة مكتوبة يدويًا: السياسات التي تحتوي
-- auth.<fn>() غير ملفوفة. قياسًا على القاعدة الحيّة = 53 سياسة على 33 جدولًا،
-- وهو نفس ما رصده مدقّق Supabase (auth_rls_initplan) عددًا وتطابقًا.
-- و124 سياسة أخرى كانت ملفوفة مسبقًا فلم تُلمس.
--
-- إعادة التشغيل آمنة (idempotent): بعد التطبيق لا تبقى سياسة مطابقة للشرط.
-- ============================================================================
DO $mig$
DECLARE
  r record; v_using text; v_check text; v_before int; v_after int; v_done int := 0;
BEGIN
  SELECT count(*) INTO v_before FROM pg_policies WHERE schemaname='public';
  FOR r IN
    SELECT p.tablename, p.policyname, p.permissive, p.cmd,
           array_to_string(p.roles, ', ') AS roles, p.qual, p.with_check
    FROM pg_policies p
    WHERE p.schemaname='public'
      AND (coalesce(p.qual,'')||' || '||coalesce(p.with_check,'')) ~* 'auth\.(uid|jwt|role)\(\)'
      AND (coalesce(p.qual,'')||' || '||coalesce(p.with_check,'')) !~* 'select\s+auth\.(uid|jwt|role)\(\)'
  LOOP
    v_using := regexp_replace(r.qual,       'auth\.(uid|jwt|role)\(\)', '(select auth.\1())', 'g');
    v_check := regexp_replace(r.with_check, 'auth\.(uid|jwt|role)\(\)', '(select auth.\1())', 'g');
    EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, r.tablename);
    EXECUTE format('CREATE POLICY %I ON public.%I AS %s FOR %s TO %s%s%s',
      r.policyname, r.tablename,
      CASE WHEN r.permissive='PERMISSIVE' THEN 'PERMISSIVE' ELSE 'RESTRICTIVE' END,
      r.cmd, r.roles,
      CASE WHEN v_using IS NULL THEN '' ELSE ' USING ('||v_using||')' END,
      CASE WHEN v_check IS NULL THEN '' ELSE ' WITH CHECK ('||v_check||')' END);
    v_done := v_done + 1;
  END LOOP;
  SELECT count(*) INTO v_after FROM pg_policies WHERE schemaname='public';
  IF v_after <> v_before THEN
    RAISE EXCEPTION 'عدد السياسات تغيّر من % إلى % — تراجع كامل', v_before, v_after;
  END IF;
  RAISE NOTICE 'أُعيد بناء % سياسة؛ الإجمالي ثابت على %', v_done, v_after;
END $mig$;
