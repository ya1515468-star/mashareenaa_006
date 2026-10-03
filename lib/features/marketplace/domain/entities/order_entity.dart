import 'package:equatable/equatable.dart';
import '../../../wallet/domain/entities/currency.dart';

enum OrderStatus { pending, confirmed, shipped, completed, cancelled }

extension OrderStatusX on OrderStatus {
  String get wire => name;
  static OrderStatus fromWire(String? s) => OrderStatus.values
      .firstWhere((e) => e.wire == s, orElse: () => OrderStatus.pending);

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'قيد الانتظار';
      case OrderStatus.confirmed:
        return 'تم التأكيد';
      case OrderStatus.shipped:
        return 'تم الشحن';
      case OrderStatus.completed:
        return 'مكتمل';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }
}

class OrderEntity extends Equatable {
  final String id;
  final String listingId;
  final String listingTitle;
  final String buyerUid;
  final String sellerUid;
  final Money totalPrice;
  final OrderStatus status;
  final DateTime createdAt;

  const OrderEntity({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.buyerUid,
    required this.sellerUid,
    required this.totalPrice,
    this.status = OrderStatus.pending,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        listingId,
        listingTitle,
        buyerUid,
        sellerUid,
        totalPrice,
        status,
        createdAt
      ];
}
