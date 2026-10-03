import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/report_entity.dart';
import '../repositories/report_repository.dart';

class SubmitReportUseCase {
  final ReportRepository repository;

  const SubmitReportUseCase(this.repository);

  Future<Either<Failure, void>> call(ReportEntity report) async {
    if (report.reason.trim().isEmpty) {
      return const Left(ValidationFailure(message: 'الرجاء توضيح سبب البلاغ'));
    }
    return repository.submitReport(report);
  }
}
