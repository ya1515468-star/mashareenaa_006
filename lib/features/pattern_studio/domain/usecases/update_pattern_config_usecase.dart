import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../entities/pattern_enums.dart';
import '../repositories/pattern_studio_repository.dart';

class UpdatePatternConfigUseCase {
  final PatternStudioRepository patternRepository;
  final RbacRepository rbacRepository;

  const UpdatePatternConfigUseCase(
      {required this.patternRepository, required this.rbacRepository});

  Future<Either<Failure, void>> call({
    required PatternStudioConfigEntity config,
    required String requestedByUid,
  }) async {
    final permissionResult = await rbacRepository.hasPermission(
      uid: requestedByUid,
      permission: AppPermissions.viewAdminDashboard,
    );
    final allowed = permissionResult.getOrElse(() => false);
    if (!allowed) return const Left(PermissionFailure());

    return patternRepository.updateConfig(config);
  }
}
