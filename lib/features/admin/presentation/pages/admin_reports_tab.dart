import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';

/// البلاغات للإدارة والمالك، بأسماء المبلِّغين والمبلَّغ عنهم.
///
/// كان التبويب يقرأ مجموعة reports مباشرة: الإداريون (غير المالك) بلا سياسة
/// قراءة فلا يرون شيئًا، والبطاقة تعرض معرّفات UUID فقط، والمعالَج يختفي.
/// admin_list_reports تحرسها صلاحية chat.moderate خادميًا وتُرجع الأسماء.
final _adminReportsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>(
        (ref, status) async {
  final raw = await Supabase.instance.client.rpc('admin_list_reports',
      params: {'p_status': status, 'p_limit': 200});
  return raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];
});

class AdminReportsTab extends ConsumerStatefulWidget {
  const AdminReportsTab({super.key});

  @override
  ConsumerState<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends ConsumerState<AdminReportsTab> {
  static const _filters = <String?, String>{
    'pending': 'قيد المراجعة',
    'resolved': 'معالَجة',
    'dismissed': 'متجاهَلة',
    null: 'الكل',
  };
  String? _status = 'pending';
  bool _busy = false;

  static String _typeLabel(String? t) => switch (t) {
        'post' => 'منشور',
        'comment' => 'تعليق',
        'user' => 'عضو',
        'chatMessage' => 'رسالة شات',
        _ => 'بلاغ',
      };

  static String _statusLabel(String? s) => switch (s) {
        'resolved' => 'معالَج',
        'dismissed' => 'متجاهَل',
        _ => 'قيد المراجعة',
      };

  static Color _statusColor(String? s) => switch (s) {
        'resolved' => const Color(0xFF16A34A),
        'dismissed' => AppColors.textSecondary,
        _ => const Color(0xFFF59E0B),
      };

  Future<void> _resolve(String id, String newStatus) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Supabase.instance.client.rpc('moderator_resolve_report',
          params: {'p_report_id': id, 'p_new_status': newStatus});
      ref.invalidate(_adminReportsProvider);
      messenger?.showSnackBar(SnackBar(
          content: Text(newStatus == 'resolved' ? 'عولج البلاغ' : 'تُجوهل البلاغ')));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('تعذّر التحديث: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishWarning(Map<String, dynamic> r) async {
    final title = TextEditingController(text: 'تحذير أمان');
    final details = TextEditingController(text: r['reason']?.toString() ?? '');
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('نشر تحذير أمان'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'العنوان')),
          TextField(
              controller: details,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'التفاصيل')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('نشر')),
        ],
      ),
    );
    try {
      if (ok == true) {
        await Supabase.instance.client
            .rpc('publish_platform_safety_warning', params: {
          'p_target_user_id': r['target_id'],
          'p_title': title.text.trim(),
          'p_details': details.text.trim(),
          'p_evidence_url': r['evidence_url'],
          'p_source_report_id': r['id'],
        });
        messenger?.showSnackBar(const SnackBar(content: Text('نُشر التحذير')));
      }
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('تعذّر النشر: $e')));
    } finally {
      title.dispose();
      details.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_adminReportsProvider(_status));

    return Column(children: [
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            for (final e in _filters.entries)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: _status == e.key,
                  onSelected: (_) => setState(() => _status = e.key),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                e.toString().contains('FORBIDDEN')
                    ? 'عرض البلاغات يتطلب صلاحية الإشراف.'
                    : 'تعذّر تحميل البلاغات: $e',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (reports) {
            if (reports.isEmpty) {
              return const Center(
                child: Text('لا توجد بلاغات',
                    style: TextStyle(color: AppColors.textSecondary)),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_adminReportsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: reports.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _card(reports[i]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _card(Map<String, dynamic> r) {
    final status = r['status']?.toString();
    final pending = status == null || status == 'pending';
    final reporter = r['reporter_name']?.toString() ?? 'عضو';
    final targetName = r['target_name']?.toString();
    final created = DateTime.tryParse(r['created_at']?.toString() ?? '');
    final evidence = r['evidence_url']?.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Chip(
                label: Text(_typeLabel(r['target_type']?.toString())),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_statusLabel(status),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _statusColor(status))),
              ),
              const Spacer(),
              if (created != null)
                Text(
                  '${created.toLocal().year}/${created.toLocal().month}/${created.toLocal().day}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
            ]),
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              const TextSpan(
                  text: 'المُبلِّغ: ',
                  style: TextStyle(color: AppColors.textSecondary)),
              TextSpan(
                  text: reporter,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ])),
            const SizedBox(height: 2),
            Text.rich(TextSpan(children: [
              const TextSpan(
                  text: 'المُبلَّغ عنه: ',
                  style: TextStyle(color: AppColors.textSecondary)),
              TextSpan(
                  text: targetName ?? r['target_id']?.toString() ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ])),
            const SizedBox(height: 8),
            Text(r['reason']?.toString() ?? ''),
            if (evidence != null && evidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(evidence,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ],
            if (!pending && r['resolved_by_name'] != null) ...[
              const SizedBox(height: 6),
              Text('بواسطة: ${r['resolved_by_name']}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
            if (pending) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _resolve(r['id'].toString(), 'dismissed'),
                  child: const Text('تجاهل'),
                ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _resolve(r['id'].toString(), 'resolved'),
                  child: const Text('معالجة'),
                ),
                if (r['target_type'] == 'user')
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _publishWarning(r),
                    icon: const Icon(Icons.publish_rounded),
                    label: const Text('نشر التحذير'),
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
