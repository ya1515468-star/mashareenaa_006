import 'package:flutter/material.dart';

import '../../../../core/utils/email_validation.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';
import 'reset_password_code_page.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final success = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(_emailController.text.trim());
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBarSfx(
        const SnackBar(
          content: Text('تعذّر إرسال رمز الاستعادة، تحقق من البريد المُدخل'),
        ),
      );
      return;
    }

    // كان المسار ينتهي هنا بـpop: تُرسل رسالة ولا توجد في التطبيق أي شاشة
    // لإدخال رمز وتعيين كلمة مرور جديدة. فالرابط كان يفتح التطبيق ويُنشئ
    // جلسة استعادة فيدخل المستخدم إلى الشات دون أن يُعيد التعيين إطلاقًا.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ResetPasswordCodePage(email: _emailController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة الحساب')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'أدخل بريدك الإلكتروني وسنرسل لك رمزًا من 6 أرقام لإعادة تعيين كلمة المرور.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                AuthTextField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  // نفس صنف العطل: خطأ مطبعي في النطاق يعني أنّ رسالة
                  // الاستعادة لن تصل أبدًا بلا أي رسالة خطأ.
                  validator: EmailValidation.validate,
                ),
                const SizedBox(height: 24),
                AuthButton(
                    label: 'إرسال رابط الاستعادة',
                    isLoading: _isLoading,
                    onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
