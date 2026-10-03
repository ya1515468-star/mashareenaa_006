import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/currency.dart';
import '../../domain/entities/ledger_entry_entity.dart';
import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_remote_data_source.dart';

class WalletRepositoryImpl implements WalletRepository {
  final WalletRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  WalletRepositoryImpl(
      {required this.remoteDataSource, required this.networkInfo});

  @override
  Future<Either<Failure, WalletEntity>> getWallet(String uid) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final wallet = await remoteDataSource.getWallet(uid);
      return Right(wallet);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<WalletEntity> watchWallet(String uid) =>
      remoteDataSource.watchWallet(uid);

  @override
  Future<Either<Failure, List<LedgerEntryEntity>>> getHistory(String uid,
      {int limit = 50}) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final history = await remoteDataSource.getHistory(uid, limit: limit);
      return Right(history);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> transfer({
    required String fromUid,
    required String toUid,
    required Money amount,
    String? note,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDataSource.transfer(
          fromUid: fromUid, toUid: toUid, amount: amount, note: note);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ValidationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> credit({
    required String uid,
    required Money amount,
    required LedgerEntryType type,
    String? note,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDataSource.credit(
          uid: uid, amount: amount, type: type, note: note);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> debit({
    required String uid,
    required Money amount,
    required LedgerEntryType type,
    String? note,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDataSource.debit(
          uid: uid, amount: amount, type: type, note: note);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ValidationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
