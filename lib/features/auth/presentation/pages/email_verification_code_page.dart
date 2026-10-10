import '../../../../core/config/auth_redirect.dart';
import '../../../../core/services/snack_sfx.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../gamification/domain/usecases/apply_referral_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/premium/effects.dart';
import '../widgets/premium/premium_auth_scaffold.dart';
import '../widgets/premium/premium_button.dart';

class EmailVerificationCodePage extends ConsumerStatefulWidget {
  final String uid;
  final String email;
  final String? referralUsername;

  const EmailVerificationCodePage({
    super.key,
    required this.uid,
    required this.email,
    this.referralUsername,
  });

  @override
  ConsumerState<EmailVerificationCodePage> createState() =>
      _EmailVerificationCodePageState();
}

class _EmailVerificationCodePageState
    extends ConsumerState<EmailVerificationCodePage> {
  final _codeController = TextEditingController();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  bool _loading = false;
  String? _error;
  bool _canResend = true;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _authSub?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  StreamSubscription<AuthState>? _authSub;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // مسار الرابط: إن ضغط المستخدم رابط التأكيد فُتح التطبيق بالرابط العميق،
    // وsupabase_flutter يُتم الجلسة تلقائيًا؛ نلتقطها هنا فنكمل دون أي ضغطة.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user?.emailConfirmedAt != null) _onConfirmed();
    });
  }

  Future<void> _onConfirmed() async {
    if (_done) return;
    _done = true;
    try {
      if (widget.referralUsername != null && widget.referralUsername!.isNotEmpty) {
        await sl<ApplyReferralUseCase>().call(
          referrerUsername: widget.referralUsername!,
          newMemberUid: widget.uid,
        );
      }
    } catch (_) {/* الإحالة لا تمنع إكمال التأكيد */}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBarSfx(
      const SnackBar(content: Text('تم تأكيد بريدك الإلكتروني بنجاح! ✓')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (code.isNotEmpty) {
        // المسار الأساسي: رمز التأكيد يُكتب داخل التطبيق فلا يغادره المستخدم.
        if (!RegExp(r'^\d{6,10}$').hasMatch(code)) {
          setState(() {
            _loading = false;
            _error = 'الرمز أرقام فقط (6 خانات أو أكثر).';
          });
          _shakeKey.currentState?.shake();
          return;
        }
        await Supabase.instance.client.auth.verifyOTP(
          type: OtpType.signup,
          email: widget.email,
          token: code,
        );
        await _onConfirmed();
        return;
      }
      // بلا رمز: هل أُكّد البريد بالرابط؟ (يحتاج جلسة؛ بدونها يُطلب الرمز)
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _loading = false;
          _error = 'اكتب رمز التأكيد المرسل إلى بريدك.';
        });
        return;
      }
      final response = await Supabase.instance.client.auth.getUser();
      if (response.user?.emailConfirmedAt != null) {
        await _onConfirmed();
        return;
      }
      setState(() {
        _loading = false;
        _error = 'لم يتم تأكيد البريد بعد. اكتب الرمز المرسل إليك.';
      });
    } on AuthException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message.toLowerCase().contains('expired') || e.message.toLowerCase().contains('invalid')
            ? 'الرمز غير صحيح أو انتهت صلاحيته. اطلب رمزًا جديدًا.'
            : e.message;
      });
      _shakeKey.currentState?.shake();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'تعذّر التحقق: $e';
      });
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
        emailRedirectTo: authRedirectUrl(),
      );
      if (!mounted) return;
      setState(() {
        _canResend = false;
        _secondsLeft = 60;
      });
      while (_secondsLeft > 0) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        setState(() => _secondsLeft--);
      }
      if (mounted) setState(() => _canResend = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(content: Text('تمت إعادة إرسال رسالة التأكيد.')),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _canResend = true;
        _secondsLeft = 0;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _canResend = true;
        _secondsLeft = 0;
        _error = 'تعذّرت إعادة الإرسال: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return PremiumAuthScaffold(
      child: ShakeWidget(
        key: _shakeKey,
        child: SingleChildScrollView(
          child: StaggeredEntrance(
            children: [
              Icon(Icons.mark_email_read_outlined, size: 48, color: p.accent),
              const SizedBox(height: 12),
              Text(
                'تأكيد بريدك الإلكتروني',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'أرسلنا رمز التأكيد إلى:\n${widget.email}',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 10,
                autofocus: true,
                style: TextStyle(
                    color: p.textPrimary, fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _verify(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: p.error, fontSize: 12.5)),
              ],
              const SizedBox(height: 20),
              PremiumButton(
                  label: 'تأكيد',
                  isLoading: _loading,
                  onPressed: _verify),
              const SizedBox(height: 16),
              Center(
                child: _canResend
                    ? TextButton(
                        onPressed: _resend,
                        child: Text('إعادة إرسال الرمز',
                            style: TextStyle(color: p.accent)),
                      )
                    : Text(
                        'إعادة الإرسال في $_secondsLeft ثانية',
                        style: TextStyle(color: p.textMuted, fontSize: 12.5),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                'تعتمد عملية إنشاء الحساب على تأكيد البريد الرسمي في Supabase. إذا لم تصل الرسالة، افحص البريد غير المرغوب أو أعد الإرسال.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
