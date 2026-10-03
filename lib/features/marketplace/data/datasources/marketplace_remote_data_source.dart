import '../../../../core/data/supabase_document_compat.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/order_entity.dart';
import '../models/listing_model.dart';
import '../models/order_model.dart';

abstract class MarketplaceRemoteDataSource {
  Stream<List<ListingModel>> watchListings({String? category});
  Future<void> createListing(ListingModel listing);
  Future<void> deleteListing(String listingId);
  Future<ListingModel> getListing(String listingId);
  Future<void> createOrder(OrderModel order);
  Stream<List<OrderModel>> watchOrdersAsBuyer(String uid);
  Stream<List<OrderModel>> watchOrdersAsSeller(String uid);
  Future<void> updateOrderStatus(
      {required String orderId, required OrderStatus status});
}

class MarketplaceRemoteDataSourceImpl implements MarketplaceRemoteDataSource {
  final SupabaseDocumentStore store;

  MarketplaceRemoteDataSourceImpl(this.store);

  CollectionReference<Map<String, dynamic>> get _listings =>
      store.collection('listings');
  CollectionReference<Map<String, dynamic>> get _orders =>
      store.collection('orders');

  @override
  Stream<List<ListingModel>> watchListings({String? category}) {
    Query<Map<String, dynamic>> query = _listings
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(50);
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    return query.snapshots().map((snap) => snap.docs
        .map((d) =>
            ListingModel.fromMap(d.id, Map<String, dynamic>.from(d.data())))
        .toList());
  }

  @override
  Future<void> createListing(ListingModel listing) async {
    try {
      await _listings.add(listing.toMap());
    } catch (e) {
      throw ServerException(message: 'تعذّر نشر الإعلان: $e');
    }
  }

  @override
  Future<void> deleteListing(String listingId) async {
    try {
      // نفس إصلاح posts/comments: حذف مباشر كان يفشل صمتًا لأي مشرف حقيقي
      // غير المالك يحاول حذف إعلان شخص آخر (RLS تسمح فقط لصاحب الإعلان أو
      // Dragon). moderator_delete_content تتحقق من صلاحية chat.moderate.
      await store.rpc('moderator_delete_content', params: {
        'p_collection': 'listings',
        'p_doc_id': listingId,
      });
    } catch (e) {
      throw ServerException(message: 'تعذّر حذف الإعلان: $e');
    }
  }

  @override
  Future<ListingModel> getListing(String listingId) async {
    try {
      final doc = await _listings.doc(listingId).get();
      if (!doc.exists) {
        throw const ServerException(message: 'الإعلان غير موجود');
      }
      return ListingModel.fromMap(doc.id, doc.data()!);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'تعذّر جلب الإعلان: $e');
    }
  }

  @override
  Future<void> createOrder(OrderModel order) async {
    try {
      await _orders.add(order.toMap());
    } catch (e) {
      throw ServerException(message: 'تعذّر تسجيل الطلب: $e');
    }
  }

  @override
  Stream<List<OrderModel>> watchOrdersAsBuyer(String uid) {
    return _orders
        .where('buyerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                OrderModel.fromMap(d.id, Map<String, dynamic>.from(d.data())))
            .toList());
  }

  @override
  Stream<List<OrderModel>> watchOrdersAsSeller(String uid) {
    return _orders
        .where('sellerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                OrderModel.fromMap(d.id, Map<String, dynamic>.from(d.data())))
            .toList());
  }

  @override
  Future<void> updateOrderStatus(
      {required String orderId, required OrderStatus status}) async {
    try {
      await _orders.doc(orderId).update({'status': status.wire});
    } catch (e) {
      throw ServerException(message: 'تعذّر تحديث حالة الطلب: $e');
    }
  }
}
