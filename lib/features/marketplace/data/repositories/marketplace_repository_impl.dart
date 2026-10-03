import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/listing_entity.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../datasources/marketplace_remote_data_source.dart';
import '../models/listing_model.dart';
import '../models/order_model.dart';

class MarketplaceRepositoryImpl implements MarketplaceRepository {
  final MarketplaceRemoteDataSource remoteDataSource;

  MarketplaceRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<ListingEntity>> watchListings({String? category}) =>
      remoteDataSource.watchListings(category: category);

  @override
  Future<Either<Failure, void>> createListing(ListingEntity listing) async {
    try {
      await remoteDataSource.createListing(ListingModel.fromEntity(listing));
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteListing(String listingId) async {
    try {
      await remoteDataSource.deleteListing(listingId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ListingEntity>> getListing(String listingId) async {
    try {
      final listing = await remoteDataSource.getListing(listingId);
      return Right(listing);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> createOrder(OrderEntity order) async {
    try {
      await remoteDataSource.createOrder(
        OrderModel(
          id: '',
          listingId: order.listingId,
          listingTitle: order.listingTitle,
          buyerUid: order.buyerUid,
          sellerUid: order.sellerUid,
          totalPrice: order.totalPrice,
          createdAt: order.createdAt,
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
  Stream<List<OrderEntity>> watchOrdersAsBuyer(String uid) =>
      remoteDataSource.watchOrdersAsBuyer(uid);

  @override
  Stream<List<OrderEntity>> watchOrdersAsSeller(String uid) =>
      remoteDataSource.watchOrdersAsSeller(uid);

  @override
  Future<Either<Failure, void>> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
  }) async {
    try {
      await remoteDataSource.updateOrderStatus(
          orderId: orderId, status: status);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
