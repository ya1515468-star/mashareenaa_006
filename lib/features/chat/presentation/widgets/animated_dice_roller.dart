import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// يرسم وجه نرد حقيقي بترتيب النقاط الكلاسيكي (لا رموز يونيكود ثابتة):
/// نمط كل رقم من 1 إلى 6 مطابق تماماً لترتيب النرد الفعلي.
class _DiceFace extends StatelessWidget {
  final int value; // 1..6
  final double size;
  const _DiceFace({required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F0E0),
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFD9C9A3), width: size * 0.02),
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: CustomPaint(painter: _PipsPainter(value: value)),
    );
  }
}

/// مواضع النقاط القياسية لكل وجه (شبكة 3×3: 0,0 أعلى يسار .. 2,2 أسفل يمين).
const Map<int, List<List<int>>> _pipLayout = {
  1: [[1, 1]],
  2: [[0, 0], [2, 2]],
  3: [[0, 0], [1, 1], [2, 2]],
  4: [[0, 0], [0, 2], [2, 0], [2, 2]],
  5: [[0, 0], [0, 2], [1, 1], [2, 0], [2, 2]],
  6: [[0, 0], [0, 2], [1, 0], [1, 2], [2, 0], [2, 2]],
};

class _PipsPainter extends CustomPainter {
  final int value;
  _PipsPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final cells = _pipLayout[value.clamp(1, 6)]!;
    final cell = size.width / 3;
    final r = cell * 0.26;
    final paint = Paint()..color = const Color(0xFF241536);
    for (final c in cells) {
      final cx = cell * c[1] + cell / 2;
      final cy = cell * c[0] + cell / 2;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PipsPainter old) => old.value != value;
}

/// حوار رمي نرد متحرك: يعرض مكعباً حقيقياً يتقلّب بسرعة بين الوجوه
/// (محاكاة دحرجة فعلية)، ثم يستقر على النتيجة المطابقة حرفياً لِما سيُرسَل
/// فعلياً في الرسالة — لا يمكن أن يظهر رقم ويُرسَل رقم آخر، لأن النتيجة
/// النهائية هي نفسها القيمة المُمرَّرة أصلاً قبل بدء الحركة.
class AnimatedDiceRoller extends StatefulWidget {
  final int result; // 1..6 — القيمة التي استقرّ عليها الاتفاق مسبقًا
  const AnimatedDiceRoller({super.key, required this.result});

  /// يعرض الحوار، ينتظر انتهاء حركة الدحرجة، ثم يُغلق تلقائيًا.
  static Future<void> show(BuildContext context, int result) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: false,
      builder: (_) => AnimatedDiceRoller(result: result),
    );
  }

  @override
  State<AnimatedDiceRoller> createState() => _AnimatedDiceRollerState();
}

class _AnimatedDiceRollerState extends State<AnimatedDiceRoller>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _displayValue = 1;
  Timer? _faceTimer;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    final rnd = math.Random();
    // أثناء الدحرجة تُعرض وجوه عشوائية متسارعة التباطؤ (محاكاة تمايل
    // النرد الحقيقي)، وتُستبدَل بالنتيجة الحقيقية حصراً في اللحظة
    // الأخيرة — لا احتمال انحراف بين ما يُعرض وما يُرسَل.
    var delay = 60;
    void tick() {
      if (!mounted) return;
      setState(() => _displayValue = 1 + rnd.nextInt(6));
      delay = (delay * 1.18).round();
      if (delay < 650) {
        _faceTimer = Timer(Duration(milliseconds: delay), tick);
      } else {
        setState(() {
          _displayValue = widget.result;
          _settled = true;
        });
      }
    }

    tick();
    _ctrl.forward();
    Timer(const Duration(milliseconds: 1300), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _faceTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          // دوران وتذبذب حجم يحاكي ارتطام المكعب أثناء الدحرجة، يهدأ
          // تماماً عند الاستقرار على النتيجة.
          final t = _ctrl.value;
          final wobble = _settled ? 0.0 : math.sin(t * math.pi * 10) * 0.12;
          final scale = _settled ? 1.0 : 0.92 + math.sin(t * math.pi * 6).abs() * 0.08;
          return Transform.rotate(
            angle: wobble,
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: _DiceFace(value: _displayValue, size: 120),
      ),
    );
  }
}
