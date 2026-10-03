import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../repositories/rbac_repository.dart';

class CheckPermissionParams extends Equatable {
  final String uid;
  final String permission;

  const CheckPermissionParams({required this.uid, required this.permission});

  @override
  List<Object?> get props => [uid, permission];
}

class CheckPermissionUseCase {
  final RbacRepository repository;

  const CheckPermissionUseCase(this.repository);

  Future<Either<Failure, bool>> call(CheckPermissionParams params) {
    return repository.hasPermission(
        uid: params.uid, permission: params.permission);
  }
}
