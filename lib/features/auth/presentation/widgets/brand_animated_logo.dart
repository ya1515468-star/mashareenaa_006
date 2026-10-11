import 'dart:math' as math;

import 'package:flutter/material.dart';

/// شعار "مشاريعنا" المتحرك: رجل يعمل على ماكينة خياطة زوجية الإبرة، مرسوم
/// برمجيًا بنفس هندسة أيقونة التطبيق: الإبرتان تصعدان وتهبطان، عجلة الماكينة
/// تدور، والذراع تتبع الحركة، مع هالة ذهبية خفيفة.
class BrandAnimatedLogo extends StatefulWidget {
  final double size;
  const BrandAnimatedLogo({super.key, this.size = 112});

  @override
  State<BrandAnimatedLogo> createState() => _BrandAnimatedLogoState();
}

class _BrandAnimatedLogoState extends State<BrandAnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 1.4,
      height: s * 1.4,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(painter: SewingManPainter(_ctrl.value)),
      ),
    );
  }
}

/// يرسم المشهد على مربع 100×100 مُكبَّر إلى حجم اللوحة.
class SewingManPainter extends CustomPainter {
  final double t; // 0..1 دورة كاملة
  SewingManPainter(this.t);

  static const _gold = Color(0xFFD4AF37);
  static const _gold2 = Color(0xFFFFD700);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100.0;
    final needle = math.sin(t * 2 * math.pi * 3); // ثلاث غرزات بالدورة
    final wheel = t * 2 * math.pi * 3;
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);

    final fill = Paint()..style = PaintingStyle.fill;
    void rr(double x0, double y0, double x1, double y1, Color c, [double r = 0]) {
      fill.color = c;
      canvas.drawRRect(
          RRect.fromLTRBR(x0 * k, y0 * k, x1 * k, y1 * k, Radius.circular(r * k)), fill);
    }

    void circ(double x, double y, double r, Color c) {
      fill.color = c;
      canvas.drawCircle(Offset(x * k, y * k), r * k, fill);
    }

    void line(double x0, double y0, double x1, double y1, double w, Color c) {
      final p = Paint()
        ..color = c
        ..strokeWidth = w * k
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x0 * k, y0 * k), Offset(x1 * k, y1 * k), p);
    }

    // خلفية دائرية داكنة وهالة ذهبية نابضة
    circ(50, 50, 48, const Color(0xFF1A1208));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = _gold.withValues(alpha: .55 + .4 * pulse)
      ..strokeWidth = 2.2 * k;
    canvas.drawCircle(Offset(50 * k, 50 * k), 47 * k, ring);

    canvas.save();
    canvas.translate(10 * k, 12 * k);
    canvas.scale(0.8);

    // طاولة وكرسي
    rr(10, 68, 90, 72, const Color(0xFF784E1E), 1.5);
    line(16, 72, 16, 90, 3.5, const Color(0xFF5A3A16));
    line(84, 72, 84, 90, 3.5, const Color(0xFF5A3A16));
    rr(8, 64, 28, 67, const Color(0xFF966428), 1.5);
    line(10, 67, 10, 88, 3, const Color(0xFF5A3A16));

    // الساقان والحذاء
    line(22, 63, 36, 63, 7, const Color(0xFF1E293B));
    line(36, 63, 38, 84, 6, const Color(0xFF1E293B));
    line(38, 84, 44, 86, 4, const Color(0xFF141414));

    // الجذع والرأس
    rr(14, 42, 30, 64, const Color(0xFF3B82F6), 5);
    circ(25, 33, 7.5, const Color(0xFFF1C27D));
    fill.color = const Color(0xFF3C2814);
    canvas.drawArc(
        Rect.fromLTRB(17.2 * k, 24.8 * k, 32.8 * k, 40.4 * k), math.pi, math.pi, true, fill);
    circ(28.5, 33, 0.9, const Color(0xFF281C0C));

    // جسم الماكينة
    rr(42, 52, 80, 66, _gold, 2);
    rr(42, 38, 56, 66, _gold, 3);
    rr(42, 38, 82, 48, _gold2, 3);
    rr(60, 54, 78, 58, const Color(0xFF96781E), 1);
    circ(70, 35, 3.2, const Color(0xFFDC323C));

    // الإبرتان (زوجية) تتحركان للأعلى والأسفل
    final ny = needle * 3.2;
    for (final nx in [46.0, 51.0]) {
      line(nx, 48 + ny, nx, 60 + ny, 1.1, const Color(0xFFEBEBF0));
    }
    line(46, 48, 70, 35, 0.5, const Color(0xCCFFFFFF));
    rr(42, 64, 66, 67, const Color(0xFFC8C8CD), 1);

    // العجلة تدور
    const wx = 86.0, wy = 46.0;
    circ(wx, wy, 6.5, const Color(0xFFB48C1E));
    circ(wx, wy, 4.6, const Color(0xFF1E160A));
    for (var i = 0; i < 3; i++) {
      final a = wheel + i * 2 * math.pi / 3;
      line(wx, wy, wx + 4.3 * math.cos(a), wy + 4.3 * math.sin(a), 1.3, _gold2);
    }
    circ(wx, wy, 1.2, _gold2);

    // الذراع واليد تتبعان الإبرة
    line(27, 47, 42, 57 + needle, 4.5, const Color(0xFF3B82F6));
    circ(43, 58 + needle, 2.4, const Color(0xFFF1C27D));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SewingManPainter old) => old.t != t;
}
