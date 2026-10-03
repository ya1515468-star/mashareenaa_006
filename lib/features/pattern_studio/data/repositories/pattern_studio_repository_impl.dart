import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/pattern_enums.dart';
import '../../domain/entities/pattern_request_entity.dart';
import '../../domain/repositories/pattern_studio_repository.dart';
import '../datasources/pattern_studio_remote_data_source.dart';
import '../models/pattern_request_model.dart';

class PatternStudioRepositoryImpl implements PatternStudioRepository {
  final PatternStudioRemoteDataSource remoteDataSource;

  PatternStudioRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PatternStudioConfigEntity>> getConfig() async {
    try {
      final config = await remoteDataSource.getConfig();
      return Right(config);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateConfig(
      PatternStudioConfigEntity config) async {
    try {
      await remoteDataSource.updateConfig(config);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> createRequest(
      PatternRequestEntity request) async {
    try {
      await remoteDataSource.createRequest(
        PatternRequestModel(
          id: '',
          uid: request.uid,
          sourceImageUrl: request.sourceImageUrl,
          mannequinType: request.mannequinType,
          notes: request.notes,
          status: request.status,
          createdAt: request.createdAt,
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
  Stream<List<PatternRequestEntity>> watchMyRequests(String uid) =>
      remoteDataSource.watchMyRequests(uid);

  @override
  Stream<List<PatternRequestEntity>> watchAllRequests(
          {PatternRequestStatus? status}) =>
      remoteDataSource.watchAllRequests(status: status);

  @override
  Future<Either<Failure, void>> submitResult({
    required String requestId,
    String? resultImageUrl,
    String? resultVideoUrl,
    String? reviewerNote,
  }) async {
    try {
      await remoteDataSource.submitResult(
        requestId: requestId,
        resultImageUrl: resultImageUrl,
        resultVideoUrl: resultVideoUrl,
        reviewerNote: reviewerNote,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> rejectRequest(
      {required String requestId, required String reason}) async {
    try {
      await remoteDataSource.rejectRequest(
          requestId: requestId, reason: reason);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
