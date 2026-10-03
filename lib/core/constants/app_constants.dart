/// معرفات مجموعات البيانات المنطقية في طبقة Supabase.
class BackendCollections {
  BackendCollections._();

  /// مستند الهوية الأساسي لكل مستخدم (الدور، حالة الحساب، الملف
  /// الشخصي، بيانات المستوى/الرتبة). يطابق مجموعة `accounts`
  /// الموجودة مسبقًا في مشروع Supabase (mashareena-v1) بحسب المخطط
  /// الرسمي — لا تُنشأ مجموعة "users" منفصلة لهذه البيانات.
  static const String accounts = 'accounts';

  /// مجموعة منفصلة مخصصة لاحقًا لنظام اسم المستخدم/PIN.
  /// غير مُفعّلة بعد لأن نظام PIN لم يُبنَ في هذا الإصدار.
  static const String usernames = 'users';

  static const String roles = 'roles';
  static const String auditLogs = 'audit_logs';

  /// أكواد تأكيد البريد الإلكتروني بعد التسجيل.
  static const String verificationCodes = 'verification_codes';
}

/// الأدوار لنظام مشاريعنا.
///
/// ملاحظة أمنية:
/// DRAGON هو الدور الموحد لمالك المنصة، والصلاحيات الحساسة تبقى مفروضة خادميًا.
class AppRoles {
  AppRoles._();

  static const String dragon = 'dragon';
    // Platform owner unified role. Persisted role code: dragon.
  static const String platformOwner = dragon;
  static const String superAdmin = 'super_admin';
  static const String admin = 'admin';
  static const String moderator = 'moderator';
  static const String support = 'support';
  static const String auditor = 'auditor';

  static const String businessOwner = 'business_owner';
  static const String factory = 'factory';
  static const String workshop = 'workshop';
  static const String supplier = 'supplier';
  static const String customer = 'customer';
  static const String projectOwner = 'project_owner';
  static const String investor = 'investor';

  static const String featuredMember = 'featured_member';
  static const String visitor = 'visitor';

  static const List<String> all = [
  dragon,
  superAdmin,
  admin,
  moderator,
  support,
  auditor,
  businessOwner,
  factory,
  workshop,
  supplier,
  customer,
  projectOwner,
  investor,
  featuredMember,
  visitor,
];
}

/// مالك المنصة الموحّد هو DRAGON وفق دور خادمي في Supabase.
/// لا يعتمد العميل على بريد أو معرّف ثابت لتقرير الملكية.
class DragonAccount {
  DragonAccount._();

  static const String displayName = 'DRAGON';
}

/// الصلاحيات الذرية المعرَّفة حاليًا.
///
/// كل وحدة مستقبلية تستخدم RBAC بدل بناء منطق صلاحيات خاص بها.
///
/// مبدأ أمني مهم:
/// الصلاحيات الحساسة يجب أن تكون محددة بشكل صريح.
/// لا يجب اعتبار امتلاك صلاحية إدارية عامة كافيًا للوصول إلى
/// العمليات المالية أو التسعيرية.
class AppPermissions {
  AppPermissions._();

  // ═══════════════════════════════════════════════════════════
  // إدارة الحسابات والصلاحيات
  // ═══════════════════════════════════════════════════════════

  // كل قيمة هنا الآن هي رمز صلاحية حقيقي موجود فعليًا في جدول
  // public.permissions على الخادم — لا رموز يخترعها التطبيق. كانت
  // القيم القديمة (manage_users, suspend_accounts...) لا تطابق أي
  // صف حقيقي إطلاقًا (الخادم يستخدم أسماء بصيغة users.manage)، فكل
  // فحص hasPermission لهذه الصلاحيات كان يفشل دائمًا لغير المالك —
  // لا مسؤول (عدا Dragon) كان يستطيع فعليًا تعليق حساب أو حظره أو
  // حذفه أو أي إجراء آخر مهما كان دوره المُعطى. اختير التبسيط
  // (تجميع الصلاحيات الدقيقة تحت الفئة الواسعة المطابقة في الخادم)
  // بدل توسيع الخادم بفئات جديدة — قرار صريح، لا تخمين.

