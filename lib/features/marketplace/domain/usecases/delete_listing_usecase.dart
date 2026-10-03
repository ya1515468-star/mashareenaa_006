import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../repositories/marketplace_repository.dart';

class DeleteListingUseCase {
  final MarketplaceRepository marketplaceRepository;
  final RbacRepository rbacRepository;

  const DeleteListingUseCase(
      {required this.marketplaceRepository, required this.rbacRepository});

  Future<Either<Failure, void>> call({
    required String listingId,
    required String sellerUid,
    required String requestedByUid,
  }) async {
    if (sellerUid != requestedByUid) {
      final permissionResult = await rbacRepository.hasPermission(
        uid: requestedByUid,
        permission: AppPermissions.moderateContent,
      );
      final allowed = permissionResult.getOrElse(() => false);
      if (!allowed) return const Left(PermissionFailure());
    }

    return marketplaceRepository.deleteListing(listingId);
  }
}
