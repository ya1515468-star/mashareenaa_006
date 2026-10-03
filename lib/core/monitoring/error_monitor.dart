import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ships client-side failures to the server so the platform owner can see what
/// is actually breaking for real users, instead of the problem being invisible
/// until someone reports it verbally.
///
/// Design notes:
///  * Reporting is strictly best-effort. A failure to report must NEVER
///    surface to the user or interrupt anything — otherwise the monitoring
///    becomes its own source of bugs.
///  * A local de-duplication window stops a widget that throws on every frame
///    from spamming the network before the server-side throttle even sees it.
///  * Nothing is reported while signed out (the RPC requires auth anyway).
class ErrorMonitor {
  ErrorMonitor._();

  static const _dedupWindow = Duration(seconds: 30);
  static final Map<String, DateTime> _recent = {};
  static String? _currentScreen;

  /// Lets reports say WHERE the problem happened without every call site
  /// having to pass it.
  static void setScreen(String? screen) => _currentScreen = screen;

  static bool _shouldSkip(String key) {
    final now = DateTime.now();
    _recent.removeWhere((_, t) => now.difference(t) > _dedupWindow);
    if (_recent.containsKey(key)) return true;
    _recent[key] = now;
    return false;
  }

  /// Reports a caught problem. `expectation` is for silent logic failures —
  /// the case where nothing throws but the outcome is still wrong (an empty
  /// list where items were expected, a permission quietly denied). Those are
  /// invisible to any automatic handler and must be reported deliberately.
  static Future<void> report(
    Object error, {
    StackTrace? stack,
    String? screen,
    String? source,
    String severity = 'error',
  }) async {
    try {
      if (Supabase.instance.client.auth.currentUser == null) return;
      var message = error.toString();
      final scr = screen ?? _currentScreen;

      // A single layout failure produces dozens of follow-on
      // "RenderBox was not laid out" lines — one per widget in the subtree.
      // They are all the SAME incident, and logging each separately buries
      // the real cause. They are collapsed into one entry so the actual
      // trigger stays visible at the top of the list.
      final isLayoutCascade = message.contains('RenderBox was not laid out') ||
          message.contains('NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE');
      if (isLayoutCascade) {
        message = 'انهيار تخطيط متسلسل (نتيجة خطأ تخطيط سابق)';
      }

      if (_shouldSkip('$scr|$source|$message')) return;

      await Supabase.instance.client.rpc('log_client_error', params: {
        'p_message': message,
        'p_severity': severity,
        'p_screen': scr,
        'p_source': source,
        'p_details': stack?.toString(),
        'p_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'p_app_version': _appVersion,
      });
    } catch (_) {
      // Swallowed on purpose — see the class doc.
    }
  }

  /// Reports a silent failure: no exception was thrown, but the result is not
  /// what the screen needs. This is the only way "the button does nothing" or
  /// "the tab is empty" can ever become visible to the owner.
  static Future<void> reportExpectation({
    required String what,
    required String source,
    String? screen,
    String severity = 'warning',
  }) =>
      report(what, screen: screen, source: source, severity: severity);

  static String _appVersion = '1.0.0';
  static set appVersion(String v) => _appVersion = v;

  /// Installs the global handlers. Call once during startup.
  static void install() {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousOnError?.call(details);
      // ضجيج معروف من حزمة youtube_player_iframe نفسها: تستدعي context
      // داخل ردّ نداء إطار بعد إزالة الودجت من الشجرة. التخلص منه صحيح
      // بالفعل في كودنا (dispose يُغلق المتحكّم)، والخطأ داخلي في الحزمة
      // ولا أثر له على المستخدم — استبعاده يمنع إغراق تقرير الأخطاء
      // الحقيقية بتكرار لا يمكن إصلاحه من جهتنا.
      final text = details.exceptionAsString();
      final stackText = details.stack?.toString() ?? '';
      final isKnownPackageNoise =
          stackText.contains('youtube_player_iframe') &&
              text.contains('unmounted');
      if (isKnownPackageNoise) return;
      unawaited(report(
        text,
        stack: details.stack,
        source: 'flutter_error',
        severity: 'error',
      ));
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(report(error, stack: stack, source: 'uncaught_async', severity: 'fatal'));
      return true;
    };
  }
}

/// ---------------------------------------------------------------------------
/// Feature flags — the owner's instant "turn this off" lever.
/// ---------------------------------------------------------------------------
final featureFlagsProvider = FutureProvider<Map<String, bool>>((ref) async {
  try {
    final rows = await Supabase.instance.client
        .from('feature_flags')
        .select('flag_key,is_enabled');
    final map = <String, bool>{};
    for (final row in (rows as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      map[m['flag_key'].toString()] = m['is_enabled'] == true;
    }
    return map;
  } catch (_) {
    // If flags cannot be read, features stay ENABLED. Failing closed here
    // would disable the whole app on a transient network error.
    return const <String, bool>{};
  }
});

/// A feature is on unless the owner explicitly turned it off.
bool isFeatureEnabled(WidgetRef ref, String flagKey) {
  final flags = ref.watch(featureFlagsProvider).valueOrNull;
  if (flags == null) return true;
  return flags[flagKey] ?? true;
}
