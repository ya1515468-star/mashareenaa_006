import 'dart:math' as math;

import 'package:flutter/material.dart';

/// شعار "مشاريعنا" المتحرك: إبرة وخيط ذهبي مرسومان برمجيًا (لا صورة ثابتة)،
/// بنفس هندسة أيقونة التطبيق على الهاتف تمامًا — هوية واحدة متّسقة بين
/// أيقونة النظام وشاشات الدخول. ثلاث طبقات حركة حصرية لهذا الشعار فقط:
///   ١) هالة ذهبية دوّارة خلف العلامة (دوران بطيء مستمر).
///   ٢) نبض تنفّس هادئ على العلامة كلها (تكبير/تصغير طفيف).
///   ٣) لمعة ضوئية قطرية تمر عبر الشعار كل بضع ثوانٍ (ShaderMask متحرك).
class BrandAnimatedLogo extends StatefulWidget {
  final double size;
  const BrandAnimatedLogo({super.key, this.size = 112});

  @override
  State<BrandAnimatedLogo> createState() => _BrandAnimatedLogoState();
}

class _BrandAnimatedLogoState extends State<BrandAnimatedLogo>
    with TickerProviderStateMixin {
  late final AnimationController _rotateCtrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))
        ..repeat();
  late final AnimationController _breatheCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat(reverse: true);
  // تمر اللمعة خلال أول 35% من الدورة فقط، ثم سكون حتى الدورة التالية —
  // "مرور... سكون..." وليس زحفًا مستمرًا، وهو أقرب لما تفعله التطبيقات
  // الفاخرة من لمعة متكررة بلا توقف.
  late final AnimationController _shimmerCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600))
    ..repeat();
  late final Animation<double> _shimmerProgress = CurvedAnimation(
      parent: _shimmerCtrl, curve: const Interval(0.0, 0.35, curve: Curves.easeInOutCubic));

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _breatheCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 1.55,
      height: s * 1.55,
      child: Stack(alignment: Alignment.center, children: [
        // ١) هالة ذهبية دوّارة: ثلاث أقواس متوهّجة تدور خلف العلامة.
        AnimatedBuilder(
          animation: _rotateCtrl,
          builder: (context, child) => Transform.rotate(
            angle: _rotateCtrl.value * 2 * math.pi,
            child: child,
          ),
          child: CustomPaint(
            size: Size(s * 1.55, s * 1.55),
            painter: _HaloPainter(),
          ),
        ),
        // ٢) نبض تنفّس + ٣) لمعة متحركة، على العلامة نفسها.
        AnimatedBuilder(
          animation: Listenable.merge([_breatheCtrl, _shimmerCtrl]),
          builder: (context, child) {
            final scale = 1.0 + (_breatheCtrl.value * 0.035);
            return Transform.scale(scale: scale, child: child);
          },
          child: _ShimmeringMark(size: s, shimmer: _shimmerProgress),
        ),
      ]),
    );
  }
}

class _ShimmeringMark extends StatelessWidget {
  final double size;
  final Animation<double> shimmer;
  const _ShimmeringMark({required this.size, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size(size, size),
      painter: _NeedleThreadPainter(),
    );
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, child) {
        // الشريط اللامع يتحرك قطريًا من خارج الشعار (يسار-أعلى) إلى خارجه
        // (يمين-أسفل) مرة كل دورة، فيبدو كأنه ينزلق فوق المعدن الذهبي.
        final t = shimmer.value; // 0..1 طوال الدورة (منها فترة سكون)
        final band = 0.28;
        final start = (t * (1 + band * 2)) - band;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Colors.transparent,
              Color(0x00FFFFFF),
              Color(0xCCFFFFFF),
              Color(0x00FFFFFF),
              Colors.transparent,
            ],
            stops: [
              (start - band).clamp(0.0, 1.0),
              (start - band * 0.4).clamp(0.0, 1.0),
              start.clamp(0.0, 1.0),
              (start + band * 0.4).clamp(0.0, 1.0),
              (start + band).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
      child: mark,
    );
  }
}

