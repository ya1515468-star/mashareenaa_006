import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'frame_effect_painter.dart';


/// Canonical avatar/frame compositor.
///
/// The opening geometry is measured when the frame is uploaded and persisted
/// with the catalog record. Rendering uses that geometry so the avatar edge
/// follows the actual inner opening of the artwork instead of a guessed
/// padding value. The frame is always the top-most layer.
class AvatarFrameComposite extends StatefulWidget {
  final Widget avatar;
  final ImageProvider frame;
  final double size;
  final double frameScale;
  final double framePadding;
  final bool animateEffect;
  final double innerOpeningRatio;
  final double innerCenterX;
  final double innerCenterY;
  final String effect;

  const AvatarFrameComposite({
    super.key,
    required this.avatar,
    required this.frame,
    required this.size,
    this.frameScale = 1.0,
    this.framePadding = 0,
    this.animateEffect = true,
    this.innerOpeningRatio = 0.74,
    this.innerCenterX = 0.5,
    this.innerCenterY = 0.5,
    this.effect = 'pulse_glow',
  });

  @override
  State<AvatarFrameComposite> createState() => _AvatarFrameCompositeState();
}

class _AvatarFrameCompositeState extends State<AvatarFrameComposite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.innerOpeningRatio.clamp(0.45, 0.94).toDouble();
    final scale = widget.frameScale.clamp(0.55, 0.86).toDouble();
    // The frame artwork defines its own footprint. Do not add an extra
    // circular margin/padding around it; this was the source of the
    // visible halo above/beyond the actual frame artwork.
    final baseFrameSize = math.max(
      widget.size,
      widget.size / ratio,
    ).toDouble();

    // Scale the complete composition, not the frame artwork alone. The avatar
    // must shrink with the frame so it always remains inside the real opening
    // when the server-controlled visual level is reduced.
    final frameSize = (baseFrameSize * scale).toDouble();
    final avatarSize = (frameSize * ratio).toDouble();
    final centerX = widget.innerCenterX.clamp(0.08, 0.92).toDouble();
    final centerY = widget.innerCenterY.clamp(0.08, 0.92).toDouble();
    final avatarLeft = frameSize * centerX - avatarSize / 2;
    final avatarTop = frameSize * centerY - avatarSize / 2;

    Widget frameLayer = SizedBox(
      width: frameSize,
      height: frameSize,
      child: Image(
        image: widget.frame,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );

    if (widget.animateEffect) {
      frameLayer = AnimatedBuilder(
        animation: _controller,
        builder: (_, child) {
          final t = _controller.value;
          final pulse = 1.0 + math.sin(t * math.pi * 2) * 0.012;
          return Transform.scale(scale: pulse, child: child);
        },
        child: frameLayer,
      );
    }

    // Do not draw the generic pulse ring on top of the real frame artwork.
    // That ring was the unwanted outer halo visible above/beyond the frame.
    // Other explicit frame effects remain available.
    final showVectorEffect = widget.effect.trim().toLowerCase() != 'pulse_glow';
    final effectLayer = showVectorEffect
        ? _FrameEffectLayer(
            effect: widget.effect,
            progress: _controller,
            size: frameSize,
          )
        : const SizedBox.shrink();

    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: Stack(
        key: const ValueKey<String>('avatar-frame-stack'),
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: avatarLeft,
            top: avatarTop,
            width: avatarSize,
            height: avatarSize,
            child: ClipOval(child: widget.avatar),
          ),
          Positioned.fill(child: IgnorePointer(child: frameLayer)),
          Positioned.fill(child: IgnorePointer(child: effectLayer)),
        ],
      ),
    );
  }
}


class _FrameEffectLayer extends StatelessWidget {
  final String effect;
  final Animation<double> progress;
  final double size;
  const _FrameEffectLayer({required this.effect, required this.progress, required this.size});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: progress,
        builder: (_, __) => CustomPaint(
          size: Size.square(size),
          painter: FrameEffectPainter(effect: effect, t: progress.value),
        ),
      );
}
