import '../../../../core/data/supabase_document_compat.dart';
import '../../../wallet/domain/entities/currency.dart';
import '../../domain/entities/listing_entity.dart';

class ListingModel extends ListingEntity {
  const ListingModel({
    required super.id,
    required super.sellerUid,
    required super.title,
    required super.description,
    required super.price,
    required super.type,
    required super.category,
    super.imageUrls,
    super.status,
    required super.createdAt,
  });

  factory ListingModel.fromMap(String id, Map<String, dynamic> map) {
    return ListingModel(
      id: id,
      sellerUid: map['sellerUid'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: Money(
        minorUnits: map['priceMinorUnits'] as int? ?? 0,
        currency: CurrencyX.fromWire(map['currency'] as String?),
      ),
      type: ListingTypeX.fromWire(map['type'] as String?),
      category: map['category'] as String? ?? 'other',
      imageUrls: List<String>.from(map['imageUrls'] as List? ?? []),
      status: ListingStatusX.fromWire(map['status'] as String?),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory ListingModel.fromEntity(ListingEntity e) => ListingModel(
        id: e.id,
        sellerUid: e.sellerUid,
        title: e.title,
        description: e.description,
        price: e.price,
        type: e.type,
        category: e.category,
        imageUrls: e.imageUrls,
        createdAt: e.createdAt,
      );

  Map<String, dynamic> toMap() {
    return {
      'sellerUid': sellerUid,
      'title': title,
      'description': description,
      'priceMinorUnits': price.minorUnits,
      'currency': price.currency.wire,
      'type': type.wire,
      'category': category,
      'imageUrls': imageUrls,
      'status': status.wire,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
