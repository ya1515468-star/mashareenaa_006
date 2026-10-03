import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/role_entity.dart';
import '../entities/audit_log_entity.dart';

abstract class RbacRepository {
  Future<Either<Failure, RoleEntity>> getUserRole(String uid);

  Future<Either<Failure, bool>> hasPermission(
      {required String uid, required String permission});

  Future<Either<Failure, void>> assignRole({
    required String uid,
    required String roleId,
    required String assignedBy,
  });

  Future<Either<Failure, void>> assignDefaultRole(String uid);

  /// يجلب كل الأدوار — من طبقة بيانات Supabase إن كانت مهيَّأة، وإلا من القيم
  /// الافتراضية المحلية (RoleModel.defaults) كنقطة بداية، مع تهيئتها
  /// في طبقة بيانات Supabase تلقائيًا عند أول استدعاء (Seed).
  Future<Either<Failure, List<RoleEntity>>> listRoles();

  /// يحدّث قائمة صلاحيات دور معيّن — يتحقق من صلاحية manage_roles أولًا.
  Future<Either<Failure, void>> updateRolePermissions({
    required String roleId,
    required List<String> permissions,
    required String updatedBy,
  });

  /// سجل التدقيق: كل الإجراءات الإدارية الحساسة تُكتب هنا تلقائيًا.
  Stream<List<AuditLogEntity>> watchAuditLogs({int limit});
}
