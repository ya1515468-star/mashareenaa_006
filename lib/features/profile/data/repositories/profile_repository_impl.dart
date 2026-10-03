import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';
import '../models/profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ProfileRepositoryImpl(
      {required this.remoteDataSource, required this.networkInfo});

  @override
  Future<Either<Failure, ProfileEntity>> createProfile({
    required String uid,
    required String displayName,
    required String email,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final profile = await remoteDataSource.createProfile(
          uid: uid, displayName: displayName, email: email);
      return Right(profile);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ProfileEntity>> getProfile(String uid) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final profile = await remoteDataSource.getProfile(uid);
      return Right(profile);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ProfileEntity>> updateProfile(
      ProfileEntity profile) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final updated = await remoteDataSource
          .updateProfile(ProfileModel.fromEntity(profile));
      return Right(updated);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateTypography({required String usernameFontFamily, required String messageFontFamily}) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDataSource.updateTypography(
        usernameFontFamily: usernameFontFamily,
        messageFontFamily: messageFontFamily,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }


  @override
  Stream<ProfileEntity?> watchProfile(String uid) =>
      remoteDataSource.watchProfile(uid);

  @override
  Future<Either<Failure, void>> setVerified(String uid, bool verified) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDataSource.setVerified(
        uid: uid,
        verified: verified,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
