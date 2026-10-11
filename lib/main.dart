import 'core/navigation/app_navigator.dart';
import 'features/ai_assistant/presentation/ai_assistant_fab.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'core/services/realtime_resilience.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/injection_container.dart';
import 'core/routing/app_router.dart';
import 'core/services/presence_lifecycle_observer.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/config/supabase_config.dart';
import 'core/monitoring/error_monitor.dart';
import 'core/widgets/upload_progress_overlay.dart';
import 'core/widgets/global_mini_player.dart';
import 'core/widgets/sewing_machine_splash.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'core/services/background_keepalive.dart';
import 'core/services/server_realtime_sync.dart';
import 'features/chat/presentation/widgets/trix_game.dart' show TrixFloatingHost;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
    // المهلة الافتراضية 10 ثوانٍ قصيرة على شبكات الجوال البطيئة: كانت تنتج
    // RealtimeSubscribeException(timedOut) متكررة فتُعلَّق القنوات.
    realtimeClientOptions: const RealtimeClientOptions(
      timeout: Duration(seconds: 25),
    ),
  );

  // Dependency Injection
  await initDependencies();

  // Global error monitoring: routes framework errors and uncaught async
  // errors to the server so the platform owner can see real failures instead
  // of relying on users describing them.
  ErrorMonitor.install();

  // إعادة وصل Realtime بتوكن صالح عند عودة التطبيق من الخلفية.
  RealtimeResilience.instance.install();

  // البند 16: مراقب دورة الحياة الذي يُشغّل الخدمة الأمامية عند أول خروج
  // فعلي إلى الخلفية. لا يبدأ أي خدمة ولا يطلب أي إذن الآن — تركيب المراقب
  // وحده، فإقلاع التطبيق لا يتغيّر. وملفوف بـtry/catch لأن إقلاع التطبيق
  // أهم من هذه الإضافة.
  try {
    FlutterForegroundTask.initCommunicationPort();
    BackgroundKeepAlive.instance.install();
  } catch (_) {
    // بلا خدمة أمامية يبقى السلوك كما كان قبل الإضافة.
  }

  runApp(
    const ProviderScope(
      child: MashareenaApp(),
    ),
  );
}

class MashareenaApp extends ConsumerWidget {
  const MashareenaApp({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(globalServerRealtimeSyncProvider);
    final palette = ref.watch(themeControllerProvider);
    final theme = AppTheme.fromPalette(palette);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'مشاريعنا | Mashareena',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      builder: (
        context,
        child,
      ) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: UploadProgressOverlay(
            // Stack فوق التطبيق كله (لا داخل أي شاشة بعينها) حتى يبقى
            // المشغّل المصغّر العائم حيًّا عبر كل تنقّل بين الشاشات.
            // البند 12: targetSdk 35 يفرض الرسم خلف أزرار النظام (رجوع/
            // الرئيسية/القائمة). كانت الحشوة السفلية تُطبَّق على محتوى
            // التطبيق وحده، بينما المشغّل العائم وزر المساعد شقيقان له في
            // الـStack خارج تلك الحشوة — فيُرسمان تحت أزرار الهاتف ويتعذّر
            // الضغط عليهما. الحشوة الآن تلفّ الـStack كله فتنطبق على
            // الثلاثة معًا.
            child: Builder(builder: (ctx) {
              final mq = MediaQuery.of(ctx);
              final pad = (mq.viewPadding.bottom - mq.viewInsets.bottom)
                  .clamp(0.0, 200.0)
                  .toDouble();
              return Padding(
                padding: EdgeInsets.only(bottom: pad),
                child: MediaQuery.removePadding(
                  context: ctx,
                  removeBottom: true,
                  child: Stack(children: [
                    child ?? const SizedBox.shrink(),
                    // البند 3 (السبب الحقيقي لغياب صورة يوتيوب): YoutubePlayer
                    // على الهاتف يرسم الـWebView داخل OverlayPortal، وهذا
                    // الموضع فوق الـNavigator بلا أي Overlay سلف — فكان يرمي
                    // "No Overlay widget found" (_OverlayPortalState
                    // ._getLocation)، وهو الخطأ المسجّل من الجهاز عشرات
                    // المرات. المتحكّم يعمل فيُسمع الصوت، لكن الـWebView
                    // المرئي لا يُركَّب أبدًا. Overlay خاص هنا يمنحهما سلفًا.
                    // الإدخالات غير معتمة، فالمساحات الفارغة لا تحجب اللمس
                    // عن التطبيق تحتها.
                    Overlay(initialEntries: [
                      OverlayEntry(builder: (_) => const GlobalMiniPlayer()),
                      OverlayEntry(builder: (_) => const AiAssistantFab()),
                      // نافذة التركس العائمة (ملء الشاشة/نافذة/أيقونة) ومستمع
                      // دعوات الطاولات — فوق كل الشاشات فتبقى المباراة حيّة.
                      OverlayEntry(builder: (_) => const TrixFloatingHost()),
                    ]),
                  ]),
                ),
              );
            }),
          ),
        );
      },
      home: const StartupSplashGate(
        child: PresenceLifecycleObserver(child: AppRouter()),
      ),
    );
  }
}
