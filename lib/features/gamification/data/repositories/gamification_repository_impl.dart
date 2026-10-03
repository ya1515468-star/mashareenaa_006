import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/gamification_stats_entity.dart';
import '../../domain/entities/points_package_entity.dart';
import '../../domain/entities/rank_entity.dart';
import '../../domain/repositories/gamification_repository.dart';
import '../datasources/gamification_remote_data_source.dart';
import '../models/rank_table.dart';

class GamificationRepositoryImpl implements GamificationRepository {
  final GamificationRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  GamificationRepositoryImpl(
      {required this.remoteDataSource, required this.networkInfo});

  @override
  Future<Either<Failure, GamificationStatsEntity>> getStats(String uid) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final stats = await remoteDataSource.getStats(uid);
      return Right(stats);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<GamificationStatsEntity> watchStats(String uid) =>
      remoteDataSource.watchStats(uid);

  @override
  Future<Either<Failure, GamificationStatsEntity>> addXp(
    String uid, {
    required String eventType,
    String? referenceType,
    String? referenceId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final stats = await remoteDataSource.addXp(
        uid,
        eventType: eventType,
        referenceType: referenceType,
        referenceId: referenceId,
      );

      return Right(stats);
    } on ServerException catch (e) {
      return Left(
        ServerFailure(
          message: e.message,
          code: e.code,
        ),
      );
    } catch (e) {
      return Left(
        UnknownFailure(
          message: e.toString(),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, GamificationStatsEntity>> claimDailyReward(
    String uid, {
    required int multiplier,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final stats =
          await remoteDataSource.claimDailyReward(uid, multiplier: multiplier);
      return Right(stats);
    } on ServerException catch (e) {
      return Left(ValidationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  RankEntity rankForLevel(int level) => RankTable.forLevel(level);

  @override
  Future<Either<Failure, void>> spendPoints({
    required String uid,
    required int amount,
    required bool unlimited,
  }) async {
    if (!unlimited && !await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      await remoteDataSource.spendPoints(
          uid: uid, amount: amount, unlimited: unlimited);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ValidationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> spendGems({
    required String uid,
    required int amount,
    required bool unlimited,
  }) async {
    if (!unlimited && !await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      await remoteDataSource.spendGems(
          uid: uid, amount: amount, unlimited: unlimited);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ValidationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> creditGems(
      {required String uid, required int amount}) async {
    try {
      await remoteDataSource.creditGems(uid: uid, amount: amount);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ValidationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> creditPoints(
      {required String uid, required int amount}) async {
    try {
      await remoteDataSource.creditPoints(uid: uid, amount: amount);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ValidationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unlockBadge(
      {required String uid, required String badgeId}) async {
    try {
      await remoteDataSource.unlockBadge(uid: uid, badgeId: badgeId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ValidationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> spinMysteryBox(String uid) async {
    try {
      final reward = await remoteDataSource.spinMysteryBox(uid);
      return Right(reward);
    } on ServerException catch (e) {
      return Left(ValidationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> transferPoints({
    required String fromUid,
    required String toUid,
    required int amount,
    required bool bypassChecks,
  }) async {
    try {
      await remoteDataSource.transferPoints(
        fromUid: fromUid,
        toUid: toUid,
        amount: amount,
        bypassChecks: bypassChecks,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ValidationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PointsPackageEntity>>>
      listPointsPackages() async {
    try {
      return Right(await remoteDataSource.listPointsPackages());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updatePointsPackagePrice(
      {required String packageId,
      required int priceMinorUnits,
      required bool enabled,
      required String updatedBy}) async {
    try {
      await remoteDataSource.updatePointsPackagePrice(
          packageId: packageId,
          priceMinorUnits: priceMinorUnits,
          enabled: enabled,
          updatedBy: updatedBy);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, GamificationStatsEntity>> purchasePointsPackage({
    required String uid,
    required String packageId,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final stats = await remoteDataSource.purchasePointsPackage(
          uid: uid, packageId: packageId);
      return Right(stats);
    } on ServerException catch (e) {
      return Left(ValidationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
