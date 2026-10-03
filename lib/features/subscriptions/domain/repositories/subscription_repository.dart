import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription_tier_entity.dart';
import '../entities/user_subscription_entity.dart';

abstract class SubscriptionRepository {
  Future<Either<Failure, UserSubscriptionEntity>> getCurrentSubscription(
      String uid);

  Stream<UserSubscriptionEntity> watchSubscription(String uid);

  /// المزايا الفعلية للمستخدم بعد دمج: مزايا عضويته الحالية + أي
  /// منح خاص من DRAGON (membershipOverrides على حسابه) — أي مزية
  /// يمنحها DRAGON صراحة تبقى فعّالة حتى لو لم تشملها عضويته.
  Future<Either<Failure, MembershipFeatures>> getEffectiveFeatures(String uid);

  /// DRAGON فقط (يُتحقَّق من صلاحية grant_membership_features قبل
  /// التنفيذ) يمنح أو يسحب مزية محدَّدة لأي عضو، بصرف النظر عن
  /// عضويته الفعلية.
  Future<Either<Failure, void>> setFeatureOverride({
    required String targetUid,
    required String featureKey,
    required bool enabled,
    required String grantedByUid,
  });
}
