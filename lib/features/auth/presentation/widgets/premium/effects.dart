import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// يلف أي ويدجت ويمنحه القدرة على الاهتزاز أفقيًا بسرعة عند فشل
/// التحقق (مثل حركة "لا" برأسك). استدعِ [ShakeWidgetState.shake].
class ShakeWidget extends StatefulWidget {
  final Widget child;
  const ShakeWidget({super.key, required this.child});

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  void shake() {
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final offset = sin(t * pi * 6) * (1 - t) * 10;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// خلفية جزيئات ذهبية عائمة، حركة بطيئة وعشوائية جدًا — تعطي إحساسًا
/// بالعمق والفخامة دون تشتيت الانتباه عن الحقول. أداء خفيف: يعتمد
/// على CustomPainter واحد بدل عشرات الويدجتات المتحركة.
class FloatingGoldDust extends StatefulWidget {
  final int particleCount;
  const FloatingGoldDust({super.key, this.particleCount = 34});

  @override
  State<FloatingGoldDust> createState() => _FloatingGoldDustState();
}

class _Particle {
  double x, y, radius, speed, drift, opacity;
  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.drift,
    required this.opacity,
  });
}

class _FloatingGoldDustState extends State<FloatingGoldDust>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();
  final _random = Random();
  late final List<_Particle> _particles = List.generate(
    widget.particleCount,
    (_) => _Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      radius: 0.6 + _random.nextDouble() * 1.6,
      speed: 0.008 + _random.nextDouble() * 0.02,
      drift: (_random.nextDouble() - 0.5) * 0.4,
      opacity: 0.15 + _random.nextDouble() * 0.35,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = context.palette.accent;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _DustPainter(
              particles: _particles,
              t: _controller.value,
              color: gold,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _DustPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  final Color color;
  _DustPainter({required this.particles, required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final yy = (p.y - t * p.speed * 10) % 1.0;
      final xx = (p.x + sin((t * 6.28) + p.y * 10) * p.drift * 0.05) % 1.0;
      final paint = Paint()..color = color.withValues(alpha: p.opacity);
      canvas.drawCircle(
          Offset(xx * size.width, yy * size.height), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter oldDelegate) => true;
}

/// توهج دائري خافت يتبع نقطة اللمس/الفأرة خلف البطاقة المركزية —
/// نسخة تفاعلية بسيطة (Listener بدل MouseRegion فقط) تعمل باللمس
/// وبمؤشر الفأرة معًا.
class MouseTrackingGlow extends StatefulWidget {
  final Widget child;
  const MouseTrackingGlow({super.key, required this.child});

  @override
  State<MouseTrackingGlow> createState() => _MouseTrackingGlowState();
}

class _MouseTrackingGlowState extends State<MouseTrackingGlow> {
  Offset? _pointer;

  @override
  Widget build(BuildContext context) {
    final gold = context.palette.accent;
    return Listener(
      onPointerHover: (e) => setState(() => _pointer = e.localPosition),
      onPointerMove: (e) => setState(() => _pointer = e.localPosition),
      child: Stack(
        children: [
          if (_pointer != null)
            Positioned(
              left: _pointer!.dx - 140,
              top: _pointer!.dy - 140,
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        gold.withValues(alpha: 0.10),
                        gold.withValues(alpha: 0.0)
                      ],
                    ),
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

/// البطاقة المركزية الزجاجية (Glassmorphism): شفافية طفيفة + ضبابية
/// خلفية + توهج ذهبي خارجي ناعم (Neon/Glow Border) يعطي إحساسًا بأن
/// البطاقة تطفو فوق الخلفية السوداء.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: p.accent.withValues(alpha: 0.18),
              blurRadius: 40,
              spreadRadius: -6),
          BoxShadow(
              color: p.accent.withValues(alpha: 0.08),
              blurRadius: 90,
              spreadRadius: 6),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: p.surfaceElevated.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: p.accent.withValues(alpha: 0.28), width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// يُشغّل ظهورًا متتاليًا ناعمًا (Staggered Fade-in & Slide-up) لأي
/// قائمة أبناء — كل عنصر يظهر بعد سابقه بفارق أجزاء من الثانية.
class StaggeredEntrance extends StatelessWidget {
  final List<Widget> children;
  final Duration stagger;
  final Duration duration;

  const StaggeredEntrance({
    super.key,
    required this.children,
    this.stagger = const Duration(milliseconds: 80),
    this.duration = const Duration(milliseconds: 480),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: duration + stagger * i,
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0, 1),
                child: Transform.translate(
                    offset: Offset(0, (1 - value) * 14), child: child),
              );
            },
            child: children[i],
          ),
      ],
    );
  }
}
