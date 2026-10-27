import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/pages/email_verification_code_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/widgets/pin_lock_gate.dart';
import '../../features/home/presentation/pages/home_shell.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/sewing_machine_splash.dart';
import '../widgets/update_gate.dart';
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

    // بوّابة التحديث تُغلِّف كل شيء بما فيه شاشة الدخول: التطبيق يُوزَّع
    // خارج Google Play فلا تحديث تلقائي، ومستخدمٌ على نسخة معطوبة قد لا
    // يستطيع تسجيل الدخول أصلًا — فبوّابةٌ بعد المصادقة لا تصله.
    return UpdateGate(
      child: authState.when(
        loading: () => const Scaffold(body: SewingMachineSplash()),
        error: (_, __) => const LoginPage(),
        data: (user) {
          if (user == null) return const LoginPage();
          // خط الدفاع الثاني ضد تجاوز تأكيد البريد: لا تُبنى HomeShell أبدًا
          // لحساب بريده غير مؤكَّد، أيًّا كان المسار الذي أوصل المستخدم إلى
          // هنا. البوّابة تُقرَّر هنا تصريحيًا لا بترتيب مكدّس التنقّل، فلا
          // تستطيع أي ضغطة «رجوع» كشف الشات من تحتها.
          // مستخدمو Google/Apple يأتون دائمًا بـemailConfirmedAt مضبوطًا،
          // فلا يمسّهم هذا الشرط.
          if (!user.emailVerified) {
            return EmailVerificationCodePage(uid: user.uid, email: user.email);
          }
          return PinLockGate(
            uid: user.uid,
            child: const LoginAnnouncementGate(child: HomeShell()),
          );
        },
      ),
    );
  }
}
