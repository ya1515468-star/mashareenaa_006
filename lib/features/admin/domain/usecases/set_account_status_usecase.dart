import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../repositories/admin_repository.dart';

/// كل حالة حساب لها صلاحية مختلفة تحرسها: الإيقاف يحتاج
/// suspend_accounts، الحظر الدائم يحتاج ban_accounts، وإعادة
/// التفعيل تحتاج manage_users — فلا يستطيع مشرف بصلاحية إيقاف
/// بسيطة أن يحظر حسابًا نهائيًا.
class SetAccountStatusUseCase {
  final AdminRepository adminRepository;
  final RbacRepository rbacRepository;

  const SetAccountStatusUseCase(
      {required this.adminRepository, required this.rbacRepository});

  Future<Either<Failure, void>> call({
    required String targetUid,
    required AccountStatus status,
    required String requestedByUid,
  }) async {
    final requiredPermission = switch (status) {
      AccountStatus.suspended => AppPermissions.suspendAccounts,
      AccountStatus.banned => AppPermissions.banAccounts,
      AccountStatus.deleted => AppPermissions.deleteAccounts,
      AccountStatus.active => AppPermissions.manageUsers,
    };

    final permissionResult = await rbacRepository.hasPermission(
      uid: requestedByUid,
      permission: requiredPermission,
    );
    final allowed = permissionResult.getOrElse(() => false);
    if (!allowed) return const Left(PermissionFailure());

    return adminRepository.setAccountStatus(
        targetUid: targetUid, status: status);
  }
}
