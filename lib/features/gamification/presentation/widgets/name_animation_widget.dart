import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/name_animation_providers.dart';
import '../../domain/entities/name_animation.dart';

class AnimatedNameAnimalEffect extends ConsumerStatefulWidget {
  final NameAnimation? animation;
  final double? width;
  final double? height;

  const AnimatedNameAnimalEffect({
    super.key,
    required this.animation,
    this.width,
    this.height,
  });

  @override
  ConsumerState<AnimatedNameAnimalEffect> createState() => _AnimatedNameAnimalEffectState();
}

class _AnimatedNameAnimalEffectState extends ConsumerState<AnimatedNameAnimalEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.animation?.durationMs ?? 1800).clamp(1200, 2400)),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _effectWrapper(Widget child, double width, double height) {
    final effect = widget.animation?.renderEffect ?? 'float_glow';
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = _controller.value * math.pi * 2;
        // Each render_effect gets its own distinct motion signature rather
        // than sharing one curve — this is what makes the admin's effect
        // picker (none / float_glow / bounce_glow) actually mean something.
        var dy = 0.0;
        var scaleX = 1.0;
        var scaleY = 1.0;
        var rotation = 0.0;
        var glowAlpha = 0.0;
        var glowBlur = 7.0;

        if (effect == 'float_glow') {
          // Gentle, symmetric up/down float with a soft breathing glow.
          dy = math.sin(phase) * math.max(0.8, height * 0.055);
          final s = 1.0 + math.cos(phase) * 0.018;
          scaleX = s;
          scaleY = s;
          glowAlpha = 0.12 + ((math.sin(phase) + 1) * 0.035);
        } else if (effect == 'bounce_glow') {
          // Sharper double-hop bounce with squash-and-stretch and a light
          // wobble, so it reads as energetic rather than a slow float.
          final bounce = math.sin(phase).abs();
          dy = -bounce * math.max(1.2, height * 0.16);
          scaleY = 0.88 + bounce * 0.22;
          scaleX = 1.12 - bounce * 0.12;
          rotation = math.sin(phase * 0.5) * 0.05;
          glowAlpha = 0.10 + bounce * 0.12;
          glowBlur = 9;
        }

        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(0, dy),
                child: Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(
                    scaleX: scaleX,
                    scaleY: scaleY,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: glowAlpha <= 0
                            ? const []
                            : [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: glowAlpha),
                                  blurRadius: glowBlur,
                                  spreadRadius: 0.4,
                                ),
                              ],
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
              if (effect != 'none')
                IgnorePointer(
                  child: CustomPaint(
                    painter: _AnimalSparklePainter(progress: _controller.value, energetic: effect == 'bounce_glow'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.animation;
    if (a == null || !a.isActive || a.key.trim().isEmpty) return const SizedBox.shrink();
    final boxW = (widget.width ?? a.maxWidth).clamp(24.0, 46.0).toDouble();
    final boxH = (widget.height ?? a.maxHeight).clamp(18.0, 32.0).toDouble();
    final bytesAsync = ref.watch(nameAnimationAssetBytesProvider(a));
    final isGif = a.animationType.toLowerCase().contains('gif') ||
        (a.storagePath?.toLowerCase().endsWith('.gif') ?? false);
    if (!isGif) return const SizedBox.shrink();
    return SizedBox(
      width: boxW,
      height: boxH,
      child: bytesAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (Uint8List? bytes) {
          if (bytes == null || bytes.isEmpty) return const SizedBox.shrink();
          return _effectWrapper(
            Image.memory(
              bytes,
              width: boxW,
              height: boxH,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            boxW,
            boxH,
          );
        },
      ),
    );
  }
}

/// Places the animal above the username without increasing the username row's layout height.
/// The parent gets the same footprint it had without the animal.
class AnimatedNameAnimalAboveName extends StatelessWidget {
  final NameAnimation? animation;
  final Widget name;
  final double gap;
  /// Proportional scale taken from the user's chosen username font size, so
  /// the animal shrinks/grows together with the rest of the name composition
  /// (template, frame, background) instead of staying a fixed size above a
  /// smaller name.
  final double scale;

  const AnimatedNameAnimalAboveName({
    super.key,
    required this.animation,
    required this.name,
    this.gap = 1,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final a = animation;
    if (a == null || !a.isActive || a.key.trim().isEmpty) return name;
    final s = scale.clamp(0.55, 2.0).toDouble();
    final w = (a.maxWidth.clamp(24.0, 46.0)).toDouble() * s;
    final h = (a.maxHeight.clamp(18.0, 32.0)).toDouble() * s;
    // كان `h + gap*s` يرفع الحيوان بارتفاعه كاملًا فوق حافة الاسم،
    // فيطفو بعيدًا وتظهر فجوة كبيرة بينه وبين الاسم. نُبقي ثلثه
    // متداخلًا مع الاسم فيجلس فوقه مباشرة كما في مواقع الشات.
    final overlayHeight = h * 0.68 + gap * s;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        name,
        Positioned(
          left: 0,
          right: 0,
          bottom: overlayHeight,
          child: IgnorePointer(
            child: Center(
              child: SizedBox(
                width: w,
                height: h,
                child: AnimatedNameAnimalEffect(animation: a, width: w, height: h),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimalSparklePainter extends CustomPainter {
  final double progress;
  final bool energetic;
  const _AnimalSparklePainter({required this.progress, this.energetic = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final phase = progress * math.pi * 2;
    final paint = Paint()..style = PaintingStyle.fill;
    final points = <Offset>[
      Offset(size.width * .18, size.height * (.22 + .08 * math.sin(phase))),
      Offset(size.width * .80, size.height * (.34 + .06 * math.sin(phase + 2.1))),
      Offset(size.width * .61, size.height * (.80 + .04 * math.sin(phase + 4.0))),
    ];
    // bounce_glow gets a 4th, slightly brighter sparkle so it reads as
    // more energetic than the calmer float_glow twinkle.
    if (energetic) {
      points.add(Offset(size.width * .38, size.height * (.55 + .10 * math.sin(phase + 3.1))));
    }
    for (var i = 0; i < points.length; i++) {
      final boost = energetic ? 0.05 : 0.0;
      final alpha = .13 + boost + .08 * ((math.sin(phase + i * 1.7) + 1) / 2);
      paint.color = Colors.white.withValues(alpha: alpha);
      final r = i == 1 ? 1.2 : 0.9;
      canvas.drawCircle(points[i], r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnimalSparklePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.energetic != energetic;
}
