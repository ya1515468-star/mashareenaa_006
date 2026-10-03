import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/profile_entity.dart';
import '../repositories/profile_repository.dart';

class CreateProfileUseCase {
  final ProfileRepository repository;

  const CreateProfileUseCase(this.repository);

  Future<Either<Failure, ProfileEntity>> call({
    required String uid,
    required String displayName,
    required String email,
  }) {
    return repository.createProfile(
        uid: uid, displayName: displayName, email: email);
  }
}
