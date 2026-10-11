import 'package:flutter/material.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/local_session_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium/effects.dart';
import '../widgets/premium/login_visual_variants.dart';
import '../widgets/premium/premium_auth_scaffold.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/premium_text_field.dart';
import '../widgets/premium/remember_me_checkbox.dart';
import '../widgets/premium/social_login_row.dart';
import '../widgets/brand_animated_logo.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _localSession = LocalSessionService();

  bool? _rememberMeOverride;

  @override
  void initState() {
    super.initState();
    _restoreRememberedEmail();
  }

  Future<void> _restoreRememberedEmail() async {
    final email = await _localSession.getRememberedEmail();
    if (email != null && mounted) {
      _emailController.text = email;
      setState(() => _rememberMeOverride = true);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(bool rememberMe) async {
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }

    final success = await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (success) {
      if (rememberMe) {
        await _localSession.saveRememberedEmail(_emailController.text.trim());
      } else {
        await _localSession.clearRememberedEmail();
      }
    } else if (mounted) {
      _shakeKey.currentState?.shake();
      final error = ref.read(authControllerProvider);
      final message = error.error?.toString() ?? 'فشل تسجيل الدخول';
      final requiresConfirmation = message.contains('تأكيد البريد');

      ScaffoldMessenger.of(context).showSnackBarSfx(
        SnackBar(
          content: Text(message),
          action: requiresConfirmation
              ? SnackBarAction(
                  label: 'إعادة الإرسال',
                  onPressed: () async {
                    final resendMessage = await ref
                        .read(authControllerProvider.notifier)
                        .resendSignupConfirmationEmail(
                          _emailController.text.trim(),
                        );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBarSfx(
                      SnackBar(
                        content: Text(
                          resendMessage ??
                              'تمت إعادة إرسال رسالة تأكيد البريد الإلكتروني',
                        ),
                      ),
                    );
                  },
                )
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final variantAsync = ref.watch(loginVisualVariantProvider);
    // كان يُعرض طراز افتراضي (atelier) أثناء الانتظار القصير، ثم يتبدّل
    // فجأة إلى الطراز الحقيقي الذي يختاره الخادم بمجرد وصوله — وبما أن
    // الطرز الثلاثة تختلف فعليًا في خيارات ظاهرة (مثل ظهور زر Apple)، كان
    // هذا التبديل يُرى كوميض حقيقي: يظهر الزر ثم يختفي أو العكس. عرض حالة
    // تحميل نظيفة بدل الافتراض التفاؤلي يمنع هذا التناقض المرئي كليًا.
    if (!variantAsync.hasValue) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0C1C),
        body: Center(child: BrandAnimatedLogo(size: 110)),
      );
    }
    final variant = variantAsync.value!;
    final style = loginVariantStyles[variant]!;
    final rememberMe = _rememberMeOverride ?? style.defaultRememberMe;

    return Theme(
      data: Theme.of(context).copyWith(
        extensions: [AppPaletteExtension(palette: style.palette)],
      ),
      child: Builder(builder: (context) {
        final p = context.palette;
        return PremiumAuthScaffold(
          backgroundImageAsset: style.backgroundAsset,
          child: ShakeWidget(
            key: _shakeKey,
            child: Form(
              key: _formKey,
              child: StaggeredEntrance(
                children: [
                  const Center(child: BrandAnimatedLogo(size: 104)),
                  const SizedBox(height: 12),
                  Text(
                    'Mashareena',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .4,
                        color: p.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    style.tagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: p.accentBright,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    style.heading,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    style.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.textSecondary, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  PremiumTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'الرجاء إدخال البريد الإلكتروني';
                      }
                      if (!value.contains('@')) {
                        return 'صيغة البريد الإلكتروني غير صحيحة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  PremiumTextField(
                    controller: _passwordController,
                    label: 'كلمة المرور',
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال كلمة المرور';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage()),
                            );
                          },
                          child: const Text('نسيت كلمة المرور؟',
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      RememberMeCheckbox(
                        value: rememberMe,
                        onChanged: (v) =>
                            setState(() => _rememberMeOverride = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  PremiumButton(
                      label: 'تسجيل الدخول',
                      isLoading: isLoading,
                      onPressed: () => _submit(rememberMe)),
                  const SizedBox(height: 20),
                  SocialLoginRow(
                    // لم يعد يتبع الطراز البصري العشوائي (كان يُخفي الزر في
                    // طرازين من ثلاثة!) — المنصة الحقيقية وحدها تقرر داخل
                    // SocialLoginRow نفسه.
                    showAppleButton: true,
                    onError: (message) {
                      ScaffoldMessenger.of(context)
                          .showSnackBarSfx(SnackBar(content: Text(message)));
                    },
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('ليس لديك حساب؟',
                          style: TextStyle(color: p.textSecondary)),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              transitionDuration: const Duration(milliseconds: 380),
                              pageBuilder: (_, animation, __) =>
                                  const RegisterPage(),
                              transitionsBuilder: (_, animation, __, child) {
                                final slide = Tween(
                                        begin: const Offset(1, 0), end: Offset.zero)
                                    .chain(CurveTween(curve: Curves.easeOutCubic))
                                    .animate(animation);
                                return SlideTransition(
                                  position: slide,
                                  child: FadeTransition(
                                      opacity: animation, child: child),
                                );
                              },
                            ),
                          );
                        },
                        child: const Text('إنشاء حساب جديد'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // شريط الميزات الأربع/الخمس — أيقونات فقط مع تسمية قصيرة،
                  // يختلف عدده ومحتواه حسب الطراز الحالي مطابقةً لتصميمه.
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 18,
                    runSpacing: 12,
                    children: [
                      for (final f in style.features)
                        SizedBox(
                          width: 68,
                          child: Column(
                            children: [
                              Icon(f.$1, color: p.accentBright, size: 20),
                              const SizedBox(height: 4),
                              Text(f.$2,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: p.textSecondary, fontSize: 9.5)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
