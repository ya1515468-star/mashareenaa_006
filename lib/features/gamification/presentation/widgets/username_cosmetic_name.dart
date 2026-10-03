import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/entities/username_effect.dart';
import 'username_effect_text.dart';
import '../../../profile/presentation/widgets/name_template.dart';

class UsernameCosmeticName extends StatelessWidget {
  final String name;
  final UsernameEffect effect;
  final double fontSize;
  final Color? overrideColor;
  final FontWeight fontWeight;
  final String? backgroundMode;
  final String? backgroundColor1;
  final String? backgroundColor2;
  final double backgroundOpacity;
  final String? externalEffect;
  final Color? glowColor;
  final EdgeInsets padding;
  final String? fontFamily;
  /// Standalone video-reference template; not a UsernameEffect or VisualEffect.
  final String? templateKey;
  final String? userId;

  const UsernameCosmeticName({
    super.key,
    required this.name,
    required this.effect,
    this.fontSize = 16,
    this.overrideColor,
    this.fontWeight = FontWeight.w800,
    this.backgroundMode,
    this.backgroundColor1,
    this.backgroundColor2,
    this.backgroundOpacity = .82,
    this.externalEffect,
    this.glowColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.fontFamily,
    this.templateKey,
    this.userId,
  });

  Color _hex(String? value, Color fallback) {
    final s = value?.replaceAll('#', '').trim();
    if (s == null || s.length != 6) return fallback;
    final n = int.tryParse('FF$s', radix: 16);
    return n == null ? fallback : Color(n);
  }

  @override
  Widget build(BuildContext context) {
    final key = templateKey?.trim();
    final mode = backgroundMode?.trim() ?? '';
    // Every fixed dimension inside the name (template box, panel padding,
    // border width/radius) is scaled by the same factor derived from the
    // user's chosen font size, so shrinking the name shrinks the WHOLE
    // composition proportionally instead of leaving a small text inside a
    // full-size template and frame. 22 is the server-side default font size.
    final scale = (fontSize / 22.0).clamp(0.55, 2.0).toDouble();
    final scaledPadding = padding * scale;
    final nameText = UsernameEffectText(
      name: name,
      effect: effect,
      fontSize: fontSize,
      overrideColor: overrideColor,
      fontWeight: fontWeight,
      glowColor: glowColor,
      fontFamily: fontFamily,
    );

    // Video template is the outer visual container. Any purchased/selected
    // username background and username effect stay INSIDE that container.
    if (key != null && NameTemplateRegistry.get(key) != null) {
      Widget inner = nameText;
      if (mode.isNotEmpty) {
        inner = _AnimatedUsernamePanel(
          mode: mode,
          color1: _hex(backgroundColor1, const Color(0xFF111522)),
          color2: _hex(backgroundColor2, const Color(0xFF5D2CFF)),
          opacity: backgroundOpacity.clamp(0.0, 1.0).toDouble(),
          externalEffect: externalEffect ?? '',
          glowColor: glowColor,
          padding: scaledPadding,
          scale: scale,
          child: inner,
        );
      }
      return NameTemplateHost(
        templateKey: key,
        name: name,
        width: 220.0 * scale,
        // Slightly taller than the previous 56 so the name breathes inside
        // the template and lines up with the frame/background instead of
        // looking vertically squeezed.
        height: 76.0 * scale,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: fontFamily,
        // FittedBox inside NameTemplateHost already centres and scales this,
        // so no extra Center wrapper (which would add unbounded-constraint
        // ambiguity inside a FittedBox).
        content: inner,
      );
    }

    // No video template: preserve the existing standalone behavior exactly.
    if (mode.isEmpty) return nameText;
    return _AnimatedUsernamePanel(
      mode: mode,
      color1: _hex(backgroundColor1, const Color(0xFF111522)),
      color2: _hex(backgroundColor2, const Color(0xFF5D2CFF)),
      opacity: backgroundOpacity.clamp(0.0, 1.0).toDouble(),
      externalEffect: externalEffect ?? '',
      glowColor: glowColor,
      padding: scaledPadding,
      scale: scale,
      child: nameText,
    );
  }
}

class _AnimatedUsernamePanel extends StatefulWidget {
  final String mode;
  final Color color1;
  final Color color2;
  final double opacity;
  final String externalEffect;
  final Color? glowColor;
  final EdgeInsets padding;
  final double scale;
  final Widget child;
  const _AnimatedUsernamePanel({required this.mode, required this.color1, required this.color2, required this.opacity, required this.externalEffect, required this.glowColor, required this.padding, required this.scale, required this.child});
  @override State<_AnimatedUsernamePanel> createState() => _AnimatedUsernamePanelState();
}

