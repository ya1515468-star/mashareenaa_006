import 'package:flutter/material.dart';

/// Compatibility wrapper that intentionally uses Flutter's default typography.
/// No custom font or remote fallback is injected here.
class LocalGlyphText extends StatelessWidget {
  const LocalGlyphText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection = TextDirection.rtl,
    this.softWrap = true,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection textDirection;
  final bool softWrap;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        softWrap: softWrap,
        maxLines: maxLines,
        overflow: overflow,
      );
}

List<InlineSpan> localGlyphSpans(String text, TextStyle base) => [
      TextSpan(text: text, style: base),
    ];

