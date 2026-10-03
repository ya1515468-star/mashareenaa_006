import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/garment_business_profile_entity.dart';

abstract class GarmentHubRepository {
  Future<Either<Failure, void>> upsertBusinessProfile(
      GarmentBusinessProfileEntity profile);

  Future<Either<Failure, GarmentBusinessProfileEntity?>> getBusinessProfile(
      String uid);

  /// دليل الأعمال — يبث كل الملفات التجارية المسجَّلة، مع فلترة
  /// اختيارية بنوع النشاط (معمل/ورشة/مورّد).
  Stream<List<GarmentBusinessProfileEntity>> watchDirectory(
      {GarmentBusinessType? businessType});
}
