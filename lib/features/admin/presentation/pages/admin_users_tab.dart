import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../../rbac/domain/usecases/assign_role_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/domain/entities/profile_entity.dart';
import '../../../subscriptions/domain/entities/subscription_tier_entity.dart';
import '../../../subscriptions/domain/usecases/grant_membership_feature_usecase.dart';
import '../../domain/usecases/set_account_status_usecase.dart';

/// بحث إداري: كان هذا التبويب يستعمل search_public_profiles — بحث
/// الأعضاء العام الذي يستبعد عمدًا المعلَّقين والمخفية ملفاتهم وغير
/// النشطين ولا يُرجع البريد، أي بالضبط الأعضاء الذين تحتاج الإدارة إلى
/// إيجادهم. admin_search_users يُرجعهم جميعًا وتحرسه صلاحية الإدارة خادميًا.
final _adminUserSearchProvider = FutureProvider.autoDispose
    .family<List<ProfileEntity>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final raw = await Supabase.instance.client
      .rpc('admin_search_users', params: {'p_query': q, 'p_limit': 40});
  final rows = raw is List ? raw : const <dynamic>[];
  return rows
      .whereType<Map>()
      .map((r) {
        final m = Map<String, dynamic>.from(r);
        // ProfileModel.fromMap يقرأ مفاتيح camelCase قديمة، والخادم يُرجع
        // snake_case — بلا هذا التحويل تظهر الأسماء والصور فارغة.
        final name = (m['display_name'] ?? '').toString().trim();
        m['displayName'] =
            name.isNotEmpty ? name : (m['username'] ?? '').toString();
        m['avatarUrl'] = m['avatar_url'];
        return ProfileModel.fromMap(m['id'].toString(), m);
      })
      .toList(growable: false);
});

class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(_adminUserSearchProvider(_query));
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              hintText: 'ابحث باسم المستخدم لإدارة دوره أو حالته...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        Expanded(
          child: _query.isEmpty
              ? const Center(child: Text('اكتب اسمًا للبحث'))
              : resultsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('تعذّر البحث: $e', textAlign: TextAlign.center))),
                  data: (profiles) {
                    if (profiles.isEmpty) {
                      return const Center(child: Text('لا نتائج'));
                    }
                    return ListView.builder(
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        return ExpansionTile(
                          title: ServerUsernameDisplay(
                            uid: profile.uid,
                            fallbackName: profile.displayName,
                            fallbackFontSize: 16,
                          ),
                          subtitle: Text(profile.email),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: AppRoles.all.map((roleId) {
                                      return OutlinedButton(
                                        onPressed: myUid == null
                                            ? null
                                            : () async {
                                                final useCase =
                                                    sl<AssignRoleUseCase>();
                                                final result = await useCase(
                                                  AssignRoleParams(
                                                    targetUid: profile.uid,
                                                    roleId: roleId,
                                                    requestedByUid: myUid,
                                                  ),
                                                );
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      result.isRight()
                                                          ? 'تم إسناد الدور: $roleId'
                                                          : 'فشل: صلاحية غير كافية',
                                                    ),
                                                  ),
                                                );
                                              },
                                        child: Text(roleId,
                                            style:
                                                const TextStyle(fontSize: 11)),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: myUid == null
                                              ? null
                                              : () => _setStatus(
                                                  context,
                                                  myUid,
                                                  profile.uid,
                                                  AccountStatus.active),
                                          child: const Text('تفعيل'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: myUid == null
                                              ? null
                                              : () => _setStatus(
                                                  context,
                                                  myUid,
                                                  profile.uid,
                                                  AccountStatus.suspended),
                                          child: const Text('إيقاف'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: myUid == null
                                              ? null
                                              : () => _setStatus(
                                                  context,
                                                  myUid,
                                                  profile.uid,
                                                  AccountStatus.banned),
                                          child: const Text('حظر'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'منح مزايا عضوية خاصة (DRAGON فقط)',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                        MembershipFeatureKeys.all.map((key) {
                                      return OutlinedButton(
                                        onPressed: myUid == null
                                            ? null
                                            : () async {
                                                final useCase = sl<
                                                    GrantMembershipFeatureUseCase>();
                                                final result = await useCase(
                                                  targetUid: profile.uid,
                                                  featureKey: key,
                                                  enabled: true,
                                                  requestedByUid: myUid,
                                                );
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      result.isRight()
                                                          ? 'تم منح: $key'
                                                          : 'فشل: صلاحية غير كافية',
                                                    ),
                                                  ),
                                                );
                                              },
                                        child: Text(key,
                                            style: const TextStyle(
                                                fontSize: 10.5)),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _setStatus(BuildContext context, String myUid, String targetUid,
      AccountStatus status) async {
    final useCase = sl<SetAccountStatusUseCase>();
    final result = await useCase(
        targetUid: targetUid, status: status, requestedByUid: myUid);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              result.isRight() ? 'تم تحديث الحالة' : 'فشل: صلاحية غير كافية')),
    );
  }
}
