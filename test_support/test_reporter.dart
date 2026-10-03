import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// يشحن نتائج الاختبارات إلى الخادم (`test_results`).
///
/// لماذا: نتيجة الاختبار في الطرفية تضيع بمجرد إغلاق النافذة، ونقلها
/// يدويًا مُرهِق وناقص. بإرسالها للخادم تصير قابلة للقراءة مباشرة —
/// من يصلح العطل يرى الفشل بتفاصيله كاملة بلا وسيط.
///
/// كل تشغيل يحمل `runId` واحدًا، فيمكن مقارنة تشغيلين ومعرفة ما
/// انكسر حديثًا مقابل ما كان مكسورًا أصلًا.
class TestReporter {
  TestReporter._();

  static final String runId = const Uuid().v4();
  static bool _enabled = true;
  static final List<Map<String, dynamic>> _local = [];

  /// أوقف الشحن حين لا يكون Supabase مهيّأً (اختبارات وحدة نقية).
  static void disableRemote() => _enabled = false;

  static String get _platform {
    if (kIsWeb) return 'web';
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  static Future<void> record({
    required String suite,
    required String testName,
    required bool passed,
    int? durationMs,
    String? expected,
    String? actual,
    String? failure,
    String? stack,
  }) async {
    final row = {
      'suite': suite,
      'test': testName,
      'status': passed ? 'passed' : 'failed',
      'expected': expected,
      'actual': actual,
      'failure': failure,
    };
    _local.add(row);

    // الطباعة المحلية تبقى حتى لو تعذّر الشحن — لا نفقد النتيجة أبدًا
    debugPrint('${passed ? "✓" : "✗"} $suite › $testName'
        '${failure == null ? "" : "\n    $failure"}');

    if (!_enabled) return;
    try {
      await Supabase.instance.client.rpc('log_test_result', params: {
        'p_run_id': runId,
        'p_suite': suite,
        'p_test_name': testName,
        'p_status': passed ? 'passed' : 'failed',
        'p_duration_ms': durationMs,
        'p_expected': expected,
        'p_actual': actual,
        'p_failure': failure,
        'p_stack': stack,
        'p_platform': _platform,
        'p_app_version': '1.0.0',
      });
    } catch (e) {
      // فشل الشحن لا يُفشل الاختبار — النتيجة مطبوعة محليًا على أي حال
      debugPrint('  (تعذّر شحن النتيجة: $e)');
    }
  }

  /// ملخّص يُطبع في نهاية التشغيل
  static String summary() {
    final failed = _local.where((r) => r['status'] == 'failed').toList();
    final b = StringBuffer()
      ..writeln('\n═══ ملخّص التشغيل ═══')
      ..writeln('المعرّف: $runId')
      ..writeln('نجح: ${_local.length - failed.length} / ${_local.length}');
    if (failed.isEmpty) {
      b.writeln('لا فشل ✓');
    } else {
      b.writeln('\nالفشل:');
      for (final f in failed) {
        b.writeln('  ✗ ${f['suite']} › ${f['test']}');
        if (f['failure'] != null) b.writeln('      ${f['failure']}');
      }
    }
    return b.toString();
  }
}
