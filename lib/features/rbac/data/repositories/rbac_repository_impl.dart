import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/audit_log_entity.dart';
import '../../domain/entities/role_entity.dart';
import '../../domain/repositories/rbac_repository.dart';
import '../datasources/rbac_remote_data_source.dart';

class RbacRepositoryImpl implements RbacRepository {
  final RbacRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  RbacRepositoryImpl(
      {required this.remoteDataSource, required this.networkInfo});

  @override
  Future<Either<Failure, RoleEntity>> getUserRole(String uid) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final role = await remoteDataSource.getUserRole(uid);
      return Right(role);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> hasPermission({
    required String uid,
    required String permission,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDataSource.hasPermission(
          uid: uid, permission: permission);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> assignRole({
    required String uid,
    required String roleId,
    required String assignedBy,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDataSource.assignRole(
          uid: uid, roleId: roleId, assignedBy: assignedBy);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> assignDefaultRole(String uid) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDataSource.assignDefaultRole(uid);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<RoleEntity>>> listRoles() async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final roles = await remoteDataSource.listRoles();
      return Right(roles);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateRolePermissions({
    required String roleId,
    required List<String> permissions,
    required String updatedBy,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDataSource.updateRolePermissions(
        roleId: roleId,
        permissions: permissions,
        updatedBy: updatedBy,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<AuditLogEntity>> watchAuditLogs({int limit = 100}) {
    // كان هذا التعيين يفترض مخطط Firestore قديمًا (type/targetUid/
    // performedBy/details/createdAt كـTimestamp) لا يطابق audit_logs
    // الفعلي على Supabase إطلاقًا. r['id'] as String وحدها كانت
    // كافية لإسقاط التبويب فورًا (id بيانه bigint)، لكن كل حقل آخر
    // هنا كان سيفشل بصمت أو يُرجع قيمًا افتراضية خاطئة حتى لو أُصلح
    // ذلك السطر وحده.
    return remoteDataSource.watchAuditLogsRaw(limit: limit).map(
          (rows) => rows
              .map(
                (r) => AuditLogEntity(
                  id: r['id'].toString(),
                  type: (r['action'] as String?) ?? 'unknown',
                  targetUid: r['target_id'] as String?,
                  performedBy: (r['actor_id'] ?? r['actor_user_id'])
                          ?.toString() ??
                      'system',
                  details: Map<String, dynamic>.from(
                      r['metadata'] as Map? ?? const {}),
                  createdAt: DateTime.tryParse(
                          r['created_at']?.toString() ?? '') ??
                      DateTime.now(),
                ),
              )
              .toList(),
        );
  }
}
