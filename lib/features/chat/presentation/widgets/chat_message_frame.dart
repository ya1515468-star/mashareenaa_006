import 'package:flutter/material.dart';

/// إطار حديث وخفيف لرسائل الغرف.
/// يتكيّف مع حجم المحتوى بدل فرض مستطيل عريض، ويحافظ على التباين
/// المناسب للنص العربي والإنكليزي داخل غرف الدردشة.
class ChatMessageFrame extends StatelessWidget {
  final Widget child;
  final bool silver;

  const ChatMessageFrame({
    super.key,
    required this.child,
    required this.silver,
  });

  @override
  Widget build(BuildContext context) {
    final palette = silver
        ? const _FramePalette(
            border: Color(0xFF8C96A6),
            borderBright: Color(0xFFDCE3EC),
            fillTop: Color(0xFFF8FAFD),
            fillBottom: Color(0xFFE7ECF3),
            glow: Color(0xFFFFFFFF),
          )
        : const _FramePalette(
            border: Color(0xFF8E6407),
            borderBright: Color(0xFFF3CC62),
            fillTop: Color(0xFFFFF4C8),
            fillBottom: Color(0xFFEFC358),
            glow: Color(0xFFFFFFFF),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.fillTop, palette.fillBottom],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: palette.borderBright.withValues(alpha: .80),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: CustomPaint(
          painter: _ChatMessageFramePainter(
            border: palette.border,
            glow: palette.glow,
          ),
          // كان يُرسم هنا خيط متقطّع حول الإطار (روح الخياطة)، أُزيل بناءً
          // على طلب صريح — الإطار الملوّن وتوهجه يكفيان بلا أي زخرفة خيوط.
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 9),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ChatMessageFramePainter extends CustomPainter {
  final Color border;
  final Color glow;

  const _ChatMessageFramePainter({
    required this.border,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 2 || size.height <= 2) return;

    final topGlow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          glow.withValues(alpha: .24),
          glow.withValues(alpha: .04),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * .55));

    final highlight = RRect.fromRectAndRadius(
      Rect.fromLTWH(.8, .8, size.width - 1.6, size.height * .42),
      const Radius.circular(16),
    );
    canvas.drawRRect(highlight, topGlow);

    final edge = Paint()
      ..color = border.withValues(alpha: .38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;

    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(.8, .8, size.width - 1.6, size.height - 1.6),
      const Radius.circular(16),
    );
    canvas.drawRRect(inner, edge);
  }

  @override
  bool shouldRepaint(covariant _ChatMessageFramePainter oldDelegate) =>
      oldDelegate.border != border || oldDelegate.glow != glow;
}

class _FramePalette {
  final Color border;
  final Color borderBright;
  final Color fillTop;
  final Color fillBottom;
  final Color glow;

  const _FramePalette({
    required this.border,
    required this.borderBright,
    required this.fillTop,
    required this.fillBottom,
    required this.glow,
  });
}
