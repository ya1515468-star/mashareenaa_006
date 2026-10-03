import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يدير حالتين مستقلتين تمامًا عن Supabase Auth (الذي يحتفظ بجلسته
/// الخاصة تلقائيًا على الجوال):
///
/// 1) "تذكرني" — تخزين آخر بريد إلكتروني استُخدم للدخول فقط (بيانات
///    غير حساسة) في SharedPreferences، لتعبئته تلقائيًا في المرة
///    القادمة. لا يُخزَّن أي كلمة مرور هنا مطلقًا.
///
/// 2) "قفل PIN السريع" — عندما تكون هناك جلسة Supabase Auth مخزّنة
///    فعليًا على الجهاز، يمكن للمستخدم تفعيل قفل إضافي محلي برمز
///    PIN بدل إعادة كتابة البريد/كلمة المرور، عبر flutter_secure_storage
///    (مشفّر على مستوى نظام التشغيل: Keychain/Keystore). الـ PIN هنا
///    يفتح جلسة موجودة بالفعل فقط، ولا يُستخدم كقناة مصادقة شبكية
///    مستقلة.
class LocalSessionService {
  LocalSessionService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  static const _kRememberedEmailKey = 'remember_me_email';
  static const _kRememberMeEnabledKey = 'remember_me_enabled';
  static const _kQuickPinUidKey = 'quick_pin_uid';

  // ---------------------------- تذكرني ----------------------------

  Future<void> saveRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRememberedEmailKey, email);
    await prefs.setBool(_kRememberMeEnabledKey, true);
  }

  Future<void> clearRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRememberedEmailKey);
    await prefs.setBool(_kRememberMeEnabledKey, false);
  }

  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kRememberMeEnabledKey) ?? false;
    if (!enabled) return null;
    return prefs.getString(_kRememberedEmailKey);
  }

  Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kRememberMeEnabledKey) ?? false;
  }

  // -------------------------- قفل PIN السريع --------------------------
  //
  // التحقق الفعلي من الـ PIN يتم دائمًا عبر [VerifyPinUseCase] مقابل
  // طبقة بيانات Supabase (وليس بمقارنة محلية) — لذا لا حاجة لتخزين أي تجزئة أو
  // ملح على الجهاز؛ نخزّن فقط uid صاحب الجلسة التي فعّلت القفل، وهذا
  // يكفي لتحديد "هل أعرض شاشة القفل أم لا" في [PinLockGate].

  Future<void> enableQuickPinFor(String uid) async {
    await _secureStorage.write(key: _kQuickPinUidKey, value: uid);
  }

  Future<void> clearQuickPin() async {
    await _secureStorage.delete(key: _kQuickPinUidKey);
  }

  Future<bool> hasQuickPinFor(String uid) async {
    final storedUid = await _secureStorage.read(key: _kQuickPinUidKey);
    return storedUid == uid;
  }
}
