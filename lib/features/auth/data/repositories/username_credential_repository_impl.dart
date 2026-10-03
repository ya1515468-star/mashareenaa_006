import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/username_credential_entity.dart';
import '../../domain/repositories/username_credential_repository.dart';
import '../datasources/username_credential_remote_data_source.dart';

class UsernameCredentialRepositoryImpl implements UsernameCredentialRepository {
  final UsernameCredentialRemoteDataSource remoteDataSource;
  UsernameCredentialRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, bool>> isUsernameAvailable(String username) async {
    try {
      final available = await remoteDataSource.isUsernameAvailable(username);
      return Right(available);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UsernameCredentialEntity>> createUsernameAndPin({
    required String uid,
    required String username,
    required String pin,
  }) async {
    try {
      final result = await remoteDataSource.createUsernameAndPin(
        uid: uid,
        username: username,
        pin: pin,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> verifyPin(
      {required String uid, required String pin}) async {
    try {
      final result = await remoteDataSource.verifyPin(uid: uid, pin: pin);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> resolveUidByUsername(String username) async {
    try {
      final uid = await remoteDataSource.resolveUidByUsername(username);
      if (uid == null) {
        return const Left(ValidationFailure(message: 'لا يوجد عضو بهذا الاسم'));
      }
      return Right(uid);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
