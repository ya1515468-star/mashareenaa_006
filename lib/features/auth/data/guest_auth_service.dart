import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/auth_redirect.dart';

/// نتيجة محاولة ربط بريد بحساب الزائر.
enum GuestUpgradeOutcome {
  /// أُرسل رمز التأكيد إلى البريد.
  codeSent,

  /// البريد يخصّ حسابًا آخر — على المستخدم أن يقرّر: يسجّل دخوله به
  /// (وتُفقد بيانات الزائر) أو يستعمل بريدًا غيره.
  emailBelongsToAnotherAccount,
}

class GuestAuthException implements Exception {
  final String message;
  const GuestAuthException(this.message);
  @override
  String toString() => message;
}

/// حساب الزائر: الدخول بلا تسجيل، ثم ترقيته لاحقًا ببريد مؤكَّد.
///
/// الفكرة الجوهرية: الزائر في Supabase مستخدم حقيقي له `auth.uid()`
/// ثابت. فعند ربط بريد به وتأكيده **يبقى المعرّف نفسه**، وتنتقل معه
/// رسائله ونقاطه وأصدقاؤه وكل ما جمعه بلا أي نقل بيانات. يصير حرفيًا
/// «مثل من سجّل من أول تثبيت».
///
/// ترتيب الترقية ليس اختياريًا: توثيق Supabase ينصّ على أن إضافة كلمة
/// مرور للزائر تتطلّب بريدًا **مؤكَّدًا أولًا**. فمحاولة ضبط البريد
/// وكلمة المرور معًا تُرفض بـ«Updating password of an anonymous user is
/// not possible». ولذلك الترقية ثلاث خطوات: بريد ← رمز ← كلمة مرور.
class GuestAuthService {
  final sb.SupabaseClient _client;

  GuestAuthService([sb.SupabaseClient? client])
      : _client = client ?? sb.Supabase.instance.client;

  sb.User? get _user => _client.auth.currentUser;

  /// هل الجلسة الحالية لزائر؟ يُقرأ من الجلسة مباشرة بلا رحلة للخادم.
  /// القرار الفعلي يبقى خادميًا؛ هذا للواجهة فقط.
  bool get isGuestSession => _user?.isAnonymous ?? false;

  /// ── 1) الدخول كزائر ──
  ///
  /// الاسم والجنس وتاريخ الميلاد تُمرَّر في `data` فتصل إلى
  /// `raw_user_meta_data`، ويلتقطها تريجر `handle_new_user` ويكتبها في
  /// `profiles` — فيُولد الزائر بملف شخصي مكتمل كأي عضو.
  Future<sb.User> signInAsGuest({
    required String displayName,
    String? gender,
    DateTime? birthDate,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw const GuestAuthException('اكتب اسمًا للعرض.');
    }
    try {
      final res = await _client.auth.signInAnonymously(
        data: <String, dynamic>{
          'display_name': name,
          if (gender == 'male' || gender == 'female') 'gender': gender,
          if (birthDate != null)
            'birth_date': _asDateOnly(birthDate),
        },
      );
      final user = res.user;
      if (user == null) {
        throw const GuestAuthException('تعذّر الدخول كزائر، حاول مرة أخرى.');
      }
      return user;
    } on sb.AuthException catch (e) {
      // المفتاح مُطفأ في لوحة Supabase (Authentication ← Sign In /
      // Providers ← Allow anonymous sign-ins).
      if (e.code == 'anonymous_provider_disabled') {
        throw const GuestAuthException('الدخول كزائر متوقف حاليًا.');
      }
      throw GuestAuthException(e.message);
    }
  }

  /// ── 2) ربط البريد: يُرسل رمزًا من ستّ خانات ──
  Future<GuestUpgradeOutcome> startUpgrade(String email) async {
    final value = email.trim();
    if (!_looksLikeEmail(value)) {
      throw const GuestAuthException('اكتب بريدًا إلكترونيًا صحيحًا.');
    }
    if (!isGuestSession) {
      throw const GuestAuthException('هذا الحساب مسجَّل بالفعل.');
    }
    try {
      await _client.auth.updateUser(
        sb.UserAttributes(email: value),
        emailRedirectTo: authRedirectUrl(),
      );
      return GuestUpgradeOutcome.codeSent;
    } on sb.AuthException catch (e) {
      final raw = '${e.code ?? ''} ${e.message}'.toLowerCase();
      // البريد يخصّ حسابًا قائمًا: Supabase يرفض الربط. القرار للمستخدم
      // لا لنا — إمّا يسجّل دخوله بذلك الحساب (وتُفقد بيانات الزائر)
      // أو يستعمل بريدًا آخر.
      if (raw.contains('already') ||
          raw.contains('exists') ||
          raw.contains('registered') ||
          e.code == 'email_exists' ||
          e.code == 'identity_already_exists') {
        return GuestUpgradeOutcome.emailBelongsToAnotherAccount;
      }
      throw GuestAuthException(e.message);
    }
  }

  /// يعيد إرسال الرمز. Supabase يفرض 60 ثانية بين طلبين.
  Future<void> resendUpgradeCode(String email) async {
    try {
      await _client.auth.resend(
        type: sb.OtpType.emailChange,
        email: email.trim(),
        emailRedirectTo: authRedirectUrl(),
      );
    } on sb.AuthException catch (e) {
      throw GuestAuthException(e.message);
    }
  }

  /// ── 3) تأكيد الرمز ──
  ///
  /// نوع الرمز `emailChange` لا `signup`: الحساب موجود أصلًا ونحن نربط
  /// به هويّة بريد، لا نُنشئ حسابًا جديدًا.
  Future<void> confirmUpgradeCode({
    required String email,
    required String code,
  }) async {
    final token = code.trim();
    if (token.length < 6) {
      throw const GuestAuthException('الرمز ستّ خانات.');
    }
    try {
      await _client.auth.verifyOTP(
        type: sb.OtpType.emailChange,
        email: email.trim(),
        token: token,
      );
    } on sb.AuthException catch (e) {
      throw GuestAuthException(e.message);
    }
  }

  /// ── 4) كلمة المرور — بعد التأكيد حصرًا ──
  ///
  /// بلا كلمة مرور لا يستطيع صاحب الحساب تسجيل الدخول من جهاز آخر،
  /// فهذه الخطوة تُكمل الترقية ولا تُعدّ اختيارية عمليًا.
  Future<void> setPasswordAfterUpgrade(String password) async {
    if (password.length < 6) {
      throw const GuestAuthException('كلمة المرور ستّة أحرف على الأقل.');
    }
    try {
      await _client.auth.updateUser(sb.UserAttributes(password: password));
    } on sb.AuthException catch (e) {
      final raw = e.message.toLowerCase();
      if (raw.contains('anonymous')) {
        throw const GuestAuthException(
            'أكّد بريدك أولًا ثم اضبط كلمة المرور.');
      }
      throw GuestAuthException(e.message);
    }
  }

  /// هل اكتملت الترقية فعلًا؟ يُعاد تحميل المستخدم من الخادم لا من
  /// الذاكرة المحلية، لأن الجلسة المحفوظة قد تسبق التأكيد.
  Future<bool> refreshAndCheckUpgraded() async {
    try {
      final res = await _client.auth.getUser();
      final user = res.user;
      if (user == null) return false;
      return !(user.isAnonymous) &&
          (user.email?.trim().isNotEmpty ?? false) &&
          user.emailConfirmedAt != null;
    } catch (_) {
      return false;
    }
  }

  static String _asDateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}
