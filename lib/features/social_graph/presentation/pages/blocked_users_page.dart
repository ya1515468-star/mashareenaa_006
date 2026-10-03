import 'package:flutter/material.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/repositories/social_graph_repository.dart';
import '../../domain/usecases/unblock_usecase.dart';

final blockedUidsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final uid = ref.watch(authControllerProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return sl<SocialGraphRepository>().watchBlockedUids(uid);
});

/// ميزة 9 من القائمة الإضافية: شاشة مستقلة لإدارة قائمة المحظورين
/// (عرض + إلغاء حظر) — الحظر نفسه موجود مسبقًا في صفحة الملف
/// الشخصي، لكن لم تكن هناك طريقة لمراجعة القائمة أو التراجع عنها.
class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedUidsProvider);
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('المستخدمون المحظورون')),
      body: blockedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('تعذّر التحميل: $e')),
        data: (uids) {
          if (uids.isEmpty) {
            return Center(
                child: Text('لا يوجد مستخدمون محظورون',
                    style: TextStyle(color: p.textSecondary)));
          }
          return ListView.builder(
            itemCount: uids.length,
            itemBuilder: (context, index) {
              final blockedUid = uids[index];
              return RepaintBoundary(
                child: Consumer(
                  builder: (context, ref, _) {
                    final profileAsync =
                        ref.watch(profileByIdProvider(blockedUid));
                    final name = profileAsync.valueOrNull?.displayName ?? 'عضو';
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.block)),
                      title: ServerUsernameDisplay(uid: blockedUid, fallbackName: name, fallbackFontSize: 14),
                      // ListTile.trailing يمنح عرضًا لانهائيًا دائمًا مهما
                      // كان الابن — نفس نمط BoxConstraints المتكرر في
                      // سجل الأخطاء. ConstrainedBox يحدّه.
                      trailing: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: TextButton(
                          onPressed: myUid == null
                              ? null
                              : () => sl<UnblockUseCase>()
                                  .call(blockerUid: myUid, targetUid: blockedUid),
                          child: const Text('إلغاء الحظر',
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
