import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/friend_request_entity.dart';
import '../../domain/repositories/friend_repository.dart';
import '../datasources/friend_remote_data_source.dart';

class FriendRepositoryImpl implements FriendRepository {
  final FriendRemoteDataSource remoteDataSource;

  FriendRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> sendRequest(
      {required String fromUid, required String toUid}) async {
    try {
      await remoteDataSource.sendRequest(fromUid: fromUid, toUid: toUid);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ValidationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> respondToRequest(
      {required String requestId, required bool accept}) async {
    try {
      await remoteDataSource.respondToRequest(
          requestId: requestId, accept: accept);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeFriend(
      {required String uidA, required String uidB}) async {
    try {
      await remoteDataSource.removeFriend(uidA: uidA, uidB: uidB);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<FriendRequestEntity?> watchRelationship(
          {required String uidA, required String uidB}) =>
      remoteDataSource.watchRelationship(uidA: uidA, uidB: uidB);

  @override
  Stream<List<FriendRequestEntity>> watchFriends(String uid) =>
      remoteDataSource.watchFriends(uid);

  @override
  Stream<List<FriendRequestEntity>> watchPendingIncoming(String uid) =>
      remoteDataSource.watchPendingIncoming(uid);
}
