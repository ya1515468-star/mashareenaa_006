import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/role_entity.dart';
import '../repositories/rbac_repository.dart';

class GetUserRoleUseCase {
  final RbacRepository repository;

  const GetUserRoleUseCase(this.repository);

  Future<Either<Failure, RoleEntity>> call(String uid) {
    return repository.getUserRole(uid);
  }
}
