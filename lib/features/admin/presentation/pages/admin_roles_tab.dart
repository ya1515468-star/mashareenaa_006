import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../rbac/domain/entities/role_entity.dart';
import '../../../rbac/domain/usecases/manage_roles_usecases.dart';

final allRolesProvider =
    FutureProvider.autoDispose<List<RoleEntity>>((ref) async {
  final result = await sl<ListRolesUseCase>().call();
  return result.fold((failure) => [], (roles) => roles);
});

// كانت هذه قائمة ثابتة بقيم Dart القديمة (manage_users, suspend_accounts...)
// لا تطابق جدول public.permissions الحقيقي إطلاقًا. وبعد تبسيط رموز
// AppPermissions لتطابق القاعدة (خيار "ب" — تجميع الصلاحيات الدقيقة تحت
// الفئة الواسعة في الخادم)، أصبحت خمس ثوابت مختلفة (manageUsers،
// suspendAccounts، banAccounts...) تحمل القيمة نفسها 'users.manage' —
// فقائمة ثابتة بأسماء Dart كانت ستُظهر نفس الصلاحية خمس مرات بتسميات
// متعددة. القائمة تُقرأ الآن من الخادم مباشرة: صلاحية واحدة حقيقية،
// مرة واحدة، دائمًا مطابقة لما تفرضه القاعدة فعليًا.
final _allPermissionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client
      .from('permissions')
      .select('code, description')
      .order('code');
  return List<Map<String, dynamic>>.from(rows);
});

// تسميات عربية أوضح للرموز الأكثر استخدامًا في واجهات الإدارة؛ أي رمز
// غير مذكور هنا يعرض وصفه من الخادم، أو رمزه الخام إن لم يوجد وصف.
const _permissionLabelsAr = {
  'users.manage': 'إدارة المستخدمين (تعليق/حظر/حذف/توثيق)',
  'users.read': 'عرض بيانات المستخدمين',
  'roles.assign': 'تعيين الأدوار وترقية الأعضاء',
  'roles.revoke': 'إلغاء الأدوار',
  'roles.read': 'عرض الأدوار',
  'permissions.manage': 'تعديل صلاحيات الأدوار',
  'permissions.read': 'عرض صلاحيات الأدوار',
  'profile.update': 'تعديل الملف الشخصي',
  'profile.read': 'عرض الملفات الشخصية',
  'chat.moderate': 'الإشراف على المحادثات (قفل/حذف)',
  'chat.read': 'عرض المحادثات',
  'audit.read': 'عرض سجل التدقيق',
  'platform.manage': 'إدارة المنصة (لوحة الإدارة، المكالمات، الإعلانات)',
  'economy.manage': 'إدارة الاقتصاد (نقاط/جواهر/هدايا)',
  'economy.read': 'عرض بيانات الاقتصاد',
  'store.manage': 'إدارة المتجر',
  'store.price.update': 'تعديل أسعار المتجر',
  'store.price.read': 'عرض أسعار المتجر',
  'store.read': 'عرض المتجر',
  'subscription.manage': 'إدارة العضويات ومنح ميزاتها',
  'subscription.read': 'عرض العضويات',
  'security.manage': 'إدارة إعدادات الأمان',
  'security.read': 'عرض إعدادات الأمان',
  'presence.hidden.read': 'رؤية حالة الاتصال المخفية',
  'broadcast_messages': 'بث رسائل عامة',
};

class AdminRolesTab extends ConsumerWidget {
  const AdminRolesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(allRolesProvider);
    final permissionsAsync = ref.watch(_allPermissionsProvider);
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;
    final p = context.palette;

    return rolesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('تعذّر تحميل الأدوار: $e')),
      data: (roles) => permissionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('تعذّر تحميل الصلاحيات: $e')),
        data: (permissionRows) => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: roles.length,
        itemBuilder: (context, index) {
          final role = roles[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              title: Text(role.name,
                  style: TextStyle(
                      color: p.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text(
                  'أولوية: ${role.priority} · ${role.permissions.length} صلاحية'),
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Wrap(
                    children: [
                      for (final permRow in permissionRows)
                        FilterChip(
                          label: Text(
                              _permissionLabelsAr[permRow['code']] ??
                                  permRow['description']?.toString() ??
                                  permRow['code'].toString(),
                              style: const TextStyle(fontSize: 11)),
                          selected: role.hasPermission(permRow['code'].toString()),
                          onSelected: myUid == null
                              ? null
                              : (selected) async {
                                  final perm = permRow['code'].toString();
                                  final updated =
                                      List<String>.from(role.permissions);
                                  if (selected) {
                                    updated.add(perm);
                                  } else {
                                    updated.remove(perm);
                                  }
                                  await sl<UpdateRolePermissionsUseCase>().call(
                                    roleId: role.id,
                                    permissions: updated,
                                    requestedByUid: myUid,
                                  );
                                  ref.invalidate(allRolesProvider);
                                },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}
