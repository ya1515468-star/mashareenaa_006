import 'package:flutter/material.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/monitoring/error_monitor.dart';

final _errorsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, bool>((ref, includeResolved) async {
  final rows = await Supabase.instance.client.rpc('admin_list_client_errors',
      params: {'p_include_resolved': includeResolved, 'p_limit': 200});
  return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

/// Proactive self-inspection of the database. Unlike the error log (which
/// only records what already failed for a user), this actively hunts for
/// defects — broken column references, duplicate overloads, missing grants,
/// RLS gaps — before anyone runs into them.
final _diagnosticsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client.rpc('run_system_diagnostics');
  return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final _flagsRawProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client
      .from('feature_flags')
      .select('flag_key,is_enabled,name_ar')
      .order('flag_key');
  return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

/// Owner-only: what is actually failing for real users, plus the switches to
/// disable a broken feature instantly without shipping a new build.
class ErrorMonitorPage extends ConsumerStatefulWidget {
  const ErrorMonitorPage({super.key});
  @override
  ConsumerState<ErrorMonitorPage> createState() => _ErrorMonitorPageState();
}

class _ErrorMonitorPageState extends ConsumerState<ErrorMonitorPage> {
  bool _includeResolved = false;

  /// Maps a recorded failure to a concrete, human-readable next step.
  /// Deliberately a SUGGESTION shown to the owner — never something the system
  /// applies by itself. An automated fixer acting on a wrong guess would be
  /// writing to a production database unsupervised.
  String? _suggestFix(Map<String, dynamic> e) {
    final msg = (e['message'] ?? '').toString().toLowerCase();
    final src = (e['source'] ?? '').toString().toLowerCase();
    if (msg.contains('agora_server_not_configured')) {
      return 'أسرار Agora غير مضبوطة على الخادم. اضبط AGORA_APP_ID و AGORA_APP_CERTIFICATE.';
    }
    if (msg.contains('does not exist') && msg.contains('column')) {
      return 'الاستعلام يطلب عمودًا غير موجود. صحّح اسم العمود في الاستعلام.';
    }
    if (msg.contains('permission denied')) {
      return 'صلاحية ناقصة على جدول أو دالة. راجع منح الصلاحيات لهذا المورد.';
    }
    if (msg.contains('row-level security') || msg.contains('violates row-level')) {
      return 'سياسة RLS تمنع العملية. راجع سياسة الجدول المعني.';
    }
    if (src.contains('_empty')) {
      return 'لا يوجد خطأ تقني — المصدر أعاد صفر عنصر. تحقق من وجود البيانات وتفعيلها.';
    }
    if (msg.contains('infinite width') || msg.contains('unbounded') ||
        msg.contains('infinite size')) {
      return 'ودجت حصل على عرض/ارتفاع بلا حدود. غالبًا داخل Row/Column أو '
          'Positioned بجهة واحدة. الحل: تحديد عرض أو استخدام Expanded/Flexible.';
    }
    if (msg.contains('انهيار تخطيط متسلسل')) {
      return 'هذه نتيجة لخطأ تخطيط آخر — ابحث عن أول خطأ تخطيط في القائمة وأصلحه، '
          'وستختفي هذه تلقائيًا.';
    }
    if (msg.contains('Agora') || msg.contains('AGORA')) {
      return 'أسرار Agora غير مضبوطة على الخادم: AGORA_APP_ID و AGORA_APP_CERTIFICATE.';
    }
    if (msg.contains('الملف الشخصي غير موجود') || msg.contains('PROFILE_NOT_FOUND')) {
      return 'العضو مفعّل خدمة إخفاء الملف الشخصي — هذا سلوك صحيح لا خلل.';
    }
    if (msg.contains('FEATURE_REQUIRED')) {
      return 'الميزة تتطلب خدمة VIP غير مملوكة — سلوك صحيح، لا خلل.';
    }
    if (msg.contains('FORBIDDEN')) {
      return 'الخادم رفض العملية لنقص صلاحية — تحقق أن المستخدم يملك الصلاحية فعلًا.';
    }
    return null;
  }

  String _reportText(Map<String, dynamic> e) {
    final fix = (e['suggested_fix']?.toString().trim().isNotEmpty == true)
        ? e['suggested_fix'].toString()
        : (_suggestFix(e) ?? '—');
    return '''
[${e['severity']}] ${e['category'] ?? ''}
الرسالة: ${e['message'] ?? ''}
الشاشة: ${e['screen'] ?? '—'}
المصدر: ${e['source'] ?? '—'}
المنصة: ${e['platform'] ?? '—'}   الإصدار: ${e['app_version'] ?? '—'}
التكرار: ${e['occurrences'] ?? 1}   المتأثرون: ${e['affected_users'] ?? 1}
أول ظهور: ${e['first_seen_at'] ?? '—'}
آخر ظهور: ${e['last_seen_at'] ?? '—'}
الإصلاح المقترح: $fix
--- التفاصيل التقنية ---
${e['details'] ?? '—'}
'''
        .trim();
  }

  Future<void> _copyReport(Map<String, dynamic> e) async {
    await Clipboard.setData(ClipboardData(text: _reportText(e)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(
      content: Text('تم نسخ تقرير الخطأ ✓'),
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _copyAll(List<Map<String, dynamic>> errors) async {
    final buffer = StringBuffer()
      ..writeln('تقرير أخطاء MASHAREENA — ${DateTime.now().toIso8601String()}')
      ..writeln('عدد الأخطاء: ${errors.length}')
      ..writeln('=' * 40);
    for (final e in errors) {
      buffer
        ..writeln(_reportText(e))
        ..writeln('=' * 40);
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(
      content: Text('تم نسخ ${errors.length} خطأ ✓'),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _setResolved(String id, bool resolved) async {
    try {
      await Supabase.instance.client.rpc('admin_resolve_client_error',
          params: {'p_id': id, 'p_resolved': resolved});
      ref.invalidate(_errorsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBarSfx(SnackBar(content: Text('تعذر التحديث: $e')));
      }
    }
  }

  Future<void> _toggleFlag(String key, bool enabled) async {
    try {
      await Supabase.instance.client.rpc('admin_set_feature_flag',
          params: {'p_flag_key': key, 'p_enabled': enabled});
      ref.invalidate(_flagsRawProvider);
      ref.invalidate(featureFlagsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(
          content: Text(enabled ? 'تم تفعيل الميزة ✓' : 'تم تعطيل الميزة ✓'),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBarSfx(SnackBar(content: Text('تعذر التغيير: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorsAsync = ref.watch(_errorsProvider(_includeResolved));
    final flagsAsync = ref.watch(_flagsRawProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مراقبة الأخطاء'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              ref.invalidate(_errorsProvider);
              ref.invalidate(_flagsRawProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---------------- Feature switches ----------------
          const Text('مفاتيح إيقاف الميزات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const Text(
            'أوقف أي ميزة معطوبة فورًا دون إصدار نسخة جديدة.',
            style: TextStyle(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 6),
          flagsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('تعذر تحميل المفاتيح: $e',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            data: (flags) => Column(
              children: [
                for (final f in flags)
                  SwitchListTile(
                    value: f['is_enabled'] == true,
                    onChanged: (v) => _toggleFlag(f['flag_key'].toString(), v),
                    title: Text(
                      (f['name_ar'] ?? f['flag_key']).toString(),
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(f['flag_key'].toString(),
                        style: const TextStyle(fontSize: 10, color: Colors.white38)),
                    dense: true,
                  ),
              ],
            ),
          ),

          const Divider(height: 28),

          // ---------------- Proactive diagnostics ----------------
          Row(children: [
            const Expanded(
              child: Text('الفحص الذاتي للنظام',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            IconButton(
              tooltip: 'إعادة الفحص',
              onPressed: () => ref.invalidate(_diagnosticsProvider),
              icon: const Icon(Icons.play_circle_outline, size: 20),
            ),
          ]),
          const Text(
            'يفتّش النظام بنفسه عن أعطال لم يصادفها أحد بعد.',
            style: TextStyle(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 6),
          ref.watch(_diagnosticsProvider).when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(14),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(
                  e.toString().contains('FORBIDDEN')
                      ? 'الفحص الذاتي للمالك فقط.'
                      : 'تعذر تشغيل الفحص: $e',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(children: [
                        Icon(Icons.verified, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('النظام سليم — لا ملاحظات.',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    );
                  }
                  final fatal =
                      rows.where((r) => r['severity'] == 'fatal').length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'النتيجة: ${rows.length} ملاحظة'
                        '${fatal > 0 ? '  •  منها $fatal حرجة' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: fatal > 0 ? Colors.redAccent : Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final r in rows.take(40))
                        Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              r['severity'] == 'fatal'
                                  ? Icons.dangerous
                                  : Icons.warning_amber_rounded,
                              color: r['severity'] == 'fatal'
                                  ? Colors.redAccent
                                  : Colors.amber,
                              size: 20,
                            ),
                            title: Text(
                              '${r['category']} — ${r['object_name']}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('${r['detail']}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white54)),
                          ),
                        ),
                    ],
                  );
                },
              ),

          const Divider(height: 28),

          // ---------------- Errors ----------------
          Row(
            children: [
              const Expanded(
                child: Text('الأخطاء المسجّلة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
              TextButton.icon(
                onPressed: () {
                  final rows = ref.read(_errorsProvider(_includeResolved)).valueOrNull;
                  if (rows != null && rows.isNotEmpty) _copyAll(rows);
                },
                icon: const Icon(Icons.copy_all, size: 16),
                label: const Text('نسخ الكل', style: TextStyle(fontSize: 11)),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _includeResolved = !_includeResolved),
                icon: Icon(_includeResolved ? Icons.visibility_off : Icons.visibility, size: 16),
                label: Text(_includeResolved ? 'إخفاء المعالَجة' : 'إظهار المعالَجة',
                    style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          errorsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                e.toString().contains('FORBIDDEN')
                    ? 'هذه الشاشة للمالك فقط.'
                    : 'تعذر تحميل الأخطاء: $e',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
            data: (errors) {
              if (errors.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('لا توجد أخطاء مسجّلة 🎉',
                        style: TextStyle(color: Colors.white60)),
                  ),
                );
              }
              return Column(
                children: [
                  for (final e in errors) _errorCard(e),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _errorCard(Map<String, dynamic> e) {
    final severity = (e['severity'] ?? 'error').toString();
    final resolved = e['resolved'] == true;
    final color = switch (severity) {
      'fatal' => Colors.red,
      'error' => Colors.orangeAccent,
      'warning' => Colors.amber,
      _ => Colors.blueAccent,
    };
    final fix = (e['suggested_fix']?.toString().trim().isNotEmpty == true)
        ? e['suggested_fix'].toString()
        : _suggestFix(e);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color),
                  ),
                  child: Text(severity,
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('×${e['occurrences'] ?? 1}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                if (resolved)
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(e['message']?.toString() ?? '',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'الشاشة: ${e['screen'] ?? '—'}  •  المصدر: ${e['source'] ?? '—'}  •  '
              '${e['platform'] ?? '—'}  •  مستخدمون: ${e['affected_users'] ?? 1}',
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
            Text('آخر ظهور: ${e['last_seen_at'] ?? '—'}',
                style: const TextStyle(fontSize: 10, color: Colors.white38)),
            if (fix != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: .5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 15, color: Colors.lightBlueAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('الإصلاح المقترح: $fix',
                          style: const TextStyle(fontSize: 11, color: Colors.lightBlueAccent)),
                    ),
                  ],
                ),
              ),
            ],
            if ((e['details']?.toString().trim().isNotEmpty ?? false))
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('التفاصيل التقنية',
                      style: TextStyle(fontSize: 11, color: Colors.white54)),
                  children: [
                    SelectableText(
                      e['details'].toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                TextButton(
                  onPressed: () => _setResolved(e['id'].toString(), !resolved),
                  child: Text(resolved ? 'إعادة فتح' : 'تحديد كمُعالَج',
                      style: const TextStyle(fontSize: 11)),
                ),
                const Spacer(),
                // Copies the FULL report (message + screen + source + counts +
                // stack trace) as one block, so it can be pasted somewhere
                // useful instead of being retyped from a screenshot.
                TextButton.icon(
                  onPressed: () => _copyReport(e),
                  icon: const Icon(Icons.copy_all, size: 15),
                  label: const Text('نسخ الخطأ', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
