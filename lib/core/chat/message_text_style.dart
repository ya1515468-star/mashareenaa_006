import 'package:flutter/material.dart';

import '../services/server_fonts.dart';

/// تنسيق نص الرسالة كما يحدّده الخادم، في مكان واحد.
///
/// لماذا موحَّد: كان كل سطح يستنتج اللون والخط بنفسه — صفّ الغرفة،
/// وفقاعة الخاص، والسطر المضمَّن — بثلاث قراءات مختلفة لنفس الحقول.
/// فظهر اللون في موضع وغاب في آخر، وتعذّر معرفة أيّ السطوح على حقّ.
/// الآن مصدر واحد: ما يرجعه `get_user_chat_identity` يُفسَّر هنا فقط.
///
/// والألوان المتدرّجة (72 لونًا في الكتالوج، منها عشرون مدمجة بلونين)
/// كانت تُرسَم بلون واحد مسطّح لأنّ `message_color_2` لم يُقرأ قطّ —
/// أي أنّ العضو يشتري تدرّجًا فيحصل على نصف ما رآه في المتجر.
@immutable
class MessageTextStyle {
  const MessageTextStyle({
    required this.color,
    this.gradientTo,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.scale = 1.0,
    this.letterSpacing = 0.0,
    this.fontFamily,
  });

  final Color color;

  /// اللون الثاني للتدرّج، أو null للون مسطّح.
  final Color? gradientTo;

  final bool bold;
  final bool italic;
  final bool underline;
  final double scale;
  final double letterSpacing;
  final String? fontFamily;

  bool get isGradient => gradientTo != null;

  /// اللون الافتراضي يُمرَّر من السطح: الغرف على خلفية فاتحة والخاص على
  /// غامقة، فلا يصحّ ثابتٌ واحد هنا.
  static MessageTextStyle fromIdentity(
    Map<String, dynamic>? identity, {
    required Color fallbackColor,
  }) {
    if (identity == null) return MessageTextStyle(color: fallbackColor);

    final c1 = _hex(identity['message_color_1']);
    final c2 = _hex(identity['message_color_2']);
    final legacy = int.tryParse('${identity['message_color'] ?? ''}');

    // 4294967295 = أبيض معتم، وهو الافتراضي في القاعدة أي «بلا اختيار»
    // لا «اختار الأبيض» — فاعتباره اختيارًا يطمس النص على خلفية فاتحة.
    final color = c1 ??
        ((legacy != null && legacy != 4294967295)
            ? Color(legacy)
            : fallbackColor);

    final key = identity['message_font_key']?.toString();
    final family = (key != null && key.isNotEmpty && ServerFonts.isLoaded(key))
        ? ServerFonts.family(key)
        : null;

    return MessageTextStyle(
      color: color,
      // التدرّج لا يُطبَّق إلّا إن كان اللون الأول من الكتالوج أيضًا:
      // لونٌ ثانٍ فوق لون احتياطي يعطي تدرّجًا لم يختره أحد.
      gradientTo: c1 == null ? null : c2,
      bold: identity['message_bold'] == true,
      italic: identity['message_italic'] == true,
      underline: identity['message_underline'] == true,
      scale: _d(identity['message_font_scale'], 1.0, min: 0.80, max: 1.60),
      letterSpacing:
          _d(identity['message_letter_spacing'], 0.0, min: 0.0, max: 4.0),
      fontFamily: family,
    );
  }

  /// نفس المنطق لكن من `get_my_message_style` (مفاتيح بلا السابقة
  /// `message_`) — تستعمله المعاينة قبل أن يرسل العضو أي رسالة.
  static MessageTextStyle fromMyStyle(
    Map<String, dynamic>? s, {
    required Color fallbackColor,
  }) {
    if (s == null) return MessageTextStyle(color: fallbackColor);
    return fromIdentity({
      'message_color_1': s['color_1'],
      'message_color_2': s['color_2'],
      'message_color': s['color'],
      'message_bold': s['bold'],
      'message_italic': s['italic'],
      'message_underline': s['underline'],
      'message_font_scale': s['font_scale'],
      'message_letter_spacing': s['letter_spacing'],
      'message_font_key': s['font_key'],
    }, fallbackColor: fallbackColor);
  }

  MessageTextStyle copyWith({
    Color? color,
    Color? gradientTo,
    bool clearGradient = false,
    bool? bold,
    bool? italic,
    bool? underline,
    double? scale,
    double? letterSpacing,
    String? fontFamily,
    bool clearFontFamily = false,
  }) {
    return MessageTextStyle(
      color: color ?? this.color,
      gradientTo: clearGradient ? null : (gradientTo ?? this.gradientTo),
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      scale: scale ?? this.scale,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      fontFamily: clearFontFamily ? null : (fontFamily ?? this.fontFamily),
    );
  }

  TextStyle toTextStyle({required double baseFontSize, double? height}) {
    return TextStyle(
      color: color,
      fontSize: baseFontSize * scale,
      fontWeight: bold ? FontWeight.w900 : FontWeight.w400,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      decoration: underline ? TextDecoration.underline : TextDecoration.none,
      decorationColor: color,
      letterSpacing: letterSpacing == 0 ? null : letterSpacing,
      fontFamily: fontFamily,
      height: height,
    );
  }

  static Color? _hex(Object? v) {
    final s = v?.toString().replaceAll('#', '').trim() ?? '';
    if (s.length == 6) {
      final n = int.tryParse('FF$s', radix: 16);
      return n == null ? null : Color(n);
    }
    if (s.length == 8) {
      final n = int.tryParse(s, radix: 16);
      return n == null ? null : Color(n);
    }
    return null;
  }

  static double _d(Object? v, double fallback,
      {required double min, required double max}) {
    final d = double.tryParse('${v ?? ''}');
    if (d == null) return fallback;
    return d.clamp(min, max);
  }
}

/// نص الرسالة مرسومًا بتنسيقه، متدرّجًا كان أو مسطّحًا.
///
/// التدرّج يُرسَم بـShaderMask لا بلونين متبادلين: التدرّج على النص
/// نفسه هو ما يراه العضو في المتجر، فأي تقريب آخر يجعل ما اشتراه
/// مختلفًا عمّا ظهر له.
class MessageText extends StatelessWidget {
  const MessageText({
    super.key,
    required this.text,
    required this.style,
    required this.baseFontSize,
    this.height,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final MessageTextStyle style;
  final double baseFontSize;
  final double? height;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final ts = style.toTextStyle(baseFontSize: baseFontSize, height: height);
    final to = style.gradientTo;
    if (to == null) {
      return Text(
        text,
        style: ts,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: [style.color, to],
        begin: Alignment.centerRight, // عربي: يبدأ من حيث يبدأ النص
        end: Alignment.centerLeft,
      ).createShader(bounds),
      child: Text(
        text,
        style: ts.copyWith(color: Colors.white, decorationColor: Colors.white),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}
