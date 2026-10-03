import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../repositories/username_credential_repository.dart';

class CheckUsernameAvailableUseCase {
  final UsernameCredentialRepository repository;
  const CheckUsernameAvailableUseCase(this.repository);

  Future<Either<Failure, bool>> call(String username) async {
    final trimmed = username.trim();
    if (trimmed.length < AppValidation.minUsernameLength ||
        trimmed.length > AppValidation.maxUsernameLength) {
      return const Left(ValidationFailure(
          message: 'اسم المستخدم يجب أن يكون بين 3 و20 حرفًا'));
    }
    final validPattern = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validPattern.hasMatch(trimmed)) {
      return const Left(
        ValidationFailure(
            message: 'اسم المستخدم يجب أن يحتوي أحرفًا وأرقامًا و(_) فقط'),
      );
    }
    return repository.isUsernameAvailable(trimmed);
  }
}
