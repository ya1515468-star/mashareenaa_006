import '../../domain/entities/gift_transaction_entity.dart';
import '../../../../core/data/supabase_document_compat.dart';

class GiftTransactionModel extends GiftTransactionEntity {
  const GiftTransactionModel({
    required super.id,
    required super.giftId,
    required super.fromUid,
    required super.toUid,
    required super.pricePoints,
    required super.createdAt,
  });

  factory GiftTransactionModel.fromMap(String id, Map<String, dynamic> map) {
    return GiftTransactionModel(
      id: id,
      giftId: map['giftId'] as String? ?? '',
      fromUid: map['fromUid'] as String? ?? '',
      toUid: map['toUid'] as String? ?? '',
      pricePoints: map['pricePoints'] as int? ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
