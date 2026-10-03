import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../repositories/rbac_repository.dart';

class AssignRoleParams extends Equatable {
  final String targetUid;
  final String roleId;
  final String requestedByUid;

  const AssignRoleParams({
    required this.targetUid,
    required this.roleId,
    required this.requestedByUid,
  });

  @override
  List<Object?> get props => [targetUid, roleId, requestedByUid];
}

/// يتحقق أولًا أن الحساب الطالب يملك صلاحية manage_roles قبل تنفيذ
/// إسناد الدور — نفس Repository يُستخدم للتحقق والتنفيذ معًا.
class AssignRoleUseCase {
  final RbacRepository repository;

  const AssignRoleUseCase(this.repository);

  Future<Either<Failure, void>> call(AssignRoleParams params) async {
    final permissionCheck = await repository.hasPermission(
      uid: params.requestedByUid,
      permission: AppPermissions.manageRoles,
    );

    if (permissionCheck.isLeft()) {
      return permissionCheck.fold(
        (failure) => Left(failure),
        (_) => const Left(UnknownFailure()),
      );
    }

    final allowed = permissionCheck.getOrElse(() => false);
    if (!allowed) {
      return const Left(PermissionFailure());
    }

    return repository.assignRole(
      uid: params.targetUid,
      roleId: params.roleId,
      assignedBy: params.requestedByUid,
    );
  }
}
