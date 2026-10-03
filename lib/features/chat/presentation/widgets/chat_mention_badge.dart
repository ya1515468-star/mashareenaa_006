import 'package:flutter/material.dart';

/// Unified visual treatment for chat mentions.
/// The stored token may contain '@', but the rendered badge never shows it.
class ChatMentionBadge extends StatelessWidget {
  final String name;
  final double fontSize;

  const ChatMentionBadge({
    super.key,
    required this.name,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final label = name.trim().replaceFirst(RegExp(r'^@'), '');
    return ClipPath(
      clipper: const _BrokenCornerClipper(cut: 5),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF1976D2),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(9, 3, 9, 3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: .28),
                width: .8,
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 1, 4, 1),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrokenCornerClipper extends CustomClipper<Path> {
  final double cut;

  const _BrokenCornerClipper({required this.cut});

  @override
  Path getClip(Size size) {
    final c = cut.clamp(2.0, 10.0).toDouble();
    return Path()
      ..moveTo(c, 0)
      ..lineTo(size.width - c, 0)
      ..lineTo(size.width, c)
      ..lineTo(size.width, size.height - c)
      ..lineTo(size.width - c, size.height)
      ..lineTo(c, size.height)
      ..lineTo(0, size.height - c)
      ..lineTo(0, c)
      ..close();
  }

  @override
  bool shouldReclip(covariant _BrokenCornerClipper oldClipper) =>
      oldClipper.cut != cut;
}
