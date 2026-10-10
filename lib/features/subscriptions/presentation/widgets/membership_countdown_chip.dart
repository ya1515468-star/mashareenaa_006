import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/subscription_provider.dart';

/// عدّاد الأيام المتبقية لانتهاء العضوية المدفوعة (يظهر في البروفايل).
/// لا يظهر للحساب المجاني أو للعضوية المنتهية.
class MembershipCountdownChip extends ConsumerWidget {
  const MembershipCountdownChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(currentSubscriptionProvider).valueOrNull;
    final exp = sub?.expiresAt;
    if (sub == null || exp == null || !sub.isActive) {
      return const SizedBox.shrink();
    }
    final left = exp.difference(DateTime.now());
    if (left.isNegative) return const SizedBox.shrink();

    final String label;
    if (left.inDays >= 1) {
      // نقرّب للأعلى كي لا يظهر «0 يوم» وما زال هناك ساعات.
      final days = left.inHours % 24 == 0 ? left.inDays : left.inDays + 1;
      label = 'متبقّي $days يوم على انتهاء العضوية';
    } else if (left.inHours >= 1) {
      label = 'متبقّي ${left.inHours} ساعة على انتهاء العضوية';
    } else {
      label = 'تنتهي العضوية خلال أقل من ساعة';
    }
    final urgent = left.inDays < 3;
    final color = urgent ? Colors.orangeAccent : Colors.greenAccent;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.hourglass_bottom_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
