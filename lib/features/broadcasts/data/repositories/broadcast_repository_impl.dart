import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/broadcast_entity.dart';
import '../../domain/repositories/broadcast_repository.dart';
import '../datasources/broadcast_remote_data_source.dart';

class BroadcastRepositoryImpl implements BroadcastRepository {
  final BroadcastRemoteDataSource remoteDataSource;
  BroadcastRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> sendBroadcast({
    required String message,
    required String sentByUid,
  }) async {
    try {
      await remoteDataSource.sendBroadcast(
          message: message, sentByUid: sentByUid);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<BroadcastEntity?> watchLatestBroadcast() =>
      remoteDataSource.watchLatestBroadcast();
}
