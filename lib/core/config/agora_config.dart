class AgoraConfig {
  const AgoraConfig._();

  /// Agora Application ID
  static const String appId = '185603fcabd6488180fd18ee95475a65';

  /// Enable Agora Token Authentication
  ///
  /// يجب أن تبقى true في الإنتاج.
  /// يتم إنشاء Token من Backend وليس داخل Flutter.
  static const bool tokenEnabled = true;

  /// RTC Default Settings

  /// تفعيل الصوت افتراضيًا
  static const bool enableAudio = true;

  /// تفعيل الفيديو افتراضيًا
  static const bool enableVideo = true;

  /// أقصى عدد محاولات إعادة الاتصال
  static const int maxReconnectAttempts = 5;

  /// مهلة الاتصال قبل اعتباره فاشلاً
  static const int callTimeoutSeconds = 60;

  /// جودة الفيديو الافتراضية
  ///
  /// سيتم ضبطها لاحقًا حسب الشبكة والجهاز.
  static const String defaultVideoProfile = '720p';
}
