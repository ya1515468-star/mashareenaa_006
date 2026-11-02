import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/auth_otp.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/check_username_available_usecase.dart';
import '../../domain/usecases/create_username_pin_usecase.dart';
import '../../../../core/services/snack_sfx.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/guest_auth_service.dart';
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../widgets/premium/premium_button.dart';

enum _Step { email, code, password, username, done }

/// ترقية حساب الزائر إلى حساب دائم ببريد مؤكَّد.
///
/// ثلاث خطوات بترتيب فرضه Supabase لا نحن: البريد أولًا، ثم رمز
/// التأكيد، و**بعدهما** كلمة المرور — فكلمة مرور الزائر لا تُقبل قبل
/// تأكيد بريده.
///
/// المعرّف `auth.uid()` لا يتغيّر في أي خطوة، فرسائله ونقاطه وأصدقاؤه
/// وكل ما جمعه كزائر يبقى معه. لا نقل بيانات ولا هجرة.
class GuestUpgradePage extends ConsumerStatefulWidget {
  const GuestUpgradePage({super.key});

  static Future<bool> open(BuildContext context) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const GuestUpgradePage()),
    );
    return done ?? false;
  }

  @override
  ConsumerState<GuestUpgradePage> createState() => _GuestUpgradePageState();
}

class _GuestUpgradePageState extends ConsumerState<GuestUpgradePage> {
  final _service = GuestAuthService();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();

  /// null = لم يُفحَص بعد، true = متاح، false = مأخوذ أو غير صالح.
  bool? _usernameAvailable;
  Timer? _usernameDebounce;

  _Step _step = _Step.email;
  bool _busy = false;
  String? _error;

  /// البريد يخصّ حسابًا آخر — يُعرض الخياران ولا نقرّر عنه.
  bool _emailTaken = false;

  Timer? _cooldownTimer;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _usernameDebounce?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsLeft = AuthOtp.resendCooldown.inSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on GuestAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر إتمام العملية، حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmail() => _run(() async {
        final outcome = await _service.startUpgrade(_emailController.text);
        if (!mounted) return;
        if (outcome == GuestUpgradeOutcome.emailBelongsToAnotherAccount) {
          setState(() => _emailTaken = true);
          return;
        }
        setState(() {
          _emailTaken = false;
          _step = _Step.code;
        });
        _startCooldown();
      });

  Future<void> _submitCode() => _run(() async {
        await _service.confirmUpgradeCode(
          email: _emailController.text,
          code: _codeController.text,
        );
        final upgraded = await _service.refreshAndCheckUpgraded();
        if (!mounted) return;
        if (!upgraded) {
          setState(() => _error = 'لم يكتمل التأكيد بعد، أعد المحاولة.');
          return;
        }
        // القيود تُرفع فور التأكيد بلا إعادة تشغيل.
        ref.invalidate(guestStateProvider);
        ref.invalidate(authControllerProvider);
        setState(() => _step = _Step.password);
      });

  Future<void> _submitPassword() => _run(() async {
        await _service.setPasswordAfterUpgrade(_passwordController.text);
        if (!mounted) return;
        ref.invalidate(guestStateProvider);
        ref.invalidate(authControllerProvider);
        setState(() => _step = _Step.username);
      });

