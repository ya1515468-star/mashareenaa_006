import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../rbac/domain/repositories/rbac_repository.dart';
import '../entities/report_entity.dart';
import '../repositories/report_repository.dart';

class ResolveReportUseCase {
  final ReportRepository reportRepository;
  final RbacRepository rbacRepository;

  const ResolveReportUseCase(
      {required this.reportRepository, required this.rbacRepository});

  Future<Either<Failure, void>> call({
    required String reportId,
    required ReportStatus newStatus,
    required String resolvedBy,
  }) async {
    final permissionResult = await rbacRepository.hasPermission(
      uid: resolvedBy,
      permission: AppPermissions.moderateContent,
    );
    final allowed = permissionResult.getOrElse(() => false);
    if (!allowed) return const Left(PermissionFailure());

    return reportRepository.resolveReport(
      reportId: reportId,
      newStatus: newStatus,
      resolvedBy: resolvedBy,
    );
  }
}
