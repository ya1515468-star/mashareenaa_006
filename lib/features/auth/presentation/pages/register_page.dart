import 'dart:async';
import '../../../../core/services/snack_sfx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/local_session_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/usecases/check_username_available_usecase.dart';
import '../../domain/usecases/create_username_pin_usecase.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium/effects.dart';
import '../widgets/premium/password_widgets.dart';
import '../widgets/premium/premium_auth_scaffold.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/brand_animated_logo.dart';
import '../widgets/premium/premium_text_field.dart';
import '../widgets/premium/theme_picker_sheet.dart';
import '../widgets/premium/two_factor_prompt.dart';
import 'email_verification_code_page.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

enum _UsernameStatus { idle, checking, available, taken, invalid }

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  final _referralController = TextEditingController();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _localSession = LocalSessionService();

  bool _passwordFocused = false;
  bool _enableQuickPin = true;
  bool _wants2FA = false;
  bool _submitting = false;
  _UsernameStatus _usernameStatus = _UsernameStatus.idle;
  Timer? _usernameDebounce;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _usernameController.dispose();
    _pinController.dispose();
    _nameDebounce?.cancel();
    _referralController.dispose();
    super.dispose();
  }

  // الاسم الظاهر يجب ألا يتكرر: فحص حيّ على الخادم (is_name_available) مع تأخير.
  bool _nameChecking = false;
  bool? _nameTaken;
  Timer? _nameDebounce;

  void _onNameChanged(String value) {
    _nameDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() { _nameChecking = false; _nameTaken = null; });
      return;
    }
    setState(() => _nameChecking = true);
    _nameDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final ok = await Supabase.instance.client.rpc('is_name_available',
            params: {'p_name': value.trim(), 'p_kind': 'display'});
        if (mounted) setState(() { _nameChecking = false; _nameTaken = ok != true; });
      } catch (_) {
        if (mounted) setState(() { _nameChecking = false; _nameTaken = null; });
      }
    });
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _usernameStatus = _UsernameStatus.idle);
      return;
    }
    setState(() => _usernameStatus = _UsernameStatus.checking);
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final useCase = sl<CheckUsernameAvailableUseCase>();
      final result = await useCase(value.trim());
      if (!mounted) return;
      result.fold(
        (failure) => setState(() => _usernameStatus = _UsernameStatus.invalid),
        (available) => setState(
          () => _usernameStatus =
              available ? _UsernameStatus.available : _UsernameStatus.taken,
        ),
      );
    });
  }

  String? _usernameHintText() {
    switch (_usernameStatus) {
      case _UsernameStatus.checking:
        return 'جارٍ التحقق من التوفر...';
      case _UsernameStatus.available:
        return 'اسم المستخدم متاح ✓';
      case _UsernameStatus.taken:
        return 'اسم المستخدم محجوز، جرّب اسمًا آخر';
      case _UsernameStatus.invalid:
        return 'اسم مستخدم غير صالح';
      case _UsernameStatus.idle:
        return null;
    }
  }

  Color _usernameHintColor(dynamic p) {
    switch (_usernameStatus) {
      case _UsernameStatus.available:
        return p.success;
      case _UsernameStatus.taken:
      case _UsernameStatus.invalid:
        return p.error;
      default:
        return p.textMuted;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    if (_usernameController.text.trim().isNotEmpty &&
        _usernameStatus != _UsernameStatus.available) {
      _shakeKey.currentState?.shake();
      ScaffoldMessenger.of(context).showSnackBarSfx(
        const SnackBar(
            content: Text('الرجاء اختيار اسم مستخدم متاح، أو تركه فارغًا')),
      );
      return;
    }

    setState(() => _submitting = true);

    final signedUp = await ref.read(authControllerProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );

    if (!signedUp) {
      setState(() => _submitting = false);
      _shakeKey.currentState?.shake();
      if (mounted) {
        final error = ref.read(authControllerProvider);
        final raw = error.error?.toString().toLowerCase() ?? '';
        final message = raw.contains('confirm') || raw.contains('email') || raw.contains('تأكيد البريد')
            ? 'يرجى تأكيد البريد الإلكتروني ثم المحاولة مرة أخرى.'
            : 'تعذر إنشاء الحساب الآن. تحقق من البيانات والاتصال ثم أعد المحاولة.';
        ScaffoldMessenger.of(context).showSnackBarSfx(
          SnackBar(content: Text(message)),
        );
      }
      return;
    }

    final user = ref.read(authControllerProvider).value;
    final uid = user?.uid;

    // اسم المستخدم + PIN اختياريان — فشلهما لا يوقف إتمام التسجيل.
    if (uid != null &&
        _usernameController.text.trim().isNotEmpty &&
        _pinController.text.isNotEmpty) {
      final createUseCase = sl<CreateUsernamePinUseCase>();
      final result = await createUseCase(
        CreateUsernamePinParams(
          uid: uid,
          username: _usernameController.text.trim(),
          pin: _pinController.text.trim(),
        ),
      );
      final created = result.fold((_) => false, (_) => true);
      if (created && _enableQuickPin) {
        await _localSession.enableQuickPinFor(uid);
      }
    }

    setState(() => _submitting = false);
    if (!mounted || uid == null) return;

    // عندما تكون Confirm Email مفعلة في Supabase، signUp يعيد المستخدم
    // بدون Session. لا نحاول تنفيذ RPC محمي من دون جلسة؛ ننتقل لشاشة
    // تأكيد البريد التي تستخدم آلية Supabase الرسمية لإعادة الإرسال.
    if (Supabase.instance.client.auth.currentSession == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailVerificationCodePage(
            uid: uid,
            email: _emailController.text.trim(),
            referralUsername: _referralController.text.trim(),
          ),
        ),
      );
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isLoading = _submitting;

    return PremiumAuthScaffold(
      topRight: IconButton(
        icon: Icon(Icons.palette_outlined, color: p.accent),
        tooltip: 'اختر ثيمك الفاخر',
        onPressed: () => ThemePickerSheet.show(context),
      ),
      child: ShakeWidget(
        key: _shakeKey,
        child: Form(
          key: _formKey,
          child: StaggeredEntrance(
            children: [
              // لم يكن لصفحة إنشاء الحساب أي شعار إطلاقاً، فقط أيقونة عامة —
              // الآن نفس الشعار المتحرك المستعمل في شاشة الدخول، فتبقى
              // الهوية موحّدة بين الشاشتين.
              const Center(child: BrandAnimatedLogo(size: 92)),
              const SizedBox(height: 10),
              Text(
                'إنشاء حساب جديد',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary),
              ),
              const SizedBox(height: 22),
              PremiumTextField(
                controller: _nameController,
                label: 'الاسم الكامل',
                prefixIcon: Icons.badge_outlined,
                onChanged: _onNameChanged,
                suffixWidget: _nameChecking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : _nameTaken == null
                        ? null
                        : Icon(_nameTaken! ? Icons.cancel : Icons.check_circle,
                            size: 18, color: _nameTaken! ? p.error : const Color(0xFF22C55E)),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'الرجاء إدخال الاسم';
                  if (_nameTaken == true) return 'هذا الاسم مستخدم، اختر اسمًا آخر';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              PremiumTextField(
                controller: _emailController,
                label: 'البريد الإلكتروني',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'الرجاء إدخال البريد الإلكتروني';
                  }
                  if (!v.contains('@')) {
                    return 'صيغة البريد الإلكتروني غير صحيحة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Focus(
                onFocusChange: (focused) =>
                    setState(() => _passwordFocused = focused),
                child: PremiumTextField(
                  controller: _passwordController,
                  label: 'كلمة المرور',
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  validator: (v) {
                    if (v == null ||
                        v.length < AppValidation.minPasswordLength) {
                      return 'كلمة المرور قصيرة جدًا';
                    }
                    return null;
                  },
                ),
              ),
              PasswordStrengthPanel(
                password: _passwordController.text,
                visible:
                    _passwordFocused || _passwordController.text.isNotEmpty,
              ),
              const SizedBox(height: 14),
              PremiumTextField(
                controller: _confirmController,
                label: 'تأكيد كلمة المرور',
                obscureText: true,
                prefixIcon: Icons.lock_reset_outlined,
                validator: (v) {
                  if (v != _passwordController.text) {
                    return 'كلمتا المرور غير متطابقتين';
                  }
                  return null;
                },
              ),
              PasswordMatchIndicator(
                password: _passwordController.text,
                confirmPassword: _confirmController.text,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(child: Divider(color: p.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'اختياري: هوية سريعة',
                      style: TextStyle(color: p.textMuted, fontSize: 11.5),
                    ),
                  ),
                  Expanded(child: Divider(color: p.divider)),
                ],
              ),
              const SizedBox(height: 12),
              PremiumTextField(
                controller: _usernameController,
                label: 'اسم المستخدم (اختياري)',
                prefixIcon: Icons.alternate_email,
                onChanged: _onUsernameChanged,
                suffixWidget: _usernameStatus == _UsernameStatus.checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              if (_usernameHintText() != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 4),
                  child: Text(
                    _usernameHintText()!,
                    style:
                        TextStyle(fontSize: 12, color: _usernameHintColor(p)),
                  ),
                ),
              const SizedBox(height: 14),
              PremiumTextField(
                controller: _pinController,
                label: 'رمز PIN (${AppValidation.pinLength} خانات)',
                obscureText: true,
                prefixIcon: Icons.pin_outlined,
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  if (v.length != AppValidation.pinLength) {
                    return 'رمز PIN يجب أن يكون ${AppValidation.pinLength} خانات بالضبط';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              PremiumTextField(
                controller: _referralController,
                label: 'كود دعوة (اختياري)',
                prefixIcon: Icons.card_giftcard_outlined,
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => setState(() => _enableQuickPin = !_enableQuickPin),
                child: Row(
                  children: [
                    Checkbox(
                      value: _enableQuickPin,
                      onChanged: (v) =>
                          setState(() => _enableQuickPin = v ?? true),
                      activeColor: p.accent,
                    ),
                    Expanded(
                      child: Text(
                        'تفعيل قفل PIN السريع على هذا الجهاز',
                        style:
                            TextStyle(color: p.textSecondary, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TwoFactorPrompt(
                  value: _wants2FA,
                  onChanged: (v) => setState(() => _wants2FA = v)),
              const SizedBox(height: 24),
              PremiumButton(
                  label: 'إنشاء الحساب',
                  isLoading: isLoading,
                  onPressed: _submit),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('لديك حساب بالفعل؟',
                      style: TextStyle(color: p.textSecondary)),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('تسجيل الدخول'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
