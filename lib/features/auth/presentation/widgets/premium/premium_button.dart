import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// زر ذهبي فاخر: لمعان معدني دوري (Metallic Shimmer) يمر مائلًا كل
/// بضع ثوانٍ، ارتفاع + توهج عند الضغط المطوّل (Press Feedback عبر
/// GestureDetector)، وانضغاط خفيف (scale 0.98) عند النقر، وتحوّل
/// سلس للنص إلى مؤشر تحميل دائري أثناء المعالجة.
class PremiumButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PremiumButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.isLoading = false});

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();
  bool _pressed = false;

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
                colors: [p.accentMuted, p.accent, p.accentBright]),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: p.accent.withValues(alpha: _pressed ? 0.45 : 0.28),
                      blurRadius: _pressed ? 26 : 16,
                      spreadRadius: _pressed ? 1 : 0,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (enabled)
                  AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, _) {
                      final t = _shimmerController.value;
                      return Positioned.fill(
                        child: FractionalTranslation(
                          translation: Offset(t * 3 - 1.5, 0),
                          child: Transform.rotate(
                            angle: -0.5,
                            child: Container(
                              width: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.35),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  // زر تحميل بسيط وواضح بدل مؤشر الإبرة بروح الخياطة.
                  child: widget.isLoading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.black87),
                        )
                      : Text(
                          widget.label,
                          key: const ValueKey('label'),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
