import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/app_notification_entity.dart';
import '../providers/notification_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  /// يفتح الإشعارات كورقة عائمة (نصف الشاشة، قابلة للسحب) بدل شاشة
  /// كاملة تغطي الغرفة. الصفحة نفسها تبقى صالحة كشاشة مستقلة أيضًا.
  static Future<void> showSheet(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: .55,
          minChildSize: .35,
          maxChildSize: .92,
          expand: false,
          builder: (_, __) => const ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            child: NotificationsPage(),
          ),
        ),
      );

  IconData _iconFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.message:
        return Icons.chat_bubble_outline;
      case AppNotificationType.like:
        return Icons.favorite_outline;
      case AppNotificationType.comment:
        return Icons.mode_comment_outlined;
      case AppNotificationType.follow:
        return Icons.person_add_alt_outlined;
      case AppNotificationType.friendRequest:
        return Icons.person_add_outlined;
      case AppNotificationType.friendAccepted:
        return Icons.people_outline;
      case AppNotificationType.system:
        return Icons.campaign_outlined;
      case AppNotificationType.mention:
        return Icons.alternate_email;
      case AppNotificationType.chatReply:
        return Icons.reply;
      case AppNotificationType.friendRejected:
        return Icons.person_off_outlined;
      case AppNotificationType.callIncoming:
        return Icons.call_received;
      case AppNotificationType.callEnded:
        return Icons.call_end;
      case AppNotificationType.report:
        return Icons.flag_outlined;
    }
  }

  Future<void> _confirmDeleteAll(
      BuildContext context, WidgetRef ref, String uid) async {
    final p = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.surfaceElevated,
        title:
            Text('حذف كل الإشعارات؟', style: TextStyle(color: p.textPrimary)),
        content: Text('لا يمكن التراجع عن هذا الإجراء.',
            style: TextStyle(color: p.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('حذف الكل', style: TextStyle(color: p.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(notificationControllerProvider.notifier).deleteAll(uid);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف كل الإشعارات ✓')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('تعذّر حذف الإشعارات: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final uid = ref.watch(authControllerProvider).valueOrNull?.uid;
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'تعليم الكل كمقروء',
            onPressed: uid == null
                ? null
                : () async {
                    try {
                      await ref
                          .read(notificationControllerProvider.notifier)
                          .markAllRead(uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تعليم الكل كمقروء ✓')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تعذّر تحديث الإشعارات: $e')));
                      }
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'حذف الكل',
            onPressed:
                uid == null ? null : () => _confirmDeleteAll(context, ref, uid),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => const ErrorView(message: 'تعذر تحميل الإشعارات الآن. تحقق من الاتصال ثم أعد المحاولة.'),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text('لا توجد إشعارات',
                  style: TextStyle(color: p.textSecondary)),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: p.divider),
            itemBuilder: (context, index) {
              final n = items[index];
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: p.error.withValues(alpha: 0.85),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => ref
                    .read(notificationControllerProvider.notifier)
                    .delete(n.id)
                    .catchError((e) {
                  // كان هذا الاستدعاء "أطلق وانسَ" بلا أي التقاط — أي فشل
                  // (حتى بعد ظهور تأثير السحب البصري) كان يمر دون أي أثر
                  // ظاهر للمستخدم إطلاقًا.
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تعذّر حذف الإشعار: $e')));
                  }
                }),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: n.isRead ? p.surfaceHighlight : p.accent,
                    child: Icon(
                      _iconFor(n.type),
                      size: 18,
                      color: n.isRead ? p.textSecondary : p.background,
                    ),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight:
                          n.isRead ? FontWeight.normal : FontWeight.bold,
                      color: p.textPrimary,
                    ),
                  ),
                  subtitle:
                      Text(n.body, style: TextStyle(color: p.textSecondary)),
                  trailing: IconButton(
                    icon: Icon(Icons.close, size: 18, color: p.textMuted),
                    onPressed: () => ref
                        .read(notificationControllerProvider.notifier)
                        .delete(n.id)
                        .catchError((e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تعذّر حذف الإشعار: $e')));
                      }
                    }),
                  ),
                  onTap: () => ref
                      .read(notificationControllerProvider.notifier)
                      .markRead(n.id)
                      .catchError((e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('تعذّر تحديث الإشعار: $e')));
                    }
                  }),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
