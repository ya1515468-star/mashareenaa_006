import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/email_verification_repository.dart';
import '../datasources/email_verification_remote_data_source.dart';

class EmailVerificationRepositoryImpl implements EmailVerificationRepository {
  final EmailVerificationRemoteDataSource remoteDataSource;
  EmailVerificationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> sendVerificationCode({
    required String uid,
    required String email,
  }) async {
    try {
      await remoteDataSource.sendVerificationCode(uid: uid, email: email);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> confirmVerificationCode({
    required String uid,
    required String code,
  }) async {
    try {
      final verified =
          await remoteDataSource.confirmVerificationCode(uid: uid, code: code);
      return Right(verified);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
