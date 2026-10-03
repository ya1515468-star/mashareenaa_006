import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/report_entity.dart';

abstract class ReportRepository {
  Future<Either<Failure, void>> submitReport(ReportEntity report);

  /// يبث كل البلاغات (لصفحة الإدارة فقط — التحقق من صلاحية
  /// view_admin_dashboard يتم قبل الوصول لهذه الشاشة أصلًا).
  Stream<List<ReportEntity>> watchAllReports({ReportStatus? status});

  Future<Either<Failure, void>> resolveReport({
    required String reportId,
    required ReportStatus newStatus,
    required String resolvedBy,
  });
}
