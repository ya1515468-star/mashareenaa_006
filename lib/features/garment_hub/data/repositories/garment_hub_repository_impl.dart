import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/garment_business_profile_entity.dart';
import '../../domain/repositories/garment_hub_repository.dart';
import '../datasources/garment_hub_remote_data_source.dart';
import '../models/garment_business_profile_model.dart';

class GarmentHubRepositoryImpl implements GarmentHubRepository {
  final GarmentHubRemoteDataSource remoteDataSource;

  GarmentHubRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> upsertBusinessProfile(
      GarmentBusinessProfileEntity profile) async {
    try {
      await remoteDataSource.upsertBusinessProfile(
        GarmentBusinessProfileModel(
          uid: profile.uid,
          businessType: profile.businessType,
          businessName: profile.businessName,
          description: profile.description,
          specialties: profile.specialties,
          minOrderQuantity: profile.minOrderQuantity,
          monthlyCapacity: profile.monthlyCapacity,
          contactPhone: profile.contactPhone,
          city: profile.city,
          country: profile.country,
          updatedAt: profile.updatedAt,
        ),
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, GarmentBusinessProfileEntity?>> getBusinessProfile(
      String uid) async {
    try {
      final profile = await remoteDataSource.getBusinessProfile(uid);
      return Right(profile);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<GarmentBusinessProfileEntity>> watchDirectory(
          {GarmentBusinessType? businessType}) =>
      remoteDataSource.watchDirectory(businessType: businessType);
}
