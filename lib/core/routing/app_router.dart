import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/widgets/pin_lock_gate.dart';
import '../../features/home/presentation/pages/home_shell.dart';
import '../widgets/loading_indicator.dart';
import '../../features/notifications/presentation/widgets/login_announcement_gate.dart';

/// نقطة القرار المركزية: تعرض شاشة الدخول أو [HomeShell] (الشاشة
/// الرئيسية الفعلية بتبويباتها) اعتمادًا حصريًا على
/// [authControllerProvider]. عند وجود مستخدم، تُغلَّف [HomeShell]
/// اختياريًا بـ [PinLockGate] إن كان قد فعّل قفل PIN سريع على هذا
/// الجهاز.
class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (_, __) => const LoginPage(),
      data: (user) => user == null
          ? const LoginPage()
          : PinLockGate(
              uid: user.uid,
              child: const LoginAnnouncementGate(child: HomeShell()),
            ),
    );
  }
}