/// يرسم ثلاثة أقواس ذهبية متفاوتة الشفافية والسماكة — هالة ناعمة لا صاخبة.
class _HaloPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.width / 2;
    const gold = Color(0xFFFFD54F);

    void arc(double radiusFactor, double sweepDeg, double startDeg,
        double strokeW, double opacity) {
      final paint = Paint()
        ..color = gold.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      final r = maxR * radiusFactor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        paint,
      );
    }

    arc(0.97, 95, -20, 2.4, 0.55);
    arc(0.90, 60, 140, 2.0, 0.35);
    arc(0.90, 40, 260, 1.6, 0.30);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// العلامة نفسها: خلفية بطاقة بتدرّج بنفسجي (هوية التطبيق)، وإبرة وخيط
/// ذهبيان بنفس الهندسة المستعملة في أيقونة التطبيق على الهاتف حرفيًا.
class _NeedleThreadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2, cy = s / 2;
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s, s), Radius.circular(s * 0.225));

    // خلفية بطاقة بتدرّج بنفسجي غامق → ماجنتا داكنة (مطابق لأيقونة التطبيق
    // ولهوية كل شاشة بُنيت في المشروع).
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F081F), Color(0xFF360F5E)],
      ).createShader(Rect.fromLTWH(0, 0, s, s));
    canvas.drawRRect(rrect, bgPaint);

    canvas.save();
    canvas.clipRRect(rrect);

    const cream = Color(0xFFF8F0E0);
    const gold = Color(0xFFFFD54F);
    const goldDark = Color(0xFFD6A01E);

    final angle = 40 * math.pi / 180;
    final half = s * 0.30;
    final ex = cx + half * math.cos(angle);
    final ey = cy - half * math.sin(angle);
    final sx = cx - half * math.cos(angle) * 0.55;
    final sy = cy + half * math.sin(angle) * 0.55;

    // ظل الإبرة
    final needleShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.048
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawLine(Offset(sx, sy), Offset(ex, ey), needleShadow);

    // جسم الإبرة
    final needlePaint = Paint()
      ..color = cream
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.033
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(sx, sy), Offset(ex, ey), needlePaint);

    // رأس الإبرة (سهم)
    final ah = s * 0.056;
    final a1 = angle + 150 * math.pi / 180;
    final a2 = angle - 150 * math.pi / 180;
    final p1 = Offset(ex + ah * math.cos(a1), ey - ah * math.sin(a1));
    final p2 = Offset(ex + ah * math.cos(a2), ey - ah * math.sin(a2));
    final headPath = Path()
      ..moveTo(ex, ey)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(headPath, Paint()..color = cream);

    // طرف خلفي مستدير
    canvas.drawCircle(Offset(sx, sy), s * 0.016, Paint()..color = cream);

    // ثقب الإبرة
    const eyeT = 0.14;
    final eyeX = sx + (ex - sx) * eyeT;
    final eyeY = sy + (ey - sy) * eyeT;
    final eyeR = s * 0.023;
    canvas.drawCircle(Offset(eyeX, eyeY), eyeR, Paint()..color = const Color(0xFF0F081F));
    canvas.drawCircle(
        Offset(eyeX, eyeY),
        eyeR,
        Paint()
          ..color = cream
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.009);

    // الخيط الذهبي: منحنى بيزييه ناعم من ثقب الإبرة إلى عقدة صغيرة.
    final p0 = Offset(eyeX, eyeY);
    final p3 = Offset(cx - s * 0.18, cy + s * 0.20);
    final c1 = Offset(p0.dx - s * 0.008, p0.dy + s * 0.165);
    final c2 = Offset(p3.dx + s * 0.02, p3.dy - s * 0.15);

    final threadPath = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p3.dx, p3.dy);

    final threadShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.024
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(threadPath, threadShadow);

    final threadPaint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(threadPath, threadPaint);

    canvas.drawCircle(p3, s * 0.020, Paint()..color = gold);
    canvas.drawCircle(
        p3,
        s * 0.020,
        Paint()
          ..color = goldDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.004);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