  static const String manageUsers = 'users.manage';
  /// تعيين دور لمستخدم — مختلف عن تعديل صلاحيات الدور نفسه
  /// (managePermissions أدناه)؛ كان كلاهما يستخدم manageRoles نفسها
  /// سابقًا، وهذا الفصل مقصود لأن تعديل الصلاحيات هو الإجراء الأخطر
  /// في كل نظام RBAC.
  static const String manageRoles = 'roles.assign';
  static const String suspendAccounts = 'users.manage';
  static const String banAccounts = 'users.manage';
  static const String deleteAccounts = 'users.manage';
  static const String verifyAccounts = 'users.manage';

  // ═══════════════════════════════════════════════════════════
  // الملف الشخصي
  // ═══════════════════════════════════════════════════════════

  static const String editOwnProfile = 'profile.update';

  // ═══════════════════════════════════════════════════════════
  // الإشراف والمراقبة
  // ═══════════════════════════════════════════════════════════

  static const String moderateContent = 'chat.moderate';
  static const String viewAuditLogs = 'audit.read';
  static const String viewAdminDashboard = 'platform.manage';

  // ═══════════════════════════════════════════════════════════
  // الموارد
  // ═══════════════════════════════════════════════════════════

  /// موارد غير محدودة (نقاط/جواهر لا تنتهي).
  ///
  /// تُفرض هذه الصلاحية في Domain بمنع عملية الخصم فعليًا
  /// عندما يملك المستخدم الصلاحية.
  static const String unlimitedResources = 'economy.manage';

  // ═══════════════════════════════════════════════════════════
  // صلاحيات المنصة الحساسة
  // ═══════════════════════════════════════════════════════════

  static const String lockConversations = 'chat.moderate';

  static const String stopCalls = 'platform.manage';

  static const String transferPointsAdmin = 'economy.manage';

  static const String promoteMembers = 'roles.assign';

  static const String manageSponsoredAds = 'platform.manage';

  static const String sendGiftsToAll = 'economy.manage';

  static const String broadcastMessages = 'broadcast_messages';

  static const String grantMembershipFeatures = 'subscription.manage';

  /// تعديل الصلاحيات المُسنَدة لدور — الإجراء الأخطر في كل نظام
  /// RBAC. لم تكن له صلاحية مستقلة سابقًا (كان يستخدم manageRoles)؛
  /// فُصلت لتُفرض بدقة أعلى ولتُطابق permissions.manage الحقيقية.
  static const String managePermissions = 'permissions.manage';

  // ═══════════════════════════════════════════════════════════
  // المتجر — صلاحيات حصرية
  // ═══════════════════════════════════════════════════════════

  /// تغيير أسعار عناصر المتجر.
  ///
  /// هذه الصلاحية مخصصة حصريًا لـ: AppRoles.platformOwner (DRAGON)
  /// وتُفرض الخادم عبر RBAC/RPC.
  ///
  /// لا تُمنح لأي دور إداري أدنى.
  ///     superAdmin
  ///     admin
  ///     moderator
  ///     support
  ///     auditor
  ///     أو أي دور آخر
  ///
  /// يجب تطبيق هذا القيد في:
  /// 1. RoleModel.defaults
  /// 2. UpdateStoreItemUseCase
  /// 3. StoreRepository
  /// 4. طبقة بيانات Supabase Security Rules / Backend
  ///
  /// حتى لا يكون تغيير السعر ممكنًا بمجرد التلاعب بواجهة التطبيق.
  static const String manageStorePricing = 'store.price.update';
}

class AppValidation {
  AppValidation._();

  static const int minPasswordLength = 8;
  static const int maxDisplayNameLength = 50;
  static const int maxBioLength = 300;

  // ═══════════════════════════════════════════════════════════
  // اسم المستخدم
  // ═══════════════════════════════════════════════════════════

  /// اسم المستخدم: 3-20 حرف/رقم/شرطة سفلية، بلا مسافات.
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;

  // ═══════════════════════════════════════════════════════════
  // PIN
  // ═══════════════════════════════════════════════════════════

  /// رمز PIN: بالضبط 5 خانات.
  static const int pinLength = 5;

  // ═══════════════════════════════════════════════════════════
  // تأكيد البريد
  // ═══════════════════════════════════════════════════════════

  /// كود تأكيد البريد: 6 أرقام.
  static const int emailCodeLength = 6;

  /// صلاحية كود التأكيد: 10 دقائق.
  static const int emailCodeValidityMinutes = 10;
}




