import 'dart:async';
import '../error/failure_text.dart';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// التحقّق من نزاهة التطبيق عبر Play Integrity.
///
/// التسلسل كله مربوط بالخادم:
///   1. الخادم يُصدر nonce (صالح دقيقتين، يُستهلك مرّة واحدة).
///   2. Google يُنتج رمز نزاهة موقَّعًا مرتبطًا بذلك الـnonce.
///   3. الخادم وحده يفكّ الرمز عند Google ويخزّن الحكم.
///
/// العميل لا يقرأ الحكم ولا يستطيع تزويره: ما يعود إليه هو نتيجة الخادم،
/// وجدولا النزاهة محجوبان عنه تمامًا (RLS بلا سياسات).
///
/// لا يُمنع أي مستخدم من العميل بناءً على هذه النتيجة — المنع يقرّره الخادم
/// عند العمليات الحسّاسة عبر `integrity_is_trusted()`. هذا مقصود: أي فحص
/// في العميل يُلتَفّ عليه بتعديل التطبيق، وهو بالضبط ما نحاول كشفه.
class IntegrityService {
  IntegrityService._();
  static final IntegrityService instance = IntegrityService._();

  static const MethodChannel _channel = MethodChannel('mashareena/integrity');

  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);
  bool _running = false;

  SupabaseClient get _db => Supabase.instance.client;

  /// متاح على أندرويد فقط. على iOS البديل هو DeviceCheck/App Attest،
  /// ولم يُفعَّل بعد لأنّ مشروع iOS نفسه جديد.
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// يُشغَّل بعد تسجيل الدخول وعند العودة للمقدّمة، بحدّ أقصى مرّة كل 6 ساعات:
  /// كل نداء يستهلك حصّة Play Integrity، وحكم الجهاز لا يتغيّر بين لحظة وأخرى.
  Future<void> attestIfDue({Duration minGap = const Duration(hours: 6)}) async {
    if (!isSupported || _running) return;
    if (_db.auth.currentUser == null) return;
    if (DateTime.now().difference(_lastRun) < minGap) return;
    _running = true;
    try {
      await attestNow();
    } finally {
      _running = false;
    }
  }

  /// تنفيذ دورة تحقّق كاملة. يعيد نتيجة الخادم، أو null إن تعذّر.
  Future<Map<String, dynamic>?> attestNow() async {
    if (!isSupported) return null;
    try {
      final nonce = (await _db.rpc('integrity_new_nonce'))?.toString();
      if (nonce == null || nonce.isEmpty) return null;

      final token = await _channel.invokeMethod<String>(
        'requestToken',
        <String, dynamic>{'nonce': nonce},
      );
      if (token == null || token.isEmpty) return null;

      final res = await _db.functions.invoke(
        'play-integrity',
        body: <String, dynamic>{'token': token, 'nonce': nonce},
      );
      _lastRun = DateTime.now();
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } on PlatformException catch (e) {
      // متوقّع خارج Google Play: نسخة جانبية، محاكٍ، أو خدمات Play غائبة.
      // الخادم يسجّل غياب التصديق ويقرّر بنفسه، فلا نزعج المستخدم بشيء.
      debugPrint(FailureText.of(e));
      _lastRun = DateTime.now();
      return null;
    } catch (e) {
      debugPrint(FailureText.of(e));
      return null;
    }
  }
}
