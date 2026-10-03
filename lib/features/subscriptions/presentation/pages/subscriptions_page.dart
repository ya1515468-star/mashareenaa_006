import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/subscription_tier_entity.dart';
import '../providers/subscription_provider.dart';
import '../widgets/membership_store_tab.dart';

/// شاشة الميزات — تعرض حالة عضوية المستخدم الحالية (تحذير الانتهاء
/// القريب + اسم العضوية النشطة) فوق كتالوج العضويات الحقيقي
/// (MembershipStoreTab)، وهو المصدر الوحيد لبيانات/أسعار/شراء
/// العضويات — لا يوجد كتالوج ثابت مكرَّر في هذا الملف.
class SubscriptionsPage extends ConsumerWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAsync = ref.watch(currentSubscriptionProvider);
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('الميزات')),
      body: Column(
        children: [
          // Status header (current tier / expiry warning) stays specific to
          // this page; the actual tier catalog below is the same
          // server-driven MembershipStoreTab used elsewhere, so there is
          // exactly one source of truth for tier data/pricing/gifting
          // instead of the previously duplicated hardcoded tier list.
          currentAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (current) {
              final widgets = <Widget>[];
              if (current != null && current.expiresAt != null) {
                final daysLeft =
                    current.expiresAt!.difference(DateTime.now()).inDays;
                if (daysLeft <= 3 && daysLeft >= 0) {
                  widgets.add(Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: p.warning.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: p.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            daysLeft == 0
                                ? 'عضويتك تنتهي اليوم! جدّدها للحفاظ على مزاياك'
                                : 'عضويتك تنتهي خلال $daysLeft ${daysLeft == 1 ? 'يوم' : 'أيام'}',
                            style: TextStyle(fontSize: 12, color: p.warning),
                          ),
                        ),
                      ],
                    ),
                  ));
                }
              }
              if (current != null &&
                  current.effectiveTier.id != SubscriptionCatalog.freeTierId) {
                widgets.add(Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'عضويتك الحالية: ${current.effectiveTier.name}'
                    '${current.expiresAt != null ? ' — تنتهي في ${current.expiresAt!.toLocal().toString().split(' ').first}' : ''}',
                    style: TextStyle(color: p.textSecondary),
                  ),
                ));
              }
              return widgets.isEmpty
                  ? const SizedBox.shrink()
                  : Column(children: widgets);
            },
          ),
          const Expanded(child: MembershipStoreTab()),
        ],
      ),
    );
  }
}
