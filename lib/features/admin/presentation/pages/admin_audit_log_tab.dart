import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../rbac/domain/entities/audit_log_entity.dart';
import '../../../rbac/domain/usecases/manage_roles_usecases.dart';

final auditLogsProvider =
    StreamProvider.autoDispose<List<AuditLogEntity>>((ref) {
  return sl<WatchAuditLogsUseCase>().call(limit: 150);
});

const _typeLabelsAr = {
  'role_assignment': 'إسناد دور',
  'role_permissions_updated': 'تحديث صلاحيات دور',
  'account_status_change': 'تغيير حالة حساب',
  'broadcast_message': 'بث رسالة عامة',
  'points_transfer': 'تحويل نقاط',
};

class AdminAuditLogTab extends ConsumerWidget {
  const AdminAuditLogTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);
    final p = context.palette;

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('تعذّر تحميل سجل التدقيق: $e')),
      data: (logs) {
        if (logs.isEmpty) {
          return Center(
              child: Text('لا توجد إجراءات مسجَّلة بعد',
                  style: TextStyle(color: p.textSecondary)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final log = logs[index];
            return ListTile(
              leading: Icon(_iconFor(log.type), color: p.accent),
              title: Text(_typeLabelsAr[log.type] ?? log.type,
                  style: TextStyle(color: p.textPrimary)),
              subtitle: Text(
                'بواسطة: ${log.performedBy}${log.targetUid != null ? ' · على: ${log.targetUid}' : ''}',
                style: TextStyle(color: p.textSecondary, fontSize: 12),
              ),
              trailing: Text(_formatDate(log.createdAt),
                  style: TextStyle(color: p.textMuted, fontSize: 11)),
            );
          },
        );
      },
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'role_assignment':
        return Icons.badge_outlined;
      case 'role_permissions_updated':
        return Icons.tune;
      case 'account_status_change':
        return Icons.person_off_outlined;
      case 'broadcast_message':
        return Icons.campaign_outlined;
      case 'points_transfer':
        return Icons.swap_horiz;
      default:
        return Icons.history;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
