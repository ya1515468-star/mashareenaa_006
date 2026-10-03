import 'package:equatable/equatable.dart';
import '../../../wallet/domain/entities/currency.dart';

enum ListingType { product, service }

extension ListingTypeX on ListingType {
  String get wire => name;
  static ListingType fromWire(String? s) => ListingType.values
      .firstWhere((e) => e.wire == s, orElse: () => ListingType.product);
}

enum ListingStatus { active, sold, hidden }

extension ListingStatusX on ListingStatus {
  String get wire => name;
  static ListingStatus fromWire(String? s) => ListingStatus.values
      .firstWhere((e) => e.wire == s, orElse: () => ListingStatus.active);
}

/// فئات السوق — منفصلة عن ContentCategories لأن السوق تجاري بحت
/// وليس محتوى اجتماعيًا (منشور مقابل سلعة/خدمة للبيع).
class MarketplaceCategories {
  MarketplaceCategories._();

  static const String garments = 'garments';
  static const String fabrics = 'fabrics';
  static const String manufacturing = 'manufacturing';
  static const String tailoring = 'tailoring';
  static const String accessories = 'accessories';
  static const String other = 'other';

  static const List<String> all = [
    garments,
    fabrics,
    manufacturing,
    tailoring,
    accessories,
    other
  ];

  static String labelOf(String id) {
    switch (id) {
      case garments:
        return 'ملابس جاهزة';
      case fabrics:
        return 'أقمشة';
      case manufacturing:
        return 'تصنيع';
      case tailoring:
        return 'خياطة وتفصيل';
      case accessories:
        return 'إكسسوارات';
      case other:
      default:
        return 'أخرى';
    }
  }
}

class ListingEntity extends Equatable {
  final String id;
  final String sellerUid;
  final String title;
  final String description;
  final Money price;
  final ListingType type;
  final String category;
  final List<String> imageUrls;
  final ListingStatus status;
  final DateTime createdAt;

  const ListingEntity({
    required this.id,
    required this.sellerUid,
    required this.title,
    required this.description,
    required this.price,
    required this.type,
    required this.category,
    this.imageUrls = const [],
    this.status = ListingStatus.active,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        sellerUid,
        title,
        description,
        price,
        type,
        category,
        imageUrls,
        status,
        createdAt
      ];
}
