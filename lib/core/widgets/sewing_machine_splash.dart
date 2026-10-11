import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// شاشة فتح التطبيق: ماكينة خياطة صناعية زوجية الإبرة بمظهر ثلاثي الأبعاد
/// (أسطح بتدرّجات معدنية وجوانب وظلال ومنظور يتمايل)، الإبرتان تخيطان قماشًا
/// يتحرك وتظهر الغرز، والعجلة تدور واللمعة تمر على الجسم. مرسومة برمجيًا
/// (لا صورة ثابتة) فتبقى حادة على كل الشاشات.
class SewingMachineSplash extends StatefulWidget {
  final String? message;
  const SewingMachineSplash({super.key, this.message});

  @override
  State<SewingMachineSplash> createState() => _SewingMachineSplashState();
}

class _SewingMachineSplashState extends State<SewingMachineSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
        ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.2),
          radius: 1.1,
          colors: [Color(0xFF2A1D0A), Color(0xFF0A0C1C)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AspectRatio(
              aspectRatio: 1.25,
              child: LayoutBuilder(
                builder: (context, c) => AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final sway = math.sin(_ctrl.value * 2 * math.pi) * 0.16;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(sway)
                        ..rotateX(-0.06),
                      child: CustomPaint(
                        size: Size(c.maxWidth, c.maxHeight),
                        painter: SewingMachine3DPainter(_ctrl.value),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [Color(0xFFB8860B), Color(0xFFFFE08A), Color(0xFFB8860B)],
              ).createShader(r),
              child: const Text(
                'مشاريعنا',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 10),
              Text(widget.message!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
            ],
          ]),
        ),
      ),
    );
  }
}

class SewingMachine3DPainter extends CustomPainter {
  final double t;
  SewingMachine3DPainter(this.t);

  // لوحة الألوان المعدنية
  static const _goldHi = Color(0xFFFFE9A0);
  static const _gold = Color(0xFFD4AF37);
  static const _goldLo = Color(0xFF7A5A12);
  static const _steel = Color(0xFFE6E8EE);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 200.0;
    canvas.scale(k);
    final needle = math.sin(t * 2 * math.pi * 5);
    final wheelA = t * 2 * math.pi * 5 / 2;
    final fabricShift = (t * 5 * 12) % 12; // يتحرك القماش خطوة لكل غرزة

