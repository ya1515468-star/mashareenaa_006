import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/username_credential_repository.dart';

class VerifyPinUseCase {
  final UsernameCredentialRepository repository;
  const VerifyPinUseCase(this.repository);

  Future<Either<Failure, bool>> call(
      {required String uid, required String pin}) {
    return repository.verifyPin(uid: uid, pin: pin);
  }
}
