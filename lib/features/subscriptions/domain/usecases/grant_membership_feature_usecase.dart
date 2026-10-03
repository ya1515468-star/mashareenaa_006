import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../repositories/subscription_repository.dart';

class GrantMembershipFeatureUseCase {
  final SubscriptionRepository subscriptionRepository;
  final RbacRepository rbacRepository;

  const GrantMembershipFeatureUseCase({
    required this.subscriptionRepository,
    required this.rbacRepository,
  });

  Future<Either<Failure, void>> call({
    required String targetUid,
    required String featureKey,
    required bool enabled,
    required String requestedByUid,
  }) async {
    final permissionCheck = await rbacRepository.hasPermission(
      uid: requestedByUid,
      permission: AppPermissions.grantMembershipFeatures,
    );
    final allowed = permissionCheck.getOrElse(() => false);
    if (!allowed) return const Left(PermissionFailure());

    return subscriptionRepository.setFeatureOverride(
      targetUid: targetUid,
      featureKey: featureKey,
      enabled: enabled,
      grantedByUid: requestedByUid,
    );
  }
}