  Future<void> _resend() => _run(() async {
        await _service.resendUpgradeCode(_emailController.text);
        if (!mounted) return;
        _startCooldown();
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(content: Text('أُرسل الرمز من جديد.')),
        );
      });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تسجيل الحساب')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _StepHeader(step: _step),
              const SizedBox(height: 20),
              if (_step == _Step.email) ..._emailStep(p),
              if (_step == _Step.code) ..._codeStep(p),
              if (_step == _Step.password) ..._passwordStep(p),
              if (_step == _Step.username) ..._usernameStep(p),
              if (_step == _Step.done) ..._doneStep(p),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _emailStep(dynamic p) => [
        Text(
          'أضف بريدك ليصير حسابك دائمًا. كل ما جمعته حتى الآن — رسائلك '
          'ونقاطك وأصدقاؤك — يبقى معك كما هو.',
          style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          style: TextStyle(color: p.textPrimary),
          decoration: InputDecoration(
            labelText: 'البريد الإلكتروني',
            prefixIcon: Icon(Icons.mail_outline, color: p.textMuted),
          ),
        ),
        if (_emailTaken) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withValues(alpha: .4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('هذا البريد مسجَّل بحساب آخر.',
                        style: TextStyle(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  'إن سجّلت دخولك بذلك الحساب فستدخل إليه، و**بيانات الزائر '
                  'الحالية تُفقد نهائيًا** — رسائلك ونقاطك هنا لن تنتقل إليه. '
                  'أو استعمل بريدًا آخر ويبقى كل شيء معك.',
                  style: TextStyle(
                      color: p.textSecondary, fontSize: 12.5, height: 1.6),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    // لا نسجّل خروجه نيابةً عنه: نعيده إلى شاشة الدخول
                    // وهو يقرّر. حساب الزائر يبقى على جهازه حتى يختار.
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('سأسجّل دخولي بذلك الحساب'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => setState(() {
                    _emailTaken = false;
                    _emailController.clear();
                  }),
                  child: const Text('استعمل بريدًا آخر'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        PremiumButton(
          label: 'إرسال رمز التأكيد',
          isLoading: _busy,
          onPressed: _busy ? null : _submitEmail,
        ),
      ];

  List<Widget> _codeStep(dynamic p) => [
        Text(
          'أرسلنا رمزًا من ستّ خانات إلى ${_emailController.text.trim()}',
          style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
              color: p.textPrimary, fontSize: 22, letterSpacing: 10),
          decoration: const InputDecoration(counterText: '', hintText: '------'),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: (_secondsLeft > 0 || _busy) ? null : _resend,
            child: Text(_secondsLeft > 0
                ? 'إعادة الإرسال بعد $_secondsLeft ثانية'
                : 'إعادة إرسال الرمز'),
          ),
        ),
        const SizedBox(height: 12),
        PremiumButton(
          label: 'تأكيد',
          isLoading: _busy,
          onPressed: _busy ? null : _submitCode,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _step = _Step.email;
                    _error = null;
                  }),
          child: const Text('تعديل البريد'),
        ),
      ];

  List<Widget> _passwordStep(dynamic p) => [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: .4)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('تأكّد بريدك. بقيت خطوة واحدة.',
                  style: TextStyle(color: p.textSecondary, fontSize: 12.5)),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Text(
          'اضبط كلمة مرور لتستطيع الدخول من أي جهاز، ولتسترجع حسابك إن '
          'فقدت هذا الهاتف.',
          style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          textDirection: TextDirection.ltr,
          style: TextStyle(color: p.textPrimary),
          decoration: InputDecoration(
            labelText: 'كلمة المرور',
            prefixIcon: Icon(Icons.lock_outline, color: p.textMuted),
          ),
        ),
        const SizedBox(height: 22),
        PremiumButton(
          label: 'حفظ وإنهاء',
          isLoading: _busy,
          onPressed: _busy ? null : _submitPassword,
        ),
      ];


  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final name = value.trim();
    if (name.isEmpty) {
      setState(() => _usernameAvailable = null);
      return;
    }
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final result = await sl<CheckUsernameAvailableUseCase>()(name);
      if (!mounted) return;
      setState(() => _usernameAvailable =
          result.fold((_) => false, (available) => available));
    });
  }

  Future<void> _submitUsername() => _run(() async {
        final uid = ref.read(authControllerProvider).valueOrNull?.uid ??
            Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) {
          throw const GuestAuthException('انتهت الجلسة، أعد الدخول.');
        }
        final result = await sl<CreateUsernamePinUseCase>()(
          CreateUsernamePinParams(
            uid: uid,
            username: _usernameController.text.trim(),
            pin: _pinController.text.trim(),
          ),
        );
        final failure = result.fold<String?>((f) => f.message, (_) => null);
        if (failure != null) throw GuestAuthException(failure);
        if (!mounted) return;
        setState(() => _step = _Step.done);
      });

  List<Widget> _usernameStep(dynamic p) {
    final name = _usernameController.text.trim();
    final pinOk = _pinController.text.trim().length == AppValidation.pinLength;
    final ready = _usernameAvailable == true && pinOk;
    return [
      Text(
        'اختر اسم مستخدم فريدًا — به يجدك الآخرون، وبه ترجع إلى حسابك '
        'برمز PIN إن نسيت كلمة المرور. اختياري، وتستطيع تخطّيه الآن.',
        style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.6),
      ),
      const SizedBox(height: 18),
      TextField(
        controller: _usernameController,
        textDirection: TextDirection.ltr,
        onChanged: _onUsernameChanged,
        style: TextStyle(color: p.textPrimary),
        decoration: InputDecoration(
          labelText: 'اسم المستخدم',
          prefixIcon: Icon(Icons.alternate_email, color: p.textMuted),
          helperText: name.isEmpty
              ? 'حروف إنجليزية وأرقام و _ ، من 3 إلى 20'
              : _usernameAvailable == null
                  ? 'جارٍ التحقق…'
                  : _usernameAvailable == true
                      ? 'متاح'
                      : 'غير متاح أو غير صالح',
          helperStyle: TextStyle(
            color: _usernameAvailable == true
                ? Colors.green
                : _usernameAvailable == false
                    ? Colors.redAccent
                    : p.textMuted,
          ),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _pinController,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: AppValidation.pinLength,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: p.textPrimary),
        decoration: InputDecoration(
          labelText: 'رمز PIN (${AppValidation.pinLength} خانات)',
          counterText: '',
          prefixIcon: Icon(Icons.pin_outlined, color: p.textMuted),
        ),
      ),
      const SizedBox(height: 20),
      PremiumButton(
        label: 'حفظ الاسم',
        isLoading: _busy,
        onPressed: (_busy || !ready) ? null : _submitUsername,
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy ? null : () => setState(() => _step = _Step.done),
        child: const Text('تخطّي — أكمل لاحقًا من الملف الشخصي'),
      ),
    ];
  }

  List<Widget> _doneStep(dynamic p) => [
        const SizedBox(height: 10),
        const Icon(Icons.verified_rounded, color: Colors.green, size: 64),
        const SizedBox(height: 16),
        Text('صار حسابك دائمًا',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: p.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(
          'أنت الآن عضو كامل كمن سجّل من أول تثبيت. كل ما جمعته كزائر '
          'بقي معك، وكل الميزات مفتوحة.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 26),
        PremiumButton(
          label: 'متابعة',
          isLoading: false,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ];
}

class _StepHeader extends StatelessWidget {
  final _Step step;
  const _StepHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const labels = ['البريد', 'الرمز', 'كلمة المرور', 'الاسم'];
    final index = switch (step) {
      _Step.email => 0,
      _Step.code => 1,
      _Step.password => 2,
      _Step.username => 3,
      _Step.done => 4,
    };
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= index ? p.accent : p.divider,
              ),
            ),
          Column(children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: i <= index ? p.accent : p.divider,
              child: i < index
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text('${i + 1}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white)),
            ),
            const SizedBox(height: 4),
            Text(labels[i],
                style: TextStyle(
                    color: i <= index ? p.textPrimary : p.textMuted,
                    fontSize: 11)),
          ]),
        ],
      ],
    );
  }
}
