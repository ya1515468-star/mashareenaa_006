import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// البند 16: إبقاء التطبيق عاملًا في الخلفية.
///
/// أندرويد يُجمِّد عملية التطبيق بعد خروجه من المقدّمة بثوانٍ، فينقطع
/// مقبس Realtime ويتوقّف صوت المشغّل العائم. الطريقة الوحيدة المدعومة
/// رسميًا لإبقاء العملية حيّة هي **خدمة أمامية** — ولذلك يظهر إشعار
/// دائم في شريط الهاتف طوال عملها؛ هذا شرط النظام لا خيار التطبيق.
///
/// التصميم هنا مقصود أن يكون الأقل خطرًا على إقلاع التطبيق:
///   • لا شيء يعمل عند بدء التطبيق إطلاقًا. الخدمة تبدأ فقط عند أول
///     خروج فعلي إلى الخلفية (AppLifecycleState.paused).
///   • كل استدعاء ملفوف بـtry/catch، فأي فشل في الحزمة أو في إذن
///     الإشعارات لا يُسقط التطبيق ولا يمنع فتحه — يُتجاهل بصمت ويبقى
///     السلوك كما كان قبل هذه الإضافة.
///   • تتوقّف الخدمة عند العودة إلى المقدّمة، فلا يبقى الإشعار ظاهرًا
///     بينما المستخدم داخل التطبيق.
class BackgroundKeepAlive with WidgetsBindingObserver {
  BackgroundKeepAlive._();
  static final instance = BackgroundKeepAlive._();

  bool _installed = false;
  bool _initialized = false;
  bool _running = false;

  /// تُستدعى مرة واحدة من main. لا تبدأ أي خدمة ولا تطلب أي إذن.
  void install() {
    if (_installed) return;
    _installed = true;
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'mashareena_keepalive',
        channelName: 'استمرار العمل في الخلفية',
        channelDescription:
            'يظهر هذا الإشعار أثناء عمل التطبيق في الخلفية لإبقاء الرسائل والصوت متصلين.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // لا عمل دوري: الهدف إبقاء العملية حيّة فقط، لا تنفيذ مَهمّة
        // متكرّرة تستهلك البطارية.
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_start());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_stop());
    }
  }

  Future<void> _start() async {
    if (_running) return;
    try {
      await _ensureInit();
      // أندرويد 13+ يشترط إذن الإشعارات لعرض إشعار الخدمة. إن رفضه
      // المستخدم لا نُلحّ عليه ولا نُسقط شيئًا — تبقى الخدمة متوقّفة.
      final perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
        final after = await FlutterForegroundTask.checkNotificationPermission();
        if (after != NotificationPermission.granted) return;
      }
      await FlutterForegroundTask.startService(
        serviceId: 2601,
        notificationTitle: 'مشاريعنا يعمل في الخلفية',
        notificationText: 'اضغط للعودة إلى التطبيق',
        callback: mashareenaKeepAliveCallback,
      );
      _running = true;
    } catch (_) {
      // الخدمة الأمامية إضافة لا يعتمد عليها أي مسار آخر؛ فشلها يعني
      // رجوع السلوك إلى ما كان عليه فقط.
      _running = false;
    }
  }

  Future<void> _stop() async {
    if (!_running) return;
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {
      // لا شيء يُفعل: إن تعذّر الإيقاف يُنهيه النظام مع العملية.
    } finally {
      _running = false;
    }
  }
}

/// نقطة دخول عزلة الخدمة. يجب أن تكون دالة عليا ومعلّمة بـvm:entry-point
/// وإلّا حذفها AOT في بناء الإصدار.
@pragma('vm:entry-point')
void mashareenaKeepAliveCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

/// مُعالِج بلا عمل: وجود الخدمة وحده هو ما يُبقي العملية حيّة، فلا
/// حاجة لأي تنفيذ دوري.
class _KeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
