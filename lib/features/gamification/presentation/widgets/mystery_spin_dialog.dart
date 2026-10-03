import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/gamification_repository.dart';

/// ميزة 8 من القائمة الإضافية: عجلة حظ يومية — عنصر مرح وترقّب
/// يشجّع فتح التطبيق يوميًا (بالإضافة لمكافأة الدخول اليومي
/// العادية)، بمكافأة نقاط عشوائية كل 24 ساعة.
class MysterySpinDialog extends StatefulWidget {
  final String uid;
  const MysterySpinDialog({super.key, required this.uid});

  static Future<void> show(BuildContext context, String uid) {
    return showDialog(
      context: context,
      builder: (_) => MysterySpinDialog(uid: uid),
    );
  }

  @override
  State<MysterySpinDialog> createState() => _MysterySpinDialogState();
}

class _MysterySpinDialogState extends State<MysterySpinDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _spinning = false;
  int? _reward;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    setState(() {
      _spinning = true;
      _error = null;
    });

    _controller.forward(from: 0);
    final result =
        await sl<GamificationRepository>().spinMysteryBox(widget.uid);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _spinning = false;
        _error = failure.message;
      }),
      (reward) => setState(() {
        _spinning = false;
        _reward = reward;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Dialog(
      backgroundColor: p.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('عجلة الحظ اليومية 🎡',
                style: TextStyle(
                    color: p.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Transform.rotate(
                  angle: _controller.value * 2 * pi * 4,
                  child: Icon(Icons.donut_large, size: 90, color: p.accent),
                );
              },
            ),
            const SizedBox(height: 20),
            if (_reward != null)
              Text('🎉 ربحت $_reward نقطة!',
                  style: TextStyle(
                      color: p.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 16))
            else if (_error != null)
              Text(_error!,
                  style: TextStyle(color: p.error), textAlign: TextAlign.center)
            else
              Text('جرّب حظك واربح نقاطًا مجانية!',
                  style: TextStyle(color: p.textSecondary)),
            const SizedBox(height: 20),
            if (_reward == null)
              ElevatedButton(
                onPressed: _spinning ? null : _spin,
                child: Text(_spinning ? 'جارٍ التدوير...' : 'دوّر الآن'),
              )
            else
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }
}
