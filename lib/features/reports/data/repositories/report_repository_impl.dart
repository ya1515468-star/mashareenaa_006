import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_remote_data_source.dart';
import '../models/report_model.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ReportRemoteDataSource remoteDataSource;

  ReportRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> submitReport(ReportEntity report) async {
    try {
      await remoteDataSource.submitReport(
        ReportModel(
          id: '',
          reporterUid: report.reporterUid,
          targetType: report.targetType,
          targetId: report.targetId,
          reason: report.reason,
          createdAt: report.createdAt,
          evidenceUrl: report.evidenceUrl,
        ),
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<ReportEntity>> watchAllReports({ReportStatus? status}) =>
      remoteDataSource.watchAllReports(status: status);

  @override
  Future<Either<Failure, void>> resolveReport({
    required String reportId,
    required ReportStatus newStatus,
    required String resolvedBy,
  }) async {
    try {
      await remoteDataSource.resolveReport(
          reportId: reportId, newStatus: newStatus, resolvedBy: resolvedBy);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
