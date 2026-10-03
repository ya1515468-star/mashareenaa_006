import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/role_entity.dart';

class RoleModel extends RoleEntity {
  const RoleModel({
    required super.id,
    required super.name,
    required super.permissions,
    required super.priority,
  });

  factory RoleModel.fromMap(String id, Map<String, dynamic> map) {
    return RoleModel(
      id: id,
      name: map['name'] as String? ?? id,
      permissions: List<String>.from(
        map['permissions'] as List? ?? [],
      ),
      priority: map['priority'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'permissions': permissions,
        'priority': priority,
      };

  /// ═══════════════════════════════════════════════════════════════
  /// الأدوار الافتراضية لنظام RBAC
  ///
  /// ملاحظة أمنية مهمة:
  ///
  /// manageStorePricing موجودة حصريًا في:
  ///
  ///     AppRoles.platformOwner
  ///
  /// ولا توجد في:
  ///
  ///     DRAGON
  ///     superAdmin
  ///     admin
  ///     moderator
  ///     support
  ///     auditor
  ///     أو أي دور آخر.
  ///
  /// تغيير أسعار المتجر وتفعيل/تعطيل عناصره مسؤولية مالك المنصة فقط.
  /// ═══════════════════════════════════════════════════════════════
  static const Map<String, RoleModel> defaults = {
    // ═══════════════════════════════════════════════════════════
    // مالك المنصة
    // ═══════════════════════════════════════════════════════════
    AppRoles.platformOwner: RoleModel(
      id: AppRoles.platformOwner,
      name: 'DRAGON',
      permissions: [
        AppPermissions.manageUsers,
        AppPermissions.manageRoles,
        AppPermissions.suspendAccounts,
        AppPermissions.banAccounts,
        AppPermissions.deleteAccounts,
        AppPermissions.verifyAccounts,
        AppPermissions.editOwnProfile,
        AppPermissions.moderateContent,
        AppPermissions.viewAuditLogs,
        AppPermissions.viewAdminDashboard,
        AppPermissions.unlimitedResources,

        // ═══════════════════════════════════════════════════════
        // المتجر — مالك المنصة فقط
        // ═══════════════════════════════════════════════════════
        AppPermissions.manageStorePricing,
      ],
      priority: 500,
    ),


    // ═══════════════════════════════════════════════════════════
    // المدير العام
    // ═══════════════════════════════════════════════════════════
    AppRoles.superAdmin: RoleModel(
      id: AppRoles.superAdmin,
      name: 'Super Admin',
      permissions: [
        AppPermissions.manageUsers,
        AppPermissions.manageRoles,
        AppPermissions.suspendAccounts,
        AppPermissions.banAccounts,
        AppPermissions.verifyAccounts,
        AppPermissions.editOwnProfile,
        AppPermissions.moderateContent,
        AppPermissions.viewAuditLogs,
        AppPermissions.viewAdminDashboard,
        AppPermissions.unlimitedResources,
      ],
      priority: 300,
    ),

    // ═══════════════════════════════════════════════════════════
    // إدمن
    // ═══════════════════════════════════════════════════════════
    AppRoles.admin: RoleModel(
      id: AppRoles.admin,
      name: 'Admin',
      permissions: [
        AppPermissions.manageUsers,
        AppPermissions.suspendAccounts,
        AppPermissions.verifyAccounts,
        AppPermissions.editOwnProfile,
        AppPermissions.moderateContent,
        AppPermissions.viewAuditLogs,
        AppPermissions.viewAdminDashboard,
      ],
      priority: 200,
    ),

    // ═══════════════════════════════════════════════════════════
    // مشرف
    // ═══════════════════════════════════════════════════════════
    AppRoles.moderator: RoleModel(
      id: AppRoles.moderator,
      name: 'Moderator',
      permissions: [
        AppPermissions.editOwnProfile,
        AppPermissions.moderateContent,
      ],
      priority: 100,
    ),

    // ═══════════════════════════════════════════════════════════
    // دعم فني
    // ═══════════════════════════════════════════════════════════
    AppRoles.support: RoleModel(
      id: AppRoles.support,
      name: 'دعم فني',
      permissions: [
        AppPermissions.editOwnProfile,
        AppPermissions.viewAuditLogs,
      ],
      priority: 70,
    ),

    // ═══════════════════════════════════════════════════════════
    // مدقق
    // ═══════════════════════════════════════════════════════════
    AppRoles.auditor: RoleModel(
      id: AppRoles.auditor,
      name: 'مدقق',
      permissions: [
        AppPermissions.editOwnProfile,
        AppPermissions.viewAuditLogs,
        AppPermissions.viewAdminDashboard,
      ],
      priority: 60,
    ),

    // ═══════════════════════════════════════════════════════════
    // صاحب شركة
    // ═══════════════════════════════════════════════════════════
    AppRoles.businessOwner: RoleModel(
      id: AppRoles.businessOwner,
      name: 'صاحب شركة',
      permissions: [
        AppPermissions.editOwnProfile,
      ],
      priority: 40,
    ),

    // ═══════════════════════════════════════════════════════════
    // معمل
    // ═══════════════════════════════════════════════════════════
    AppRoles.factory: RoleModel(
      id: AppRoles.factory,
      name: 'معمل',
      permissions: [
        AppPermissions.editOwnProfile,
      ],
      priority: 35,
    ),

    // ═══════════════════════════════════════════════════════════
    // ورشة
    // ═══════════════════════════════════════════════════════════
    AppRoles.workshop: RoleModel(
      id: AppRoles.workshop,
      name: 'ورشة',
      permissions: [
        AppPermissions.editOwnProfile,
      ],
      priority: 34,
    ),

    // ═══════════════════════════════════════════════════════════
    // مورّد
    // ═══════════════════════════════════════════════════════════
    AppRoles.supplier: RoleModel(
      id: AppRoles.supplier,
      name: 'مورّد',
      permissions: [
        AppPermissions.editOwnProfile,
      ],
      priority: 33,
    ),

    // ═══════════════════════════════════════════════════════════
    // صاحب مشروع
    // ═══════════════════════════════════════════════════════════
    AppRoles.projectOwner: RoleModel(
      id: AppRoles.projectOwner,
      name: 'صاحب مشروع',
      permissions: [
        AppPermissions.editOwnProfile,
      ],
      priority: 30,
    ),

    // ═══════════════════════════════════════════════════════════
    // مستثمر
    // ═══════════════════════════════════════════════════════════
    AppRoles.investor: RoleModel(
      id: AppRoles.investor,
      name: 'مستثمر',
      permissions: [
        AppPermissions.editOwnProfile,
      ],
      priority: 25,
    ),

    // ═══════════════════════════════════════════════════════════
    // عضو مميز
    // ═══════════════════════════════════════════════════════════
    AppRoles.featuredMember: RoleModel(
      id: AppRoles.featuredMember,
      name: 'عضو مميز',
      permissions: [
        AppPermissions.editOwnProfile,
      ],
      priority: 22,
    ),

    // ═══════════════════════════════════════════════════════════
    // عميل
    // ═══════════════════════════════════════════════════════════
    AppRoles.customer: RoleModel(
      id: AppRoles.customer,
      name: 'عميل',
      permissions: [
        AppPermissions.editOwnProfile,
      ],
      priority: 20,
    ),

    // ═══════════════════════════════════════════════════════════
    // زائر
    // ═══════════════════════════════════════════════════════════
    AppRoles.visitor: RoleModel(
      id: AppRoles.visitor,
      name: 'زائر',
      permissions: [
        AppPermissions.editOwnProfile,
      ],
      priority: 10,
    ),
  };
}

