import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/pattern_enums.dart';
import '../entities/pattern_request_entity.dart';

abstract class PatternStudioRepository {
  Future<Either<Failure, PatternStudioConfigEntity>> getConfig();

  /// يحدّث إعدادات الميزة (السعر/التفعيل) — لا تتحقق من الصلاحية
  /// هنا؛ التحقق (view_admin_dashboard) يتم في الـ UseCase.
  Future<Either<Failure, void>> updateConfig(PatternStudioConfigEntity config);

  Future<Either<Failure, void>> createRequest(PatternRequestEntity request);

  Stream<List<PatternRequestEntity>> watchMyRequests(String uid);

  /// كل الطلبات لصفحة المراجعة الإدارية.
  Stream<List<PatternRequestEntity>> watchAllRequests(
      {PatternRequestStatus? status});

  Future<Either<Failure, void>> submitResult({
    required String requestId,
    String? resultImageUrl,
    String? resultVideoUrl,
    String? reviewerNote,
  });

  Future<Either<Failure, void>> rejectRequest(
      {required String requestId, required String reason});
}
