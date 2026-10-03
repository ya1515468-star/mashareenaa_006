import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/usecases/resolve_report_usecase.dart';
import '../../domain/usecases/submit_report_usecase.dart';

final allReportsProvider =
    StreamProvider.family<List<ReportEntity>, ReportStatus?>((ref, status) {
  return sl<ReportRepository>().watchAllReports(status: status);
});

class ReportController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submitReport(ReportEntity report) async {
    final result = await sl<SubmitReportUseCase>()(report);
    return result.isRight();
  }

  Future<bool> resolveReport({
    required String reportId,
    required ReportStatus newStatus,
    required String resolvedBy,
  }) async {
    final result = await sl<ResolveReportUseCase>()(
      reportId: reportId,
      newStatus: newStatus,
      resolvedBy: resolvedBy,
    );
    return result.isRight();
  }
}

final reportControllerProvider =
    AsyncNotifierProvider<ReportController, void>(ReportController.new);