class _AnimatedUsernamePanelState extends State<_AnimatedUsernamePanel> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  @override void dispose(){_c.dispose();super.dispose();}

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value * math.pi * 2;
        final pulse = .55 + .45 * (math.sin(t) + 1) / 2;
        final transparent = widget.mode.startsWith('transparent');
        final dual = widget.mode == 'dual';
        final glow = widget.color1.withValues(alpha: .12 + .16 * pulse);
        final borderColors = [widget.color1, dual ? widget.color2 : widget.color1, widget.color2, widget.color1];
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10 * widget.scale),
            // Interior fill depends on the chosen mode:
            //  * transparent_* / empty  -> genuinely empty, so a name effect
            //    or template inside is never covered (spec item 3.3).
            //  * solid                  -> filled with the user's single color.
            //  * dual                   -> gradient between the user's two
            //    manually-merged colors.
            // (This was previously hardcoded transparent for EVERY mode, which
            // made a chosen solid/dual background invisible — only its border
            // was tinted. The spec's "empty interior" rule applies to the empty
            // variant only, not to every background.)
            color: (transparent || dual)
                ? Colors.transparent
                : widget.color1.withValues(alpha: widget.opacity),
            gradient: dual
                ? LinearGradient(
                    begin: Alignment(-1 + pulse * .8, 0),
                    end: const Alignment(1.0, 0.0),
                    colors: [
                      widget.color1.withValues(alpha: widget.opacity),
                      widget.color2.withValues(alpha: widget.opacity),
                    ],
                  )
                : null,
            border: Border.all(color: widget.color1.withValues(alpha: .52 + .28 * pulse), width: 1.2 * widget.scale),
            boxShadow: [
              if (widget.glowColor != null)
                BoxShadow(color: widget.glowColor!.withValues(alpha: .20 + .20 * pulse), blurRadius: (10.0 + pulse * 6.0) * widget.scale, spreadRadius: .5 * widget.scale),
              BoxShadow(color: glow, blurRadius: (8.0 + pulse * 8.0) * widget.scale, spreadRadius: .4 * widget.scale),
              if (transparent) BoxShadow(color: widget.color2.withValues(alpha: .10 + .08 * pulse), blurRadius: 14.0 * widget.scale, spreadRadius: 1.0 * widget.scale),
            ],
          ),
          child: CustomPaint(
            painter: _PanelEffectPainter(colors: borderColors, t: t, transparent: transparent, externalEffect: widget.externalEffect, scale: widget.scale),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        );
      },
    );
  }
}

class _PanelEffectPainter extends CustomPainter {
  final List<Color> colors; final double t; final bool transparent; final String externalEffect; final double scale;
  const _PanelEffectPainter({required this.colors, required this.t, required this.transparent, required this.externalEffect, required this.scale});
  @override void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final r = RRect.fromRectAndRadius(rect.deflate(.7 * scale), Radius.circular(10 * scale));
    final shader = SweepGradient(startAngle: t, endAngle: t + math.pi * 2, colors: [...colors, colors.first]).createShader(rect);
    canvas.drawRRect(r, Paint()..style=PaintingStyle.stroke..strokeWidth=1.4 * scale..shader=shader);
    final p = Paint()..style=PaintingStyle.stroke..strokeCap=StrokeCap.round..strokeWidth=1.6 * scale;
    if (externalEffect == 'lightning') {
      for (int i=0;i<4;i++) { final double x=size.width*(0.18 + i.toDouble()*0.22); final double y= i.isEven ? 1.0 : size.height-1.0; final path=Path()..moveTo(x,y)..lineTo(x+7*math.sin(t+i.toDouble()),size.height/2)..lineTo(x+14*math.cos(t+i.toDouble()),size.height-y); p.color=colors[i%colors.length].withValues(alpha:.7); canvas.drawPath(path,p); }
    } else if (externalEffect == 'ice') {
      for (int i=0;i<10;i++) { final double x=size.width*(i.toDouble()/9.0); final double h=4.0+3.0*math.sin(t+i.toDouble()); canvas.drawLine(Offset(x,0),Offset(x+h/2,h),p..color=colors[i%colors.length].withValues(alpha:.62)); }
    } else {
      for (int i=0;i<12;i++) { final double phase=(i.toDouble()/12.0)+_mod(t/(math.pi*2.0)+i.toDouble()*0.07,1.0); final double x=(size.width*phase)%size.width; final double y=1.0 + (i % 3).toDouble()*2.0; canvas.drawCircle(Offset(x,y),1.2,p..style=PaintingStyle.fill..color=colors[i%colors.length].withValues(alpha:.45)); }
    }
  }
  double _mod(double x,double y)=>x-y*(x/y).floor();
  @override bool shouldRepaint(covariant _PanelEffectPainter oldDelegate)=>oldDelegate.t!=t || oldDelegate.externalEffect!=externalEffect;
}
