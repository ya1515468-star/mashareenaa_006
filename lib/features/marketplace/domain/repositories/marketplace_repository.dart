import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/listing_entity.dart';
import '../entities/order_entity.dart';

abstract class MarketplaceRepository {
  Stream<List<ListingEntity>> watchListings({String? category});

  Future<Either<Failure, void>> createListing(ListingEntity listing);

  Future<Either<Failure, void>> deleteListing(String listingId);

  Future<Either<Failure, ListingEntity>> getListing(String listingId);

  /// ينشئ طلب شراء بحالة "قيد الانتظار" فقط — الدفع الفعلي (تحويل
  /// شام كاش من المشتري للبائع) يتم داخل [PlaceOrderUseCase] عبر
  /// WalletRepository.transfer، وليس هنا؛ هذه الدالة تُنشئ سجل
  /// الطلب فقط بعد نجاح التحويل.
  Future<Either<Failure, void>> createOrder(OrderEntity order);

  Stream<List<OrderEntity>> watchOrdersAsBuyer(String uid);

  Stream<List<OrderEntity>> watchOrdersAsSeller(String uid);

  Future<Either<Failure, void>> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
  });
}
