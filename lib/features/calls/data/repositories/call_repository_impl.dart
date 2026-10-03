import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/repositories/call_repository.dart';
import '../datasources/call_remote_data_source.dart';

class CallRepositoryImpl implements CallRepository {
  final CallRemoteDataSource remoteDataSource;

  CallRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, CallEntity>> startCall({
    required String callerUid,
    required String calleeUid,
    required CallType type,
  }) async {
    try {
      final call = await remoteDataSource.startCall(
          callerUid: callerUid, calleeUid: calleeUid, type: type);
      return Right(call);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<CallEntity?> watchIncomingRingingCall(String uid) =>
      remoteDataSource.watchIncomingRingingCall(uid);

  @override
  Stream<CallEntity?> watchCall(String callId) =>
      remoteDataSource.watchCall(callId);

  @override
  Future<Either<Failure, void>> updateStatus(
      {required String callId, required CallStatus status}) async {
    try {
      await remoteDataSource.updateStatus(callId: callId, status: status);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
