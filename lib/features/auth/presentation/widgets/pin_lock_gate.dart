import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/local_session_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/usecases/verify_pin_usecase.dart';
import 'premium/effects.dart';
import 'premium/premium_button.dart';
import 'premium/premium_text_field.dart';

/// يلفّ الشاشة الرئيسية (HomeShell): إن كان المستخدم قد فعّل "قفل
/// PIN السريع" على هذا الجهاز مسبقًا، يُطلب منه إدخال الـ PIN أولًا
/// (حتى لو كانت جلسة Supabase Auth محفوظة تلقائيًا) قبل عرض
/// المحتوى. التحقق يتم عبر [VerifyPinUseCase] (مقابل طبقة بيانات Supabase) —
/// وهذا يمنح طبقة أمان محلية إضافية دون التأثير على منطق المصادقة
/// الأساسي في AuthController.
class PinLockGate extends StatefulWidget {
  final String uid;
  final Widget child;

  const PinLockGate({super.key, required this.uid, required this.child});

  @override
  State<PinLockGate> createState() => _PinLockGateState();
}

class _PinLockGateState extends State<PinLockGate> {
  final _localSession = LocalSessionService();
  bool _checked = false;
  bool _locked = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  Future<void> _checkLock() async {
    final hasPin = await _localSession.hasQuickPinFor(widget.uid);
    if (mounted) {
      setState(() {
        _locked = hasPin;
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const SizedBox.shrink();
    if (!_locked || _unlocked) return widget.child;
    return _PinUnlockScreen(
      uid: widget.uid,
      onUnlocked: () => setState(() => _unlocked = true),
    );
  }
}

class _PinUnlockScreen extends ConsumerStatefulWidget {
  final String uid;
  final VoidCallback onUnlocked;
  const _PinUnlockScreen({required this.uid, required this.onUnlocked});

  @override
  ConsumerState<_PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends ConsumerState<_PinUnlockScreen> {
  final _pinController = TextEditingController();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final useCase = sl<VerifyPinUseCase>();
    final result =
        await useCase(uid: widget.uid, pin: _pinController.text.trim());

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _loading = false;
          _error = failure.message;
        });
        _shakeKey.currentState?.shake();
      },
      (verified) {
        setState(() => _loading = false);
        if (verified) {
          widget.onUnlocked();
        } else {
          setState(() => _error = 'رمز PIN غير صحيح');
          _shakeKey.currentState?.shake();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          const Positioned.fill(child: FloatingGoldDust()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ShakeWidget(
                key: _shakeKey,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 48, color: p.accent),
                      const SizedBox(height: 12),
                      Text(
                        'أدخل رمز PIN لفتح التطبيق',
                        style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      PremiumTextField(
                        controller: _pinController,
                        label: 'رمز PIN',
                        obscureText: true,
                        prefixIcon: Icons.pin_outlined,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: TextStyle(color: p.error, fontSize: 12.5)),
                      ],
                      const SizedBox(height: 18),
                      PremiumButton(
                          label: 'فتح',
                          isLoading: _loading,
                          onPressed: _unlock),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
