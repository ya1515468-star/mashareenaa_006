import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../repositories/gamification_repository.dart';

class SpendGemsUseCase {
  final GamificationRepository gamificationRepository;
  final RbacRepository rbacRepository;

  const SpendGemsUseCase(
      {required this.gamificationRepository, required this.rbacRepository});

  Future<Either<Failure, void>> call(
      {required String uid, required int amount}) async {
    final permissionResult = await rbacRepository.hasPermission(
      uid: uid,
      permission: AppPermissions.unlimitedResources,
    );

    final unlimited = permissionResult.getOrElse(() => false);

    return gamificationRepository.spendGems(
        uid: uid, amount: amount, unlimited: unlimited);
  }
}
