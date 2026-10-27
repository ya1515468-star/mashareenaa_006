import 'supabase_config.dart';

/// الروابط القانونية العامة التي تخدمها دالة `legal` في الخادم.
///
/// متجر Google Play يشترط رابط **سياسة خصوصية** عاملًا لكل تطبيق يجمع
/// بيانات حساب، ويشترط كذلك مسارًا **خارج التطبيق** لطلب حذف الحساب.
/// وApp Store يشترط رابطي الخصوصية والشروط. الصفحات منشورة أصلًا على
/// الخادم (دالة legal بـverify_jwt=false أي عامة بلا تسجيل دخول)، لكنّ
/// التطبيق لم يكن يربطها في أي مكان — وهذا ما يسدّه هذا الملف.
class LegalLinks {
  const LegalLinks._();

  static const String _base = '${SupabaseConfig.url}/functions/v1/legal';

  static const String privacy = '$_base/privacy';
  static const String terms = '$_base/terms';
  static const String guidelines = '$_base/guidelines';

  /// صفحة طلب حذف الحساب من خارج التطبيق (مطلب Google Play).
  static const String deleteAccount = '$_base/delete';
}
