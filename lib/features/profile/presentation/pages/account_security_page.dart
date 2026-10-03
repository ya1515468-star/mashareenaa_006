import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/profile_entity.dart';
import '../widgets/account_setting_tiles.dart';
import 'delete_account_page.dart';

/// يجمع أربعة عناصر متتالية من قائمة الإعدادات والخصوصية: تعديل
/// البريد، تغيير كلمة المرور، تأكيد الحساب وربط Google، وحذف
/// العضوية — كلها إجراءات حسّاسة على مستوى المصادقة.
class AccountSecurityPage extends ConsumerWidget {
  final ProfileEntity profile;
  const AccountSecurityPage({super.key, required this.profile});

  Future<void> _showResult(
      BuildContext context, String? error, String success) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? success)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('أمان الحساب')),
      body: ListView(
        children: [
          TextInputSettingTile(
            icon: Icons.email_outlined,
            title: 'تعديل البريد الإلكتروني',
            currentValueLabel: profile.email,
            initialValue: profile.email,
            dialogLabel: 'البريد الإلكتروني الجديد',
            keyboardType: TextInputType.emailAddress,
            onSave: (value) async {
              final error = await ref
                  .read(authControllerProvider.notifier)
                  .updateEmail(value);
              if (!context.mounted) return;
              await _showResult(context, error,
                  'تم إرسال رابط تأكيد إلى $value — افتحه لإتمام التغيير ✓');
            },
          ),
          TextInputSettingTile(
            icon: Icons.lock_outline,
            title: 'تغيير كلمة المرور',
            initialValue: '',
            dialogLabel: 'كلمة المرور الجديدة',
            obscure: true,
            onSave: (value) async {
              if (value.length < 6) {
                await _showResult(
                    context, 'كلمة المرور قصيرة جدًا (6 أحرف على الأقل)', '');
                return;
              }
              final error = await ref
                  .read(authControllerProvider.notifier)
                  .updatePassword(value);
              if (!context.mounted) return;
              await _showResult(context, error, 'تم تغيير كلمة المرور ✓');
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.verified_user_outlined, color: AppColors.gold),
            title: const Text('تأكيد الحساب وربط Google'),
            subtitle: Text(
              currentUser?.emailVerified == true
                  ? 'البريد موثّق ✓'
                  : 'البريد غير موثّق بعد',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing:
                const Icon(Icons.chevron_left, color: AppColors.textMuted),
            onTap: () async {
              final error = await ref
                  .read(authControllerProvider.notifier)
                  .linkGoogleIdentity();
              if (!context.mounted) return;
              await _showResult(context, error,
                  'تم فتح نافذة ربط Google — أكمل تسجيل الدخول هناك ✓');
            },
          ),
          const Divider(color: AppColors.divider),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined,
                color: AppColors.error),
            title: const Text('حذف عضوية',
                style: TextStyle(color: AppColors.error)),
            subtitle: const Text(
                'حذف الحساب نهائيًا — إجراء لا يمكن التراجع عنه',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            trailing:
                const Icon(Icons.chevron_left, color: AppColors.textMuted),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => DeleteAccountPage(uid: profile.uid)),
            ),
          ),
        ],
      ),
    );
  }
}
