import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../entities/gamification_stats_entity.dart';
import '../entities/points_package_entity.dart';
import '../repositories/gamification_repository.dart';

class PurchasePointsPackageUseCase {
  final GamificationRepository repository;

  const PurchasePointsPackageUseCase(this.repository);

  Future<Either<Failure, GamificationStatsEntity>> call({
    required String uid,
    required String packageId,
  }) async {
    if (packageId.trim().isEmpty) {
      return const Left(ValidationFailure(message: 'حزمة النقاط غير موجودة'));
    }

    return repository.purchasePointsPackage(
        uid: uid, packageId: packageId.trim());
  }
}

class ListPointsPackagesUseCase {
  final GamificationRepository repository;
  const ListPointsPackagesUseCase(this.repository);

  Future<Either<Failure, List<PointsPackageEntity>>> call() =>
      repository.listPointsPackages();
}

class UpdatePointsPackagePriceUseCase {
  final GamificationRepository repository;
  final RbacRepository rbacRepository;
  const UpdatePointsPackagePriceUseCase(this.repository, this.rbacRepository);

  Future<Either<Failure, void>> call(
      {required String packageId,
      required int priceMinorUnits,
      required bool enabled,
      required String requestedByUid}) async {
    final check = await rbacRepository.hasPermission(
        uid: requestedByUid, permission: AppPermissions.manageStorePricing);
    if (!check.getOrElse(() => false)) return const Left(PermissionFailure());
    return repository.updatePointsPackagePrice(
        packageId: packageId,
        priceMinorUnits: priceMinorUnits,
        enabled: enabled,
        updatedBy: requestedByUid);
  }
}
