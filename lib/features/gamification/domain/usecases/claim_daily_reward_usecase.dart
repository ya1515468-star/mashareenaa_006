import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../subscriptions/domain/repositories/subscription_repository.dart';
import '../entities/gamification_stats_entity.dart';
import '../repositories/gamification_repository.dart';

/// يجلب مضاعِف العضوية الحالي (1 للمجاني، 2 لبريميوم، 3 لـ VIP —
/// القيم الفعلية معرّفة في SubscriptionCatalog وليست مكررة هنا) ثم
/// يمرره إلى المستودع لتطبيقه فعليًا على نقاط المكافأة اليومية.
class ClaimDailyRewardUseCase {
  final GamificationRepository gamificationRepository;
  final SubscriptionRepository subscriptionRepository;

  const ClaimDailyRewardUseCase({
    required this.gamificationRepository,
    required this.subscriptionRepository,
  });

  Future<Either<Failure, GamificationStatsEntity>> call(String uid) async {
    final subResult = await subscriptionRepository.getCurrentSubscription(uid);
    final multiplier = subResult.fold(
      (failure) => 1,
      (sub) => sub.effectiveTier.dailyRewardMultiplier,
    );

    return gamificationRepository.claimDailyReward(uid, multiplier: multiplier);
  }
}
