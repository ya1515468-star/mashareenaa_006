import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/username_effect.dart';
import '../../../profile/presentation/widgets/arabic_font_catalog.dart';

/// محرك موحد لتأثيرات أسماء المستخدمين.
///
/// جميع التأثيرات الـ100 هي تأثيرات حقيقية مولدة داخل Flutter، وليست صورًا
/// ثابتة. يتم اشتقاقها من 10 محركات حركة × 10 لوحات لونية مختلفة، مع الحفاظ
/// على اسم التأثير المحفوظ خادميًا عبر [UsernameEffect].
class UsernameEffectText extends StatefulWidget {
  final String name;
  final UsernameEffect effect;
  final double fontSize;
  final Color? overrideColor;
  final FontWeight fontWeight;
  final Color? glowColor;
  final String? fontFamily;

  const UsernameEffectText({
    super.key,
    required this.name,
    required this.effect,
    this.fontSize = 16,
    this.overrideColor,
    this.fontWeight = FontWeight.w800,
    this.glowColor,
    this.fontFamily,
  });

  @override
  State<UsernameEffectText> createState() => _UsernameEffectTextState();
}

class _UsernameEffectTextState extends State<UsernameEffectText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200 + (widget.effect.paletteIndex * 90)),
    );
    if (widget.effect.isAnimated) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant UsernameEffectText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effect != widget.effect) {
      _controller.duration = Duration(
        milliseconds: 1200 + (widget.effect.paletteIndex * 90),
      );
      if (widget.effect.isAnimated) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle _baseStyle({Color? color}) {
    return TextStyle(
      fontSize: widget.fontSize,
      fontWeight: widget.fontWeight,
      fontFamily: localArabicFontFamily(widget.fontFamily),
      color: color,
      height: 1.0,
      shadows: [
        Shadow(
          color: (widget.glowColor ?? widget.overrideColor ?? widget.effect.gradient.first)
              .withValues(alpha: .38),
          blurRadius: 7,
        ),
      ],
    );
  }

  Widget _plain() {
    return Text(widget.name, style: _baseStyle(color: widget.overrideColor));
  }

  Widget _gradientText({required Gradient gradient, double opacity = 1}) {
    return Opacity(
      opacity: opacity,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: gradient.createShader,
        child: Text(
          widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _baseStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildAnimated() {
    final base = widget.effect.gradient;
    final accent = widget.overrideColor;
    final colors = accent == null
        ? base
        : <Color>[
            Color.lerp(accent, Colors.white, .24)!,
            accent,
            Color.lerp(accent, Colors.black, .18)!,
            accent,
          ];
    final mode = widget.effect.animationMode;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final wave = math.sin(t * math.pi * 2);
        final pulse = .78 + ((wave + 1) * .11);
        final shift = (t * 2) - 1;

        final gradient = LinearGradient(
          begin: Alignment(-1.2 + (shift * .8), -1),
          end: Alignment(1.2 + (shift * .8), 1),
          colors: [
            colors.first,
            colors.length > 2 ? colors[1] : colors.last,
            colors.last,
            colors.first.withValues(alpha: .92),
          ],
          stops: const [0.0, .35, .65, 1.0],
        );

        switch (mode) {
          case 1: // لهب/اهتزاز حراري
            return Transform.translate(
              offset: Offset(wave * 0.7, -wave.abs() * .8),
              child: _gradientText(gradient: gradient, opacity: pulse),
            );

          case 2: // شريط لمعان
            return _gradientText(gradient: gradient);

          case 3: // نبض ضوئي
            return Transform.scale(
              scale: 1 + (wave * .012),
              child: _gradientText(gradient: gradient, opacity: pulse),
            );

          case 4: // موجة صاعدة
            return Transform.translate(
              offset: Offset(0, wave * 1.15),
              child: _gradientText(gradient: gradient),
            );

          case 5: // وميض/كهرباء
            final flicker = ((t * 13).floor() % 4) == 0 ? .62 : 1.0;
            return Transform.translate(
              offset: Offset(((t * 23).floor() % 3 - 1) * .55, 0),
              child: _gradientText(gradient: gradient, opacity: flicker),
            );

          case 6: // قفزة دقيقة
            return Transform.scale(
              scale: 1 + ((wave + 1) * .007),
              child: Transform.rotate(
                angle: wave * .006,
                child: _gradientText(gradient: gradient),
              ),
            );

          case 7: // قوس قزح / طيف متحرك
            final hueShift = t * math.pi * 2;
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                final r = math.max(bounds.width, 1.0).toDouble();
                return SweepGradient(
                  center: Alignment.center,
                  startAngle: hueShift,
                  endAngle: hueShift + math.pi * 2,
                  colors: <Color>[
                    colors.first,
                    colors.last,
                    Colors.white,
                    colors.first,
                  ],
                ).createShader(Rect.fromLTWH(0, 0, r, bounds.height));
              },
              child: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _baseStyle(color: Colors.white),
              ),
            );

          case 8: // تشويش بصري
            final jitter = (((t * 17).floor() % 5) - 2) * .45;
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: Offset(jitter * -1.4, 0),
                  child: Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _baseStyle(
                      color: colors.first.withValues(alpha: .38),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(jitter * 1.4, 0),
                  child: Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _baseStyle(
                      color: colors.last.withValues(alpha: .36),
                    ),
                  ),
                ),
                _gradientText(gradient: gradient),
              ],
            );

          case 9: // قوس ضوئي قطري
            final beam = t * 1.6 - .3;
            final beamGradient = LinearGradient(
              begin: Alignment(-1 + beam, 1),
              end: Alignment(-beam, -1),
              colors: [colors.first, Colors.white, colors.last],
              stops: const [.15, .5, .85],
            );
            return _gradientText(gradient: beamGradient);

          case 10: // تنفس/Glow قوي
            return Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: colors.last.withValues(alpha: .16 + (.2 * pulse)),
                    blurRadius: 8 + (7 * pulse),
                    spreadRadius: 0.3,
                  ),
                ],
              ),
              child: _gradientText(gradient: gradient, opacity: pulse),
            );
          default:
            return _plain();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.name.trim().isEmpty) return const SizedBox.shrink();

    if (widget.effect == UsernameEffect.none) {
      return _plain();
    }

    return _buildAnimated();
  }
}
