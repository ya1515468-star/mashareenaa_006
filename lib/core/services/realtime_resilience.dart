import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// استعادة اتصال Realtime عند عودة التطبيق من الخلفية.
///
/// ما كان يحدث: يُعلَّق التطبيق في الخلفية فيُغلق النظام المقبس، ويمضي وقت
/// تنتهي فيه صلاحية التوكن. عند العودة يحاول Realtime إعادة الانضمام للقنوات
/// بتوكن منتهٍ فيرفضه الخادم (InvalidJWTToken / channelError)، وتبقى الشاشات
/// الحيّة (الشات، الإشعارات، المحفظة) معلّقة بلا تحديث حتى يُعاد فتحها.
///
/// هنا: عند العودة نجدّد الجلسة أولًا إن كانت منتهية أو على وشك الانتهاء،
/// ثم نمرّر التوكن الجديد لـRealtime ونعيد وصل المقبس إن كان مقطوعًا. القنوات
/// القائمة تعيد الانضمام تلقائيًا بعدها بالتوكن الصالح.
class RealtimeResilience with WidgetsBindingObserver {
  RealtimeResilience._();
  static final instance = RealtimeResilience._();
  bool _installed = false;
  bool _busy = false;

  void install() {
    if (_installed) return;
    _installed = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_recover());
  }

  Future<void> _recover() async {
    if (_busy) return;
    _busy = true;
    try {
      final client = Supabase.instance.client;
      var session = client.auth.currentSession;
      if (session == null) return;

      final expiresAt = session.expiresAt;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (expiresAt == null || expiresAt - now < 120) {
        try {
          session = (await client.auth.refreshSession()).session ?? session;
        } catch (_) {
          // إن فشل التجديد (شبكة غير متاحة) يعيد SDK المحاولة لاحقًا تلقائيًا.
        }
      }

      // المقبس يعيد الاتصال وحده (مؤقّت إعادة الاتصال داخل المكتبة)؛ ما لا يفعله
      // وحده هو التقاط التوكن الجديد، وsetAuth تمرّره لكل القنوات فتعيد الانضمام
      // بتوكن صالح. connect() داخلية في المكتبة فلا تُستدعى من هنا.
      final token = session?.accessToken;
      if (token != null) {
        await client.realtime.setAuth(token);
      }
    } catch (_) {
      // الاستعادة تحسين، لا يجوز أن تُسقط التطبيق.
    } finally {
      _busy = false;
    }
  }
}
