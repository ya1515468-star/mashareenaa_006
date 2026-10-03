import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/widgets/frame_effect_painter.dart';

/// محرّك توهج الاسم — مطابق لمواصفة CSS المُرفَقة (glow keyframe:
/// text-shadow ينبض بين شدّة خفيفة وقوية كل ثانيتين) لكن بمعادِله
/// الحقيقي في Flutter (ظلال نص متحركة عبر AnimationController)، وليس
/// نسخًا حرفيًا لكود CSS لا يعمل خارج الويب.
class GlowText extends StatefulWidget {
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  const GlowText({
    super.key,
    required this.text,
    required this.color,
    this.fontSize = 20,
    this.fontWeight = FontWeight.bold,
  });

  @override
  State<GlowText> createState() => _GlowTextState();
}

class _GlowTextState extends State<GlowText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final intensity = 6 + (_controller.value * 14); // 6px → 20px تقريبًا
        return Text(
          widget.text,
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: widget.fontWeight,
            color: widget.color,
            shadows: [
              Shadow(color: widget.color, blurRadius: intensity),
              Shadow(
                  color: widget.color.withValues(alpha: 0.8),
                  blurRadius: intensity * 1.6),
            ],
          ),
        );
      },
    );
  }
}

/// محرّك جزيئات متحركة مُعامَل بلون واحد — نفس فكرة float keyframe
/// المُرفَقة (جزيئات تصعد وتتلاشى)، مبني على CustomPainter لأداء
/// خفيف حتى مع عناصر كثيرة على الشاشة.
class ParticleFieldGeneric extends StatefulWidget {
  final Color color;
  final int count;
  const ParticleFieldGeneric({super.key, required this.color, this.count = 22});

  @override
  State<ParticleFieldGeneric> createState() => _ParticleFieldGenericState();
}

class _Particle {
  final double x, speed, size, phase;
  _Particle(
      {required this.x,
      required this.speed,
      required this.size,
      required this.phase});
}

class _ParticleFieldGenericState extends State<ParticleFieldGeneric>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final r = Random(widget.color.toARGB32());
    _particles = List.generate(
      widget.count,
      (_) => _Particle(
        x: r.nextDouble(),
        speed: 0.5 + r.nextDouble(),
        size: 2 + r.nextDouble() * 3,
        phase: r.nextDouble(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ParticlePainter(
              particles: _particles, t: _controller.value, color: widget.color),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  final Color color;
  _ParticlePainter(
      {required this.particles, required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final progress = (t * p.speed + p.phase) % 1.0;
      final y = size.height * (1 - progress);
      final opacity = sin(progress * pi); // يظهر تدريجيًا ثم يتلاشى
      final paint = Paint()
        ..color = color.withValues(alpha: opacity.clamp(0, 1) * 0.8);
      canvas.drawCircle(Offset(p.x * size.width, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

/// محرّك خلفية متدرّجة متحركة — مطابق لمواصفة gradient keyframe
/// المرفقة (background-position يتحرك بين 0% و100%)، بمعادِله في
/// Flutter عبر تدوير زاوية LinearGradient بمرور الوقت.
class AnimatedGradientBackgroundGeneric extends StatefulWidget {
  final List<Color> colors;
  final Widget? child;
  final BorderRadius? borderRadius;

  const AnimatedGradientBackgroundGeneric({
    super.key,
    required this.colors,
    this.child,
    this.borderRadius,
  });

  @override
  State<AnimatedGradientBackgroundGeneric> createState() =>
      _AnimatedGradientBackgroundGenericState();
}

class _AnimatedGradientBackgroundGenericState
    extends State<AnimatedGradientBackgroundGeneric>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors.length >= 2
        ? widget.colors
        : [widget.colors.first, widget.colors.first];
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * 2 * pi;
        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              colors: [...colors, colors.first],
              begin: Alignment(cos(angle), sin(angle)),
              end: Alignment(-cos(angle), -sin(angle)),
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// محرّك إطار الصورة الشخصية — حلقة متوهّجة حول الصورة بلون/تدرّج
/// العنصر المُشترى، مع نبض خفيف بدل ثبات كامل.
class StoreAvatarFrame extends StatefulWidget {
  final List<Color> colors;
  final Widget child;
  final double padding;
  final String effect;

  const StoreAvatarFrame({
    super.key,
    required this.colors,
    required this.child,
    this.padding = 4,
    this.effect = 'pulse_glow',
  });

  @override
  State<StoreAvatarFrame> createState() => _StoreAvatarFrameState();
}

class _StoreAvatarFrameState extends State<StoreAvatarFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = widget.colors.first;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final glow = 6 + (_controller.value * 10);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(widget.padding),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [...widget.colors, mainColor]),
                boxShadow: [
                  BoxShadow(color: mainColor.withValues(alpha: 0.6), blurRadius: glow),
                ],
              ),
              child: widget.child,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: FrameEffectPainter(
                    effect: widget.effect,
                    t: _controller.value,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
