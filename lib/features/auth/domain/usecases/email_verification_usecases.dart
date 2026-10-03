import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/email_verification_repository.dart';

class SendVerificationCodeUseCase {
  final EmailVerificationRepository repository;
  const SendVerificationCodeUseCase(this.repository);

  Future<Either<Failure, void>> call(
      {required String uid, required String email}) {
    return repository.sendVerificationCode(uid: uid, email: email);
  }
}

class ConfirmVerificationCodeUseCase {
  final EmailVerificationRepository repository;
  const ConfirmVerificationCodeUseCase(this.repository);

  Future<Either<Failure, bool>> call(
      {required String uid, required String code}) {
    return repository.confirmVerificationCode(uid: uid, code: code);
  }
}
