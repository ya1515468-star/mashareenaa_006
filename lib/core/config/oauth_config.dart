/// معرّفات عملاء OAuth لتسجيل الدخول عبر Google و Apple.
///
/// لماذا هذا الملف موجود:
/// حزمة google_sign_in على أندرويد **لا تُعيد idToken** إلا إذا مُرِّر
/// إليها معرّف عميل الويب (serverClientId). بدونه تكون
/// `googleAuth.idToken == null` دائمًا، فيرمي الكود الخطأ
/// «تعذّر الحصول على Google ID token» في كل محاولة — أي أنّ زر Google
/// لا يعمل إطلاقًا على أندرويد. هذا سبب كون الخيار «غير فعّال».
///
/// ما يجب فعله مرّة واحدة (لا يمكن لأي كود أن يستنتجها):
/// 1) Google Cloud Console → APIs & Services → Credentials:
///    • أنشئ **OAuth client (Web application)** → انسخ Client ID إلى
///      [googleWebClientId] أدناه، وضَع نفسه + Client secret في
///      Supabase → Authentication → Providers → Google.
///    • أنشئ **OAuth client (Android)** بالحزمة
///      `com.mashareena.mashareena` وبصمة SHA-1 لمفتاح التوقيع نفسه
///      الذي تبني به (أسرار ANDROID_KEYSTORE_* في GitHub Actions):
///      `keytool -list -v -keystore <key.jks> -alias <alias>`
///      بدون بصمة SHA-1 الصحيحة يفشل الدخول بالخطأ 10 (DEVELOPER_ERROR).
/// 2) Apple Developer → Identifiers → Services ID (مثل
///    com.mashareena.mashareena.signin) → ضعه في [appleServiceId]
///    وفي Supabase → Providers → Apple.
///
/// اتركها فارغة ويبقى الزر ظاهرًا لكنه يشرح للمستخدم أنّ الخدمة غير
/// مهيّأة بدل أن يفشل برسالة غامضة.
class OAuthConfig {
  const OAuthConfig._();

  /// Client ID من نوع **Web application** (ينتهي بـ .apps.googleusercontent.com).
  static const String googleWebClientId = '';

  /// Services ID من Apple Developer (مطلوب للويب وأندرويد فقط؛
  /// على iOS يُستخدم Bundle ID تلقائيًا).
  static const String appleServiceId = '';

  static bool get googleReady => googleWebClientId.trim().isNotEmpty;
  static bool get appleReady => true; // iOS يعمل بالـBundle ID بلا إعداد إضافي
}
