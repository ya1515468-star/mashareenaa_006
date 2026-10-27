import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/auth_otp.dart';
import '../../../../core/services/snack_sfx.dart';

/// إعادة تعيين كلمة المرور برمز يصل بالبريد.
///
/// لماذا الرمز وكلمة المرور في خطوة واحدة:
/// `verifyOTP(type: recovery)` يُنشئ **جلسة فعلية** فور نجاحه. لو فصلنا
/// الخطوتين لبقي المستخدم مسجّل الدخول في الفترة بين إدخال الرمز وضبط
/// كلمة المرور — وقد يغادر الشاشة فيدخل التطبيق دون أن يُعيد التعيين
/// أصلًا. هنا تُجمع الخطوتان: يُتحقّق من الرمز ثم تُضبط كلمة المرور فورًا،
/// ثم **يُسجَّل خروج** كي يدخل بكلمته الجديدة. فلا تبقى أي نافذة مفتوحة.
///
/// العطل الذي يعالجه هذا الملف: لم يكن في التطبيق أي شاشة لإعادة التعيين.
/// كان الرابط يفتح التطبيق فيُنشئ جلسة استعادة ويدخل المستخدم إلى الشات
/// دون أن يُطلب منه تغيير كلمة المرور إطلاقًا.
class ResetPasswordCodePage extends StatefulWidget {
  final String email;
  const ResetPasswordCodePage({super.key, required this.email});

  @override
  State<ResetPasswordCodePage> createState() => _ResetPasswordCodePageState();
}

class _ResetPasswordCodePageState extends State<ResetPasswordCodePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  late DateTime _sentAt;
  Timer? _ticker;
  Duration _left = AuthOtp.validity;

  bool _canResend = false;
  int _resendIn = AuthOtp.resendCooldown.inSeconds;

  @override
  void initState() {
    super.initState();
    _sentAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _left = AuthOtp.validity - DateTime.now().difference(_sentAt);
        if (_resendIn > 0) {
          _resendIn--;
        } else {
          _canResend = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _expired => _left.isNegative || _left == Duration.zero;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expired) {
      setState(() => _error = 'انتهت صلاحية الرمز. اطلب رمزًا جديدًا.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      // ① الرمز ⇒ جلسة استعادة قصيرة العمر.
      await auth.verifyOTP(
        type: OtpType.recovery,
        email: widget.email,
        token: _codeCtrl.text.trim(),
      );
      // ② ضبط كلمة المرور فورًا داخل الجلسة نفسها.
      await auth.updateUser(UserAttributes(password: _passCtrl.text));
      // ③ خروج كي لا يبقى الدخول قائمًا بجلسة الاستعادة.
      await auth.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
        const SnackBar(
          content: Text('تم تغيير كلمة المرور ✓ سجّل الدخول بكلمتك الجديدة.'),
        ),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (m.contains('expired')) {
          _error = 'انتهت صلاحية الرمز. اطلب رمزًا جديدًا.';
        } else if (m.contains('invalid') || m.contains('token')) {
          _error = 'الرمز غير صحيح. تأكّد من الأرقام الستة.';
        } else if (m.contains('rate') || m.contains('after')) {
          _error = 'تجاوزت حدّ المحاولات. انتظر دقيقة ثم أعد المحاولة.';
        } else if (m.contains('should be different') ||
            m.contains('same as the old')) {
          _error = 'كلمة المرور الجديدة يجب أن تختلف عن القديمة.';
        } else {
          _error = e.message;
        }
      });
      // جلسة الاستعادة قد تكون أُنشئت قبل فشل ضبط كلمة المرور.
      try {
        await auth.signOut();
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذّر إكمال العملية: $e';
      });
    }
  }

  Future<void> _resend() async {
    if (!_canResend || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .resetPasswordForEmail(widget.email.trim());
      if (!mounted) return;
      setState(() {
        _sentAt = DateTime.now();
        _left = AuthOtp.validity;
        _canResend = false;
        _resendIn = AuthOtp.resendCooldown.inSeconds;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBarSfx(
        const SnackBar(content: Text('أُرسل رمز جديد إلى بريدك.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final m = e.message.toLowerCase();
      setState(() {
        _busy = false;
        _error = (m.contains('rate') || m.contains('after'))
            ? 'تجاوزت حدّ إرسال الرسائل. انتظر دقيقة ثم أعد المحاولة.'
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذّرت إعادة الإرسال: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعادة تعيين كلمة المرور')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'أرسلنا رمزًا من 6 أرقام إلى:\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  _expired
                      ? '⏳ انتهت صلاحية الرمز — اطلب رمزًا جديدًا'
                      : '⏳ صالح لمدة ${AuthOtp.countdown(_left)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _expired ? Colors.redAccent : Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 10,
                  style: const TextStyle(
                      fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    labelText: 'رمز إعادة التعيين',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'أدخل الرمز المرسل إلى بريدك';
                    if (!RegExp(r'^\d{6,10}$').hasMatch(s)) {
                      return 'الرمز أرقام فقط (6 خانات)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    final s = v ?? '';
                    if (s.length < 8) {
                      return 'كلمة المرور 8 أحرف على الأقل';
                    }
                    if (!RegExp(r'[A-Za-z]').hasMatch(s) ||
                        !RegExp(r'\d').hasMatch(s)) {
                      return 'اجمع بين أحرف وأرقام';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == _passCtrl.text ? null : 'كلمتا المرور غير متطابقتين',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('تعيين كلمة المرور'),
                ),
                const SizedBox(height: 10),
                Center(
                  child: _canResend
                      ? TextButton(
                          onPressed: _busy ? null : _resend,
                          child: const Text('إعادة إرسال الرمز'),
                        )
                      : Text('إعادة الإرسال بعد $_resendIn ثانية',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
