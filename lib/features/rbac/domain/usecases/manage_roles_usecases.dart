import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../entities/audit_log_entity.dart';
import '../entities/role_entity.dart';
import '../repositories/rbac_repository.dart';

class ListRolesUseCase {
  final RbacRepository repository;
  const ListRolesUseCase(this.repository);

  Future<Either<Failure, List<RoleEntity>>> call() => repository.listRoles();
}

class UpdateRolePermissionsUseCase {
  final RbacRepository repository;
  const UpdateRolePermissionsUseCase(this.repository);

  /// يتحقق من صلاحية manage_roles قبل التنفيذ — نفس نمط
  /// [AssignRoleUseCase].
  Future<Either<Failure, void>> call({
    required String roleId,
    required List<String> permissions,
    required String requestedByUid,
  }) async {
    final permissionCheck = await repository.hasPermission(
      uid: requestedByUid,
      // Was AppPermissions.manageRoles (now roles.assign — a different real
      // action: granting a role to a user). Changing what a role can DO is
      // the more sensitive, distinct action, so it is gated by its own
      // permission now instead of quietly sharing one with role assignment.
      permission: AppPermissions.managePermissions,
    );
    final allowed = permissionCheck.getOrElse(() => false);
    if (!allowed) return const Left(PermissionFailure());

    return repository.updateRolePermissions(
      roleId: roleId,
      permissions: permissions,
      updatedBy: requestedByUid,
    );
  }
}

class WatchAuditLogsUseCase {
  final RbacRepository repository;
  const WatchAuditLogsUseCase(this.repository);

  Stream<List<AuditLogEntity>> call({int limit = 100}) =>
      repository.watchAuditLogs(limit: limit);
}
