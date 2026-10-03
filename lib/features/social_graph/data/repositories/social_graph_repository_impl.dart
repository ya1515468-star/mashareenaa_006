import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/social_graph_repository.dart';
import '../datasources/social_graph_remote_data_source.dart';

class SocialGraphRepositoryImpl implements SocialGraphRepository {
  final SocialGraphRemoteDataSource remoteDataSource;

  SocialGraphRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> follow(
      {required String followerUid, required String targetUid}) async {
    try {
      await remoteDataSource.follow(
          followerUid: followerUid, targetUid: targetUid);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unfollow(
      {required String followerUid, required String targetUid}) async {
    try {
      await remoteDataSource.unfollow(
          followerUid: followerUid, targetUid: targetUid);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<bool> watchIsFollowing(
          {required String followerUid, required String targetUid}) =>
      remoteDataSource.watchIsFollowing(
          followerUid: followerUid, targetUid: targetUid);

  @override
  Stream<int> watchFollowersCount(String uid) =>
      remoteDataSource.watchFollowersCount(uid);

  @override
  Stream<int> watchFollowingCount(String uid) =>
      remoteDataSource.watchFollowingCount(uid);

  @override
  Stream<List<String>> watchFollowingUids(String uid) =>
      remoteDataSource.watchFollowingUids(uid);

  @override
  Future<Either<Failure, void>> block(
      {required String blockerUid, required String targetUid}) async {
    try {
      await remoteDataSource.block(
          blockerUid: blockerUid, targetUid: targetUid);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unblock(
      {required String blockerUid, required String targetUid}) async {
    try {
      await remoteDataSource.unblock(
          blockerUid: blockerUid, targetUid: targetUid);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isBlocked(
      {required String blockerUid, required String targetUid}) async {
    try {
      final result = await remoteDataSource.isBlocked(
          blockerUid: blockerUid, targetUid: targetUid);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<String>> watchBlockedUids(String uid) =>
      remoteDataSource.watchBlockedUids(uid);

  @override
  Future<Either<Failure, bool>> hasBlockEitherDirection(
      {required String uidA, required String uidB}) async {
    try {
      final aBlockedB =
          await remoteDataSource.isBlocked(blockerUid: uidA, targetUid: uidB);
      if (aBlockedB) return const Right(true);
      final bBlockedA =
          await remoteDataSource.isBlocked(blockerUid: uidB, targetUid: uidA);
      return Right(bBlockedA);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
