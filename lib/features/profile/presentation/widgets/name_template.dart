import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 50 independent name-template cosmetics reconstructed from the supplied video.
/// This registry deliberately has no dependency on UsernameEffect or VisualEffect.
class NameTemplateDefinition {
  final String key;
  final String asset;
  final int referenceIndex;
  final int variantGroup;
  final int motionStyle;
  const NameTemplateDefinition({
    required this.key,
    required this.asset,
    required this.referenceIndex,
    required this.variantGroup,
    required this.motionStyle,
  });
}

class NameTemplateRegistry {
  static const int count = 50;
  static final List<NameTemplateDefinition> all = List.generate(
    count,
    (i) => NameTemplateDefinition(
      key: 'name_template_${(i + 1).toString().padLeft(2, '0')}',
      asset: 'assets/name_templates/name_template_${(i + 1).toString().padLeft(2, '0')}.png',
      referenceIndex: (i % 10) + 1,
      variantGroup: i < 10 ? 0 : ((i - 10) ~/ 10) + 1,
      motionStyle: (i * 7) % 10,
    ),
  );

  static NameTemplateDefinition? get(String? key) {
    final normalized = key?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    for (final item in all) {
      if (item.key == normalized) return item;
    }
    return null;
  }
}

class NameTemplateHost extends StatefulWidget {
  final String templateKey;
  final String name;
  final double width;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final String? fontFamily;
  /// Optional composited username content (background + name effect).
  /// It is rendered inside the video template, never as an outer layer.
  final Widget? content;

  const NameTemplateHost({
    super.key,
    required this.templateKey,
    required this.name,
    this.width = 220,
    this.height = 76,
    this.fontSize = 18,
    this.fontWeight = FontWeight.w900,
    this.fontFamily,
    this.content,
  });

  @override
  State<NameTemplateHost> createState() => _NameTemplateHostState();
}

