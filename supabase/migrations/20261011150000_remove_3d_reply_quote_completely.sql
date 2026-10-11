-- البند 11: حذف ميزة «الرد والاقتباس ثلاثي الأبعاد» بالكامل خادميًا.
--
-- العميل لم يبقَ فيه أي قراءة أو كتابة لهذه الميزة: أُزيل الودجت
-- reply_3d_anchor.dart، وقسم «إعدادات الرد والاقتباس 3D» بكامله من صفحة
-- إعدادات الشات، وكل قراءة لـ reply_mode = reply_3d/quote_3d.
--
-- وتحققت بفحص كل دوال public وprivate_rpc أن لا شيء آخر في قاعدة البيانات
-- يرجع إلى هذا الجدول أو دوالّه، فحذفها آمن.
drop function if exists public.dragon_update_chat_feature_settings(boolean, integer, integer, text);
drop function if exists private_rpc.dragon_update_chat_feature_settings(boolean, integer, integer, text);
drop function if exists public.get_chat_feature_settings();
drop function if exists private_rpc.get_chat_feature_settings();
drop table if exists public.chat_feature_settings;
