-- Production reconciliation for the 20 additional VIP services and the
-- owner-only avatar-frame deletion contract.
-- This migration is intentionally idempotent so the local project contains
-- the same server contract that is already present in production.

BEGIN;

INSERT INTO public.profile_service_catalog
  (feature_key,name_ar,description_ar,category,price_points,price_gems,is_active,sort_order,usage_surface,usage_hint_ar)
VALUES
('profile_theme_plus','ثيم البروفايل Plus','تخصيص نمط البروفايل وحفظ الإعداد على حسابك.','vip',900,9,true,101,'profile','البروفايل ← المظهر'),
('profile_card_plus','بطاقة بروفايل احترافية','بطاقة تعريف موسعة قابلة للتخصيص من صفحة البروفايل.','vip',700,7,true,102,'profile','البروفايل ← البطاقة'),
('profile_highlight','تمييز البروفايل','إبراز البروفايل في واجهات العرض المدعومة.','vip',1100,11,true,103,'profile','البروفايل ← التمييز'),
('profile_visitor_alerts','تنبيهات زوار البروفايل','تسجيل وإظهار تنبيهات زيارة البروفايل.','vip',650,6,true,104,'profile','البروفايل ← الزوار'),
('profile_contact_button','زر تواصل احترافي','إظهار إعدادات زر تواصل مخصص في بطاقة البروفايل.','vip',600,6,true,105,'profile','البروفايل ← التواصل'),
('profile_qr_card','بطاقة QR للبروفايل','إنشاء بطاقة مشاركة للبروفايل مع رمز QR.','vip',500,5,true,106,'profile','البروفايل ← مشاركة'),
('profile_custom_badge','شارة بروفايل مخصصة','تفعيل إعداد شارة مخصصة مرتبطة بالحساب.','vip',1000,10,true,107,'profile','البروفايل ← الشارات'),
('profile_priority_search','أولوية الظهور في البحث','تفعيل أولوية الظهور في نتائج البحث المدعومة.','vip',1300,13,true,108,'profile','البحث ← أولوية الظهور'),
('chat_name_gradient','اسم متدرج في الشات','إعداد نمط لون متدرج لاسم المستخدم في واجهات الشات الداعمة.','vip',800,8,true,109,'chat','الشات ← مظهر الاسم'),
('chat_message_glow','توهج الرسائل','تفعيل إعداد تأثير توهج للرسائل في الواجهات الداعمة.','vip',750,7,true,110,'chat','الشات ← تأثير الرسائل'),
('chat_priority_badge','شارة أولوية الشات','إظهار شارة أولوية للحساب في واجهات الشات الداعمة.','vip',900,9,true,111,'chat','الشات ← شارة الأولوية'),
('chat_mention_highlight','تمييز المنشن','تخصيص تمييز الرسائل التي تذكر اسم المستخدم.','vip',550,5,true,112,'chat','الشات ← المنشن'),
('chat_link_preview_plus','معاينة روابط Plus','تفعيل معاينة روابط موسعة حيث تدعمها واجهة الشات.','vip',650,6,true,113,'chat','الشات ← الروابط'),
('chat_media_plus','وسائط Plus','تفعيل إعدادات وسائط موسعة للحساب في الشات.','vip',850,8,true,114,'chat','الشات ← الوسائط'),
('chat_favorites_plus','مفضلة الشات Plus','حفظ إعدادات مفضلة الشات على الحساب.','vip',450,4,true,115,'chat','الشات ← المفضلة'),
('chat_presence_plus','حضور Plus','إعدادات إضافية لحالة الظهور والحضور في الشات.','vip',700,7,true,116,'chat','الشات ← الحضور'),
('chat_smart_mute','كتم ذكي','حفظ إعدادات كتم ذكي للمحادثات المدعومة.','vip',600,6,true,117,'chat','الشات ← الكتم الذكي'),
('creator_tip_button','زر دعم المنشئ','إعداد زر دعم مالي داخل نقاط الواجهة الداعمة للمنشئ.','vip',900,9,true,118,'both','البروفايل / الشات ← دعم المنشئ'),
('profile_analytics_plus','إحصائيات البروفايل Plus','عرض عدادات استخدام الخدمات والزيارات المتاحة للحساب.','vip',1200,12,true,119,'profile','البروفايل ← الإحصائيات'),
('tailor_pattern_highlight','تمييز باترونات الخياط','تفعيل إعداد إبراز الباترونات في قسم الخياطة.','vip',1000,10,true,120,'both','الخياطة ← الباترونات')
ON CONFLICT (feature_key) DO UPDATE SET
  name_ar=excluded.name_ar,
  description_ar=excluded.description_ar,
  category=excluded.category,
  price_points=excluded.price_points,
  price_gems=excluded.price_gems,
  is_active=excluded.is_active,
  sort_order=excluded.sort_order,
  usage_surface=excluded.usage_surface,
  usage_hint_ar=excluded.usage_hint_ar,
  updated_at=now();

CREATE OR REPLACE FUNCTION public.admin_delete_avatar_frame(p_frame_key text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_key text := lower(trim(coalesce(p_frame_key,'')));
  v_storage_path text;
  v_cleared integer := 0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF v_key = '' THEN RAISE EXCEPTION 'FRAME_KEY_REQUIRED'; END IF;

  SELECT storage_path INTO v_storage_path
  FROM public.avatar_frame_catalog
  WHERE frame_key=v_key;
  IF NOT FOUND THEN RAISE EXCEPTION 'FRAME_NOT_FOUND'; END IF;

  UPDATE public.profiles
  SET avatar_frame_key=NULL, updated_at=now()
  WHERE avatar_frame_key=v_key;
  GET DIAGNOSTICS v_cleared=ROW_COUNT;

  DELETE FROM public.profile_cosmetic_catalog
  WHERE item_key=v_key AND category='frame';
  DELETE FROM public.avatar_frame_catalog WHERE frame_key=v_key;

  -- Storage objects are deleted by the authenticated Edge Function via the Storage API.
  -- Never delete rows directly from storage.objects.

  RETURN jsonb_build_object(
    'ok',true,
    'frame_key',v_key,
    'storage_path',v_storage_path,
    'cleared_profiles',v_cleared
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_delete_avatar_frame(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_avatar_frame(text) TO authenticated;

COMMIT;
