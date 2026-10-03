import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/listing_entity.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../../domain/usecases/create_listing_usecase.dart';
import '../../domain/usecases/delete_listing_usecase.dart';
import '../../domain/usecases/place_order_usecase.dart';
import '../../domain/usecases/update_order_status_usecase.dart';

final listingsProvider =
    StreamProvider.family<List<ListingEntity>, String?>((ref, category) {
  return sl<MarketplaceRepository>().watchListings(category: category);
});

final myOrdersAsBuyerProvider = StreamProvider<List<OrderEntity>>((ref) {
  final uid = ref.watch(authControllerProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return sl<MarketplaceRepository>().watchOrdersAsBuyer(uid);
});

final myOrdersAsSellerProvider = StreamProvider<List<OrderEntity>>((ref) {
  final uid = ref.watch(authControllerProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return sl<MarketplaceRepository>().watchOrdersAsSeller(uid);
});

class MarketplaceController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createListing(ListingEntity listing) async {
    state = const AsyncLoading();
    final result = await sl<CreateListingUseCase>()(listing);
    return result.fold((failure) {
      state = AsyncError(failure.message, StackTrace.current);
      return false;
    }, (_) {
      state = const AsyncData(null);
      return true;
    });
  }

  Future<bool> deleteListing({
    required String listingId,
    required String sellerUid,
    required String requestedByUid,
  }) async {
    final result = await sl<DeleteListingUseCase>()(
      listingId: listingId,
      sellerUid: sellerUid,
      requestedByUid: requestedByUid,
    );
    return result.isRight();
  }

  Future<bool> placeOrder(
      {required ListingEntity listing, required String buyerUid}) async {
    state = const AsyncLoading();
    final result =
        await sl<PlaceOrderUseCase>()(listing: listing, buyerUid: buyerUid);
    return result.fold((failure) {
      state = AsyncError(failure.message, StackTrace.current);
      return false;
    }, (_) {
      state = const AsyncData(null);
      return true;
    });
  }

  Future<bool> updateOrderStatus({
    required OrderEntity order,
    required OrderStatus newStatus,
    required String requestedByUid,
  }) async {
    final result = await sl<UpdateOrderStatusUseCase>()(
      order: order,
      newStatus: newStatus,
      requestedByUid: requestedByUid,
    );
    return result.isRight();
  }
}

final marketplaceControllerProvider =
    AsyncNotifierProvider<MarketplaceController, void>(
        MarketplaceController.new);
