import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/store_item_entity.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/store_remote_data_source.dart';

class StoreRepositoryImpl implements StoreRepository {
  final StoreRemoteDataSource remoteDataSource;
  StoreRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<StoreItemEntity>>> listCatalog() async {
    try {
      final items = await remoteDataSource.listCatalog();
      return Right(items);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateItem({
    required String itemId,
    required int pricePoints,
    required int priceGems,
    required bool enabled,
    required String updatedBy,
  }) async {
    try {
      await remoteDataSource.updateItem(
        itemId: itemId,
        pricePoints: pricePoints,
        priceGems: priceGems,
        enabled: enabled,
        updatedBy: updatedBy,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> purchaseItem({
    required String uid,
    required String itemId,
  }) async {
    try {
      await remoteDataSource.purchaseItem(uid: uid, itemId: itemId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> createItem(
      {required StoreItemEntity item, required String createdBy}) async {
    try {
      await remoteDataSource.createItem(item: item, createdBy: createdBy);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> grantItem(
      {required String targetUid,
      required String itemId,
      required String performedBy}) async {
    try {
      await remoteDataSource.grantItem(
          targetUid: targetUid, itemId: itemId, performedBy: performedBy);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<String>> watchOwnedItemIds(String uid) =>
      remoteDataSource.watchOwnedItemIds(uid);

  @override
  Stream<List<StoreItemEntity>> watchCatalog() =>
      remoteDataSource.watchCatalog();
}
