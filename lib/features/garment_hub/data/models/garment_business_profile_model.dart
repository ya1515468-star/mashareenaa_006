import '../../../../core/data/supabase_document_compat.dart';
import '../../domain/entities/garment_business_profile_entity.dart';

class GarmentBusinessProfileModel extends GarmentBusinessProfileEntity {
  const GarmentBusinessProfileModel({
    required super.uid,
    required super.businessType,
    required super.businessName,
    super.description,
    super.specialties,
    super.minOrderQuantity,
    super.monthlyCapacity,
    super.contactPhone,
    super.city,
    super.country,
    required super.updatedAt,
  });

  factory GarmentBusinessProfileModel.fromMap(
      String uid, Map<String, dynamic> map) {
    final business = (map['garmentBusiness'] as Map?) ?? {};
    return GarmentBusinessProfileModel(
      uid: uid,
      businessType:
          GarmentBusinessTypeX.fromWire(business['businessType'] as String?),
      businessName: business['businessName'] as String? ?? '',
      description: business['description'] as String? ?? '',
      specialties: List<String>.from(business['specialties'] as List? ?? []),
      minOrderQuantity: business['minOrderQuantity'] as int? ?? 0,
      monthlyCapacity: business['monthlyCapacity'] as int? ?? 0,
      contactPhone: business['contactPhone'] as String?,
      city: business['city'] as String?,
      country: business['country'] as String?,
      updatedAt:
          (business['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFieldMap() {
    return {
      'garmentBusiness': {
        'businessType': businessType.wire,
        'businessName': businessName,
        'description': description,
        'specialties': specialties,
        'minOrderQuantity': minOrderQuantity,
        'monthlyCapacity': monthlyCapacity,
        'contactPhone': contactPhone,
        'city': city,
        'country': country,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    };
  }
}
