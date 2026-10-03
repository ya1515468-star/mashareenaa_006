import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/role_model.dart';

abstract class RbacRemoteDataSource {
  Future<RoleModel> getUserRole(String uid);

  Future<bool> hasPermission({
    required String uid,
    required String permission,
  });

  Future<void> assignRole({
    required String uid,
    required String roleId,
    required String assignedBy,
  });

  Future<void> assignDefaultRole(String uid);

  Future<List<RoleModel>> listRoles();

  Future<void> updateRolePermissions({
    required String roleId,
    required List<String> permissions,
    required String updatedBy,
  });

  Stream<List<Map<String, dynamic>>> watchAuditLogsRaw({int limit});
}

class RbacRemoteDataSourceImpl implements RbacRemoteDataSource {
  final SupabaseClient supabase;

  RbacRemoteDataSourceImpl(this.supabase);

  String _normalizeRoleId(String code) {
    if (code == AppRoles.dragon) {
      return AppRoles.dragon;
    }

    return code;
  }

  RoleModel _roleFromData(
    Map<String, dynamic> roleRow,
    List<String> permissions,
  ) {
    final rawCode = roleRow['code']?.toString() ??
        roleRow['id']?.toString() ??
        AppRoles.visitor;

    final roleId = _normalizeRoleId(rawCode);

    return RoleModel(
      id: roleId,
      name: roleRow['name']?.toString() ??
          RoleModel.defaults[roleId]?.name ??
          roleId,
      permissions: permissions,
      priority: (roleRow['priority'] as num?)?.toInt() ??
          RoleModel.defaults[roleId]?.priority ??
          0,
    );
  }

  Future<List<String>> _permissionsForRole(
    dynamic roleDbId,
  ) async {
    final response = await supabase
        .from('role_permissions')
        .select('permissions(code)')
        .eq('role_id', roleDbId);

    final permissions = <String>[];

    for (final row in List<Map<String, dynamic>>.from(response)) {
      final permission = row['permissions'];

      if (permission is Map && permission['code'] != null) {
        permissions.add(
          permission['code'].toString(),
        );
      }
    }

    return permissions;
  }

  Future<Map<String, dynamic>?> _findRoleForUser(
    String uid,
  ) async {
    final response = await supabase
        .from('user_roles')
        .select('role_id')
        .eq('user_id', uid)
        .limit(1);

    final rows = List<Map<String, dynamic>>.from(response);

    if (rows.isEmpty) {
      return null;
    }

    final roleDbId = rows.first['role_id'];

    return await supabase
        .from('roles')
        .select('id, code, name, priority')
        .eq('id', roleDbId)
        .maybeSingle();
  }

  @override
  Future<RoleModel> getUserRole(
    String uid,
  ) async {
    try {
      final roleRow = await _findRoleForUser(uid);

      if (roleRow == null) {
        return RoleModel.defaults[AppRoles.visitor]!;
      }

      final permissions = await _permissionsForRole(
        roleRow['id'],
      );

      return _roleFromData(
        roleRow,
        permissions,
      );
    } on PostgrestException catch (e) {
      throw ServerException(
        message: 'تعذّر جلب دور المستخدم: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر جلب دور المستخدم: $e',
      );
    }
  }

  @override
  Future<bool> hasPermission({
    required String uid,
    required String permission,
  }) async {
    try {
      final role = await getUserRole(uid);

      // DRAGON is the platform owner and receives the full administrative
      // permission set. All other roles must use their explicit RBAC permissions;
      // do not bypass sensitive permissions such as store pricing.
      if (role.id == AppRoles.dragon) {
        return true;
      }

      return role.hasPermission(permission);
    } catch (e) {
      throw ServerException(
        message: 'تعذّر التحقق من الصلاحية: $e',
      );
    }
  }

  @override
  Future<void> assignRole({
    required String uid,
    required String roleId,
    required String assignedBy,
  }) async {
    try {
      await supabase.rpc('assign_role', params: {
        'p_target_user_id': uid,
        'p_role_code': roleId,
        'p_assigned_by': assignedBy
      });
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    }
  }

  @override
  Future<void> assignDefaultRole(
    String uid,
  ) async {
    try {
      await supabase.rpc('assign_default_role', params: {
        'p_user_id': uid,
      });
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    }
  }

  @override
  Future<List<RoleModel>> listRoles() async {
    try {
      // Was select('id, code, name') with priority AND permissions filled
      // entirely from the hardcoded RoleModel.defaults map — never from
      // role_permissions or the roles table's own priority column. Every
      // real role currently has ZERO rows in role_permissions, so this
      // screen was showing fabricated permission checkboxes with no
      // relationship to the database at all, and saving would have
      // OVERWRITTEN the real (empty) row with the fake baseline plus
      // whichever single box was clicked — full_replace semantics in
      // update_role_permissions (DELETE then re-INSERT). Confirmed via
      // audit_logs that this save path has never actually been used, so no
      // real damage occurred; fixed before it could.
      final rows = await supabase.from('roles').select('id, code, name, priority');

      final result = <RoleModel>[];

      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final code = row['code']?.toString() ?? row['id']?.toString();

        if (code == null || code.isEmpty) {
          continue;
        }

        final permissions = await _permissionsForRole(row['id']);
        final localDefault = RoleModel.defaults[code];

        result.add(
          RoleModel(
            id: code,
            name: row['name']?.toString() ?? localDefault?.name ?? code,
            permissions: permissions,
            priority: (row['priority'] as num?)?.toInt() ?? localDefault?.priority ?? 0,
          ),
        );
      }

      result.sort(
        (a, b) => b.priority.compareTo(a.priority),
      );

      return result;
    } on PostgrestException catch (e) {
      throw ServerException(
        message: 'تعذّر جلب الأدوار: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر جلب الأدوار: $e',
      );
    }
  }

  @override
  Future<void> updateRolePermissions({
    required String roleId,
    required List<String> permissions,
    required String updatedBy,
  }) async {
    try {
      await supabase.rpc('update_role_permissions', params: {
        'p_role_code': roleId,
        'p_permissions': permissions,
        'p_updated_by': updatedBy
      });
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchAuditLogsRaw({
    int limit = 100,
  }) async* {
    // .stream(primaryKey: ['id']) يفترض داخليًا مفتاحًا نصيًّا، بينما
    // audit_logs.id من نوع bigint — فيرمي
    // "type 'int' is not a subtype of type 'String'" ويُسقط التبويب
    // كاملًا فور فتحه. استطلاع دوري بسيط يتجنّب هذا الافتراض تمامًا
    // ويكفي لسجل تدقيق لا يحتاج تحديثًا لحظيًا بالمللي ثانية.
    while (true) {
      final rows = await supabase
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      yield List<Map<String, dynamic>>.from(rows as List);
      await Future.delayed(const Duration(seconds: 8));
    }
  }
}
