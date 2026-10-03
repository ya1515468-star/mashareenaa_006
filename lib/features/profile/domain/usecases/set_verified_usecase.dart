import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../repositories/profile_repository.dart';

class SetVerifiedParams {
  final String targetUid;
  final bool verified;
  final String requestedByUid;

  const SetVerifiedParams({
    required this.targetUid,
    required this.verified,
    required this.requestedByUid,
  });
}

class SetVerifiedUseCase {
  final ProfileRepository profileRepository;
  final RbacRepository rbacRepository;

  const SetVerifiedUseCase(
      {required this.profileRepository, required this.rbacRepository});

  Future<Either<Failure, void>> call(SetVerifiedParams params) async {
    final permissionResult = await rbacRepository.hasPermission(
      uid: params.requestedByUid,
      permission: AppPermissions.verifyAccounts,
    );

    if (permissionResult.isLeft()) {
      return permissionResult.fold(
          (failure) => Left(failure), (_) => const Left(UnknownFailure()));
    }

    final allowed = permissionResult.getOrElse(() => false);
    if (!allowed) return const Left(PermissionFailure());

    return profileRepository.setVerified(params.targetUid, params.verified);
  }
}
