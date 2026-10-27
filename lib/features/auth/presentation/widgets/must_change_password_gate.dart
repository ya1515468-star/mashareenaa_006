import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';

/// بوّابة تغيير الكلمة المؤقّتة.
///
/// حين تُعاد كلمة مرور عضو بكلمة مؤقّتة، يعرفها المُنفِّذ أيضًا. فلو
/// دخل العضو وتُركت كما هي لبقي حسابه مفتوحًا لمن يحفظها. الخادم يضع
/// علامة must_change_password، وهذه البوّابة تحجب التطبيق حتى تُغيَّر.
///
/// لا زرّ تخطٍّ ولا رجوع: التخطّي يُفرغ الإجراء من معناه. والخروج متاح
/// لمن لا يريد المتابعة.
class MustChangePasswordGate extends ConsumerStatefulWidget {
  const MustChangePasswordGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MustChangePasswordGate> createState() =>
      _MustChangePasswordGateState();
}

class _MustChangePasswordGateState
    extends ConsumerState<MustChangePasswordGate> {
  bool? _must;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    try {
      final raw = await Supabase.instance.client
          .rpc('do_i_must_change_password');
      if (mounted) setState(() => _must = raw == true);
    } catch (_) {
      // تعذّر الفحص لا يحجب التطبيق: عطل شبكة يجب ألّا يمنع الدخول.
      if (mounted) setState(() => _must = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_must != true) return widget.child;
    return _ChangePasswordScreen(onDone: () {
      if (mounted) setState(() => _must = false);
    });
  }
}

class _ChangePasswordScreen extends ConsumerStatefulWidget {
  const _ChangePasswordScreen({required this.onDone});
  final VoidCallback onDone;

  @override
  ConsumerState<_ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState
    extends ConsumerState<_ChangePasswordScreen> {
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = _pwd.text;
    if (p.length < 8) {
      setState(() => _error = 'الكلمة الجديدة 8 أحرف على الأقل');
      return;
    }
    if (p != _confirm.text) {
      setState(() => _error = 'الكلمتان غير متطابقتين');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final err =
          await ref.read(authControllerProvider.notifier).updatePassword(p);
      if (err != null) throw err;
      // لا تُرفَع العلامة إلّا بعد نجاح التغيير فعلًا: رفعها قبله يترك
      // الحساب على كلمة يعرفها غير صاحبه بلا أي تنبيه.
      await Supabase.instance.client.rpc('clear_my_must_change_password');
      if (!mounted) return;
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم تغيير كلمة المرور ✓'),
        backgroundColor: Color(0xFF16A34A),
      ));
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر التغيير: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(26),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🔐', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 14),
                  Text('اختر كلمة مرور جديدة',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                    'دخلتَ بكلمة مؤقّتة أعدّتها الإدارة. اختر الآن كلمة '
                    'يعرفها أنت وحدك.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, height: 1.7),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _pwd,
                    obscureText: _hidden,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _hidden = !_hidden),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: _hidden,
                    decoration: const InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Text('حفظ ومتابعة'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => ref
                            .read(authControllerProvider.notifier)
                            .signOut(),
                    child: const Text('تسجيل الخروج'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
