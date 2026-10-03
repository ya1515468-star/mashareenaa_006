import '../../../../core/data/supabase_document_compat.dart';
import '../../../wallet/domain/entities/currency.dart';
import '../../domain/entities/order_entity.dart';

class OrderModel extends OrderEntity {
  const OrderModel({
    required super.id,
    required super.listingId,
    required super.listingTitle,
    required super.buyerUid,
    required super.sellerUid,
    required super.totalPrice,
    super.status,
    required super.createdAt,
  });

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    return OrderModel(
      id: id,
      listingId: map['listingId'] as String? ?? '',
      listingTitle: map['listingTitle'] as String? ?? '',
      buyerUid: map['buyerUid'] as String? ?? '',
      sellerUid: map['sellerUid'] as String? ?? '',
      totalPrice: Money(
        minorUnits: map['totalPriceMinorUnits'] as int? ?? 0,
        currency: CurrencyX.fromWire(map['currency'] as String?),
      ),
      status: OrderStatusX.fromWire(map['status'] as String?),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listingId': listingId,
      'listingTitle': listingTitle,
      'buyerUid': buyerUid,
      'sellerUid': sellerUid,
      'totalPriceMinorUnits': totalPrice.minorUnits,
      'currency': totalPrice.currency.wire,
      'status': status.wire,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
