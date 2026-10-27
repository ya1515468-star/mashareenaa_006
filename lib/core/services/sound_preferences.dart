import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// تفضيلات أصوات العضو، خادمية.
///
/// لماذا هذا موجود: مفتاحا «صوت الرسائل» و«صوت الإشعارات» في البروفايل
/// كانا يكتبان في مجموعة `accounts` التي **لا يقرأها أيّ شيء** —
/// لا مشغّل الأصوات ولا غيره. فيُحفَظ الإطفاء بنجاح وتبقى الأصوات
/// تُشتغل، وهو بالضبط «إيقاف أصوات الإشعار والرسائل لا يعمل».
///
/// وكان على الخادم أصلًا جدول `chat_notification_preferences` بمفاتيح
/// لكل حدث على حدة ودالّتا قراءة وتحديث — فالإصلاح ليس تخزينًا جديدًا
/// بل وصل المفاتيح بما هو موجود، ثم فرضه في نقطة واحدة يمرّ بها كل
/// صوت (`ServerSounds.play`) فلا يستطيع أي نداء أن ينساه.
class SoundPreferences {
  SoundPreferences._();
  static final SoundPreferences instance = SoundPreferences._();

  Map<String, dynamic>? _cache;
  Future<Map<String, dynamic>>? _inFlight;

  /// مفتاح النغمة → المفتاح الخادمي الذي يحكمه.
  ///
  /// ما ليس في الخريطة (نغمات الهدايا والتحويل وأصوات الواجهة) لا
  /// يحكمه مفتاح، فيبقى عاملًا: إطفاء «صوت الرسائل» لا يعني إسكات
  /// التطبيق كلّه.
  static const Map<String, String> _gate = {
    'message_send': 'private_message_sound',
    'message_receive': 'private_message_sound',
    'public_message': 'public_message_sound',
    'mention': 'mention_sound',
    'reply': 'reply_sound',
    'quote': 'reply_sound',
    'notification': 'notifications_sound',
    'friend_request': 'notifications_sound',
    'warning': 'warning_sound',
    'call': 'calls_sound',
  };

  Future<Map<String, dynamic>> _fetch() async {
    try {
      final raw = await Supabase.instance.client
          .rpc('get_my_chat_notification_preferences');
      final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      return _cache = m;
    } catch (_) {
      // تعذّر الجلب: تُعتبر كل الأصوات مسموحة. كتم التطبيق بسبب انقطاع
      // شبكة أسوأ من صوت غير مرغوب.
      return _cache = const <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> load({bool force = false}) {
    if (!force && _cache != null) return Future.value(_cache);
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  /// يُنادى بعد أي تغيير حتى يسري فورًا بلا إعادة تشغيل.
  void invalidate() {
    _cache = null;
    unawaited(load(force: true));
  }

  /// القرار المتزامن المستعمل داخل مشغّل الأصوات.
  ///
  /// بلا تفضيلات محمَّلة بعد → مسموح، ويُطلَب تحميلها لما بعدها: أول
  /// صوت بعد الإقلاع لا يستحق تعطيل الصوت كلّه بانتظار نداء شبكة.
  bool allows(String soundKey) {
    final prefs = _cache;
    if (prefs == null) {
      unawaited(load());
      return true;
    }
    if (prefs['master_chat_sound'] == false) return false;
    final gate = _gate[soundKey];
    if (gate == null) return true;
    return prefs[gate] != false;
  }

  /// يكتب مفتاحًا واحدًا على الخادم ثم يُحدِّث النسخة المحليّة.
  Future<void> setFlag(String serverKey, bool value) async {
    await Supabase.instance.client.rpc('update_chat_notification_preferences',
        params: {'p_values': {serverKey: value}});
    final next = Map<String, dynamic>.from(_cache ?? const {});
    next[serverKey] = value;
    _cache = next;
  }

  Future<bool> flag(String serverKey, {bool defaultValue = true}) async {
    final prefs = await load();
    final v = prefs[serverKey];
    return v is bool ? v : defaultValue;
  }
}
