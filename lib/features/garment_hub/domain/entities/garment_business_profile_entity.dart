import 'package:equatable/equatable.dart';

enum GarmentBusinessType { factory, workshop, supplier }

extension GarmentBusinessTypeX on GarmentBusinessType {
  String get wire => name;

  static GarmentBusinessType fromWire(String? s) =>
      GarmentBusinessType.values.firstWhere(
        (e) => e.wire == s,
        orElse: () => GarmentBusinessType.workshop,
      );

  String get label {
    switch (this) {
      case GarmentBusinessType.factory:
        return 'معمل';
      case GarmentBusinessType.workshop:
        return 'ورشة';
      case GarmentBusinessType.supplier:
        return 'مورّد';
    }
  }
}

/// الملف التجاري المتخصص لمعمل/ورشة/مورّد ضمن Garment Hub — دليل
/// B2B منفصل عن السوق العام، مخصص لمن يملك دور factory/workshop/
/// supplier في RBAC أو نوع حساب تجاري. يُخزَّن كحقل مضمّن إضافي في
/// نفس مستند accounts (garmentBusiness) بدل مجموعة منفصلة، مطابقًا
/// لنمط بقية الوحدات (wallet, subscription...).
class GarmentBusinessProfileEntity extends Equatable {
  final String uid;
  final GarmentBusinessType businessType;
  final String businessName;
  final String description;
  final List<String> specialties;
  final int minOrderQuantity;
  final int monthlyCapacity;
  final String? contactPhone;
  final String? city;
  final String? country;
  final DateTime updatedAt;

  const GarmentBusinessProfileEntity({
    required this.uid,
    required this.businessType,
    required this.businessName,
    this.description = '',
    this.specialties = const [],
    this.minOrderQuantity = 0,
    this.monthlyCapacity = 0,
    this.contactPhone,
    this.city,
    this.country,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        uid,
        businessType,
        businessName,
        description,
        specialties,
        minOrderQuantity,
        monthlyCapacity,
        contactPhone,
        city,
        country,
        updatedAt,
      ];
}
