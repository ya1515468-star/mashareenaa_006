import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../entities/username_credential_entity.dart';
import '../repositories/username_credential_repository.dart';

class CreateUsernamePinParams extends Equatable {
  final String uid;
  final String username;
  final String pin;

  const CreateUsernamePinParams(
      {required this.uid, required this.username, required this.pin});

  @override
  List<Object?> get props => [uid, username, pin];
}

class CreateUsernamePinUseCase {
  final UsernameCredentialRepository repository;
  const CreateUsernamePinUseCase(this.repository);

  Future<Either<Failure, UsernameCredentialEntity>> call(
      CreateUsernamePinParams params) async {
    if (params.pin.length != AppValidation.pinLength) {
      return const Left(
        ValidationFailure(
            message:
                'رمز PIN يجب أن يتكون من ${AppValidation.pinLength} خانات'),
      );
    }
    final validPin = RegExp(r'^[a-zA-Z0-9]+$');
    if (!validPin.hasMatch(params.pin)) {
      return const Left(ValidationFailure(
          message: 'رمز PIN يجب أن يحتوي أرقامًا أو حروفًا فقط'));
    }
    return repository.createUsernameAndPin(
      uid: params.uid,
      username: params.username,
      pin: params.pin,
    );
  }
}