    // ظل الأرض
    canvas.drawOval(
      const Rect.fromLTWH(18, 118, 176, 22),
      Paint()
        ..color = Colors.black.withValues(alpha: .55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // صندوق ثلاثي الأبعاد: واجهة + سطح علوي + جانب أيمن.
    void box(double x, double y, double w, double h, double dx, double dy,
        {Color hi = _goldHi, Color mid = _gold, Color lo = _goldLo}) {
      final front = Rect.fromLTWH(x, y, w, h);
      // الجانب الأيمن
      final side = Path()
        ..moveTo(x + w, y)
        ..lineTo(x + w + dx, y + dy)
        ..lineTo(x + w + dx, y + dy + h)
        ..lineTo(x + w, y + h)
        ..close();
      canvas.drawPath(side, Paint()..color = lo);
      // السطح العلوي
      final top = Path()
        ..moveTo(x, y)
        ..lineTo(x + dx, y + dy)
        ..lineTo(x + w + dx, y + dy)
        ..lineTo(x + w, y)
        ..close();
      canvas.drawPath(
          top,
          Paint()
            ..shader = LinearGradient(colors: [hi, mid])
                .createShader(Rect.fromLTWH(x, y + dy, w + dx, -dy)));
      // الواجهة
      canvas.drawRRect(
        RRect.fromRectAndRadius(front, const Radius.circular(1.5)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [mid, lo],
          ).createShader(front),
      );
      canvas.drawRect(
        Rect.fromLTWH(x, y, w, 1.2),
        Paint()..color = hi.withValues(alpha: .8),
      );
    }

    // القاعدة (طاولة الماكينة)
    box(22, 104, 150, 12, 22, -10,
        hi: const Color(0xFFEAC75A), mid: const Color(0xFFB8922B), lo: const Color(0xFF5E4410));

    // القماش على القاعدة (يتحرك يسارًا) + خطّا الغرز
    final cloth = Path()
      ..moveTo(26, 103.5)
      ..lineTo(150, 103.5)
      ..lineTo(170, 94)
      ..lineTo(46, 94)
      ..close();
    canvas.save();
    canvas.clipPath(Path()..addRect(const Rect.fromLTWH(22, 90, 150, 16)));
    canvas.drawPath(
        cloth,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFF2F6FDB), Color(0xFF1B3F8C)])
              .createShader(const Rect.fromLTWH(26, 94, 140, 10)));
    final stitch = Paint()
      ..color = const Color(0xFFFFF3C4)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row < 2; row++) {
      final y = 99.5 - row * 2.2 + 0;
      for (double x = 150 - fabricShift; x > 40; x -= 12) {
        canvas.drawLine(Offset(x, y), Offset(x - 6, y), stitch);
      }
    }
    canvas.restore();

    // العمود الأيمن + الذراع العلوية + الرأس
    box(132, 38, 24, 66, 14, -7);
    box(52, 38, 104, 20, 14, -7,
        hi: const Color(0xFFFFF0B3), mid: const Color(0xFFE3BE45), lo: const Color(0xFF8A6914));
    box(52, 38, 32, 50, 10, -5,
        hi: const Color(0xFFFFF0B3), mid: const Color(0xFFD9B23C), lo: const Color(0xFF7A5A12));

    // لوحة تحكم صغيرة على العمود
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(138, 64, 12, 18), const Radius.circular(2)),
      Paint()..color = const Color(0xFF14110A),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(144, 69.5 + i * 5),
          1.3, Paint()..color = i == 0 ? const Color(0xFF39FF14) : const Color(0xFFFFD700));
    }

    // بكرة الخيط + الخيط
    final spoolTop = const Offset(104, 33);
    canvas.drawRect(
        const Rect.fromLTWH(98, 33, 12, 9), Paint()..color = const Color(0xFFB71C2B));
    canvas.drawOval(Rect.fromCenter(center: const Offset(104, 42), width: 12, height: 4),
        Paint()..color = const Color(0xFF8E1521));
    canvas.drawOval(Rect.fromCenter(center: spoolTop, width: 12, height: 4),
        Paint()..color = const Color(0xFFFF5A68));
    final thread = Paint()
      ..color = const Color(0xFFFF5A68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    final ny = needle * 3.0;
    final tp = Path()
      ..moveTo(spoolTop.dx, spoolTop.dy)
      ..quadraticBezierTo(90, 30, 66, 40)
      ..lineTo(64 + 0, 70 + ny);
    canvas.drawPath(tp, thread);
    canvas.drawLine(const Offset(66, 40), Offset(74, 70 + ny), thread);

    // قضيبا الإبرتين (زوجية) وقدم الضغط
    const barPaint = Color(0xFFBFC3CC);
    for (final nx in [64.0, 74.0]) {
      canvas.drawRect(Rect.fromLTWH(nx - 1.4, 58, 2.8, 22 + ny),
          Paint()..color = barPaint);
      canvas.drawRect(Rect.fromLTWH(nx - .5, 58, .9, 22 + ny),
          Paint()..color = Colors.white.withValues(alpha: .8));
      canvas.drawLine(Offset(nx, 80 + ny), Offset(nx, 96 + ny),
          Paint()
            ..color = _steel
            ..strokeWidth = 1.1
            ..strokeCap = StrokeCap.round);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(58, 88, 22, 4), const Radius.circular(1.5)),
      Paint()..color = const Color(0xFF9EA3AE),
    );

    // عجلة اليد (ثلاثية الأبعاد: سماكة + وجه + أذرع تدور)
    const wc = Offset(178, 46);
    canvas.drawOval(Rect.fromCenter(center: wc.translate(3, 0), width: 22, height: 30),
        Paint()..color = _goldLo);
    canvas.drawOval(
        Rect.fromCenter(center: wc, width: 22, height: 30),
        Paint()
          ..shader = const RadialGradient(colors: [_goldHi, _gold, _goldLo])
              .createShader(Rect.fromCenter(center: wc, width: 22, height: 30)));
    canvas.drawOval(Rect.fromCenter(center: wc, width: 14, height: 20),
        Paint()..color = const Color(0xFF1E160A));
    for (var i = 0; i < 3; i++) {
      final a = wheelA + i * 2 * math.pi / 3;
      canvas.drawLine(
          wc,
          wc.translate(6.4 * math.cos(a), 9.4 * math.sin(a)),
          Paint()
            ..color = _goldHi
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(wc, 2, Paint()..color = _goldHi);

    // لمعة تمرّ على الجسم
    final sx = -60 + (t * 1.0) * 320;
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(20, 30, 180, 90));
    canvas.drawPath(
      Path()
        ..moveTo(sx, 120)
        ..lineTo(sx + 14, 120)
        ..lineTo(sx + 44, 30)
        ..lineTo(sx + 30, 30)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: .16),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SewingMachine3DPainter old) => old.t != t;
}

/// يعرض [SewingMachineSplash] فوق التطبيق لمدة [duration] على الأقل ثم يخفيه
/// بتلاشٍ سلس، بينما يتابع التطبيق تحميله تحته.
class StartupSplashGate extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const StartupSplashGate({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 3200),
  });

  @override
  State<StartupSplashGate> createState() => _StartupSplashGateState();
}

class _StartupSplashGateState extends State<StartupSplashGate> {
  bool _visible = true;
  bool _gone = false;
  Timer? _t1;
  Timer? _t2;

  @override
  void initState() {
    super.initState();
    _t1 = Timer(widget.duration, () {
      if (mounted) setState(() => _visible = false);
    });
    _t2 = Timer(widget.duration + const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _gone = true);
    });
  }

  @override
  void dispose() {
    _t1?.cancel();
    _t2?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: widget.child),
      if (!_gone)
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 450),
              opacity: _visible ? 1 : 0,
              child: const Material(child: SewingMachineSplash()),
            ),
          ),
        ),
    ]);
  }
}