class _NameTemplateHostState extends State<NameTemplateHost>
    with SingleTickerProviderStateMixin {
  int get widgetMotionSeed => NameTemplateRegistry.get(widget.templateKey)?.motionStyle ?? 0;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 2100 + (widgetMotionSeed % 10) * 120),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final definition = NameTemplateRegistry.get(widget.templateKey);
    if (definition == null) {
      return Text(widget.name, textDirection: TextDirection.rtl);
    }
    const ratio = 352 / 89;
    final targetWidth = widget.width;
    final targetHeight = widget.height > 0 ? widget.height : targetWidth / ratio;
    return SizedBox(
      width: targetWidth,
      height: targetHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final phase = (t * 2 - .10) % 1.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: Image.asset(
                  definition.asset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _NameTemplateShinePainter(
                    progress: phase,
                    intensity: .42,
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _NameTemplateMotionPainter(
                    progress: t,
                    style: definition.motionStyle,
                    referenceIndex: definition.referenceIndex,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  targetWidth * .14,
                  targetHeight * .23,
                  targetWidth * .14,
                  targetHeight * .18,
                ),
                // Both branches get the same auto-fit treatment now. Before,
                // only the plain-text fallback was wrapped in a FittedBox —
                // a composed name (effect + background + frame) passed in as
                // `content` was rendered at its natural size and could
                // overflow or sit disproportionately inside the template.
                // Scaling BOTH keeps the name perfectly fitted to the
                // template's inner area no matter how long the name is or
                // which layers are active.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: widget.content ??
                      Text(
                        widget.name,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: widget.fontSize,
                          fontWeight: widget.fontWeight,
                          fontFamily: widget.fontFamily,
                          color: Colors.white,
                          height: 1.0,
                          shadows: const [
                            Shadow(color: Color(0xFF000000), blurRadius: 3, offset: Offset(0, 1)),
                            Shadow(color: Color(0xFF000000), blurRadius: 6, offset: Offset(0, 0)),
                          ],
                        ),
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


class _NameTemplateMotionPainter extends CustomPainter {
  final double progress;
  final int style;
  final int referenceIndex;
  const _NameTemplateMotionPainter({required this.progress, required this.style, required this.referenceIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final phase = progress * math.pi * 2;
    if (style == 0) {
      p.color = Colors.white.withValues(alpha: .10 + .05 * math.sin(phase));
      canvas.drawOval(Rect.fromCenter(center: Offset(size.width * .5, size.height * .28), width: size.width * .20, height: size.height * .18), p);
    } else if (style == 1) {
      final x = size.width * (.15 + ((progress + referenceIndex * .03) % 1.0) * .70);
      p.color = Colors.white.withValues(alpha: .16);
      canvas.drawLine(Offset(x, size.height * .14), Offset(x - size.width * .12, size.height * .78), p);
    } else if (style == 2) {
      p.color = Colors.white.withValues(alpha: .12);
      for (int i = 0; i < 3; i++) {
        final r = size.height * (.13 + i * .035) + math.sin(phase + i) * 1.5;
        canvas.drawOval(Rect.fromCenter(center: Offset(size.width * .5, size.height * .28), width: size.width * (.18 + i * .025) + r, height: r), p);
      }
    } else if (style == 3) {
      p.color = Colors.white.withValues(alpha: .14);
      final y = size.height * (.22 + .10 * math.sin(phase));
      canvas.drawArc(Rect.fromLTWH(size.width * .18, y, size.width * .64, size.height * .26), math.pi, math.pi * .72, false, p);
    } else if (style == 4) {
      p.color = Colors.white.withValues(alpha: .13);
      final cx = size.width * (.50 + .025 * math.sin(phase));
      final cy = size.height * (.29 + .018 * math.cos(phase));
      canvas.drawCircle(Offset(cx, cy), size.height * .07, p);
      canvas.drawCircle(Offset(cx, cy), size.height * .095, p);
    } else if (style == 5) {
      p.color = Colors.white.withValues(alpha: .11);
      final x = size.width * (.18 + ((progress * .75 + .07) % 1.0));
      canvas.drawOval(Rect.fromCenter(center: Offset(x, size.height * .25), width: size.width * .08, height: size.height * .32), p);
    } else if (style == 6) {
      p.color = Colors.white.withValues(alpha: .10);
      for (int i = 0; i < 5; i++) {
        final a = phase + i * math.pi * 2 / 5;
        final cx = size.width * .5 + math.cos(a) * size.width * .19;
        final cy = size.height * .26 + math.sin(a) * size.height * .12;
        canvas.drawCircle(Offset(cx, cy), size.height * .018, p);
      }
    } else if (style == 7) {
      p.color = Colors.white.withValues(alpha: .12);
      final y = size.height * (.08 + .28 * ((math.sin(phase) + 1) / 2));
      canvas.drawLine(Offset(size.width * .22, y), Offset(size.width * .78, y), p);
    } else if (style == 8) {
      p.color = Colors.white.withValues(alpha: .10);
      for (int i = 0; i < 4; i++) {
        final r = size.height * (.09 + i * .025);
        final cx = size.width * (.42 + .16 * math.sin(phase + i));
        canvas.drawArc(Rect.fromCenter(center: Offset(cx, size.height * .24), width: size.width * .20 + r, height: r * 1.8), phase + i, math.pi * .75, false, p);
      }
    } else {
      p.color = Colors.white.withValues(alpha: .11);
      final pulse = .5 + .5 * math.sin(phase * 1.5);
      canvas.drawOval(Rect.fromCenter(center: Offset(size.width * .5, size.height * .25), width: size.width * (.20 + pulse * .06), height: size.height * (.18 + pulse * .03)), p);
      canvas.drawCircle(Offset(size.width * .5, size.height * .25), size.height * (.05 + pulse * .015), p);
    }
  }

  @override
  bool shouldRepaint(covariant _NameTemplateMotionPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.style != style || oldDelegate.referenceIndex != referenceIndex;
}

class _NameTemplateShinePainter extends CustomPainter {
  final double progress;
  final double intensity;
  const _NameTemplateShinePainter({required this.progress, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final x = size.width * (-.20 + progress * 1.40);
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: intensity),
        Colors.white.withValues(alpha: intensity * .16),
        Colors.transparent,
      ],
      stops: const [.0, .46, .56, 1.0],
    ).createShader(Rect.fromLTWH(x - size.width * .28, 0, size.width * .56, size.height));
    final paint = Paint()..shader = shader..blendMode = BlendMode.screen;
    final clip = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height * .22));
    canvas.save();
    canvas.clipRRect(clip);
    canvas.drawRect(Offset.zero & size, paint);
    canvas.restore();
    // Gentle perimeter sparkle, matching the moving/glossy character seen in the reference.
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: .18 + .10 * math.sin(progress * math.pi * 2));
    canvas.drawRRect(clip, p);
  }

  @override
  bool shouldRepaint(covariant _NameTemplateShinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.intensity != intensity;
}
