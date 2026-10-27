/// صلاحية رموز البريد (OTP) في مكان واحد.
///
/// القيمة الفعلية يفرضها الخادم، لا التطبيق:
/// Supabase → Authentication → Providers → Email → **Email OTP Expiration**
/// (الافتراضي 3600 ثانية = ساعة واحدة).
///
/// ما هنا يُستخدم لعرض العدّاد التنازلي للمستخدم فقط. إن غيّرت القيمة في
/// اللوحة فغيّرها هنا ليتطابق العرض مع الواقع. وحتى لو اختلفا، الخادم هو
/// الحَكَم: الرمز المنتهي يُرفض ويظهر للمستخدم «انتهت صلاحية الرمز».
class AuthOtp {
  const AuthOtp._();

  /// مدّة صلاحية رمز تأكيد التسجيل ورمز إعادة التعيين.
  static const Duration validity = Duration(hours: 1);

  /// أقل فاصل بين طلبي إرسال (Supabase يفرض 60 ثانية على /resend).
  static const Duration resendCooldown = Duration(seconds: 60);

  static String get validityLabel {
    final m = validity.inMinutes;
    if (m % 60 == 0) {
      final h = m ~/ 60;
      return h == 1 ? 'ساعة واحدة' : '$h ساعات';
    }
    return '$m دقيقة';
  }

  /// نص عدّاد تنازلي mm:ss.
  static String countdown(Duration left) {
    if (left.isNegative) return '00:00';
    final mm = left.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = left.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = left.inHours;
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}
