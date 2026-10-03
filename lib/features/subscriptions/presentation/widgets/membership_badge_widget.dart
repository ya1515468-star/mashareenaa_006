import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/subscription_tier_entity.dart';
import '../../domain/repositories/subscription_repository.dart';

/// يجلب العضوية الفعّالة الحالية لأي uid — يُستخدم لعرض الشارة
/// بجانب اسمه في أي مكان (رأس المحادثة، البروفايل، لاحقًا: فقاعة
/// الرسالة). autoDispose لتفادي تكديس ذاكرة لمستخدمين كُثر لم تعد
/// شاراتهم معروضة.
final userTierProvider = FutureProvider.autoDispose
    .family<SubscriptionTierEntity, String>((ref, uid) async {
  final result = await sl<SubscriptionRepository>().getCurrentSubscription(uid);
  return result.fold(
      (failure) => SubscriptionCatalog.free, (sub) => sub.effectiveTier);
});

/// الشارة الصغيرة نفسها — لا تُعرض شيئًا للعضوية المجانية (شارة
/// فارغة عمدًا في [SubscriptionCatalog.free]).
class MembershipBadgeChip extends StatelessWidget {
  final MembershipBadge badge;
  final double fontSize;

  const MembershipBadgeChip(
      {super.key, required this.badge, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    if (badge.emoji.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badge.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badge.color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(badge.emoji, style: TextStyle(fontSize: fontSize + 1)),
          const SizedBox(width: 3),
          Text(badge.labelAr,
              style: TextStyle(
                  fontSize: fontSize,
                  color: badge.color,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// نسخة مبنية مباشرة من uid — تجلب العضوية تلقائيًا عبر
/// [userTierProvider] وتعرض شارتها (أو لا شيء أثناء التحميل/لعضوية
/// مجانية).
class UserMembershipBadge extends ConsumerWidget {
  final String uid;
  final double fontSize;
  const UserMembershipBadge({super.key, required this.uid, this.fontSize = 11});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(userTierProvider(uid));
    return tierAsync.when(
      data: (tier) =>
          MembershipBadgeChip(badge: tier.badge, fontSize: fontSize),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
