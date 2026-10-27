import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// فلاتر الصور: تعريفها من الخادم، وتطبيقها على الجهاز، وخَبزها في
/// الملف قبل الرفع.
///
/// تقسيم العمل مقصود:
///  • **التعريف خادمي**: الاسم والترتيب والسعر ومعاملات اللون كلّها في
///    `media_filter_catalog`. فإضافة فلتر أو تعديله أو منعه لا تستلزم
///    نسخة جديدة من التطبيق ولا تحديثًا من المستخدمين.
///  • **الرسم على الجهاز**: لا سبيل غيره — معالجة الصورة تجري على وحدة
///    الرسوميات حيث الصورة موجودة.
///  • **الخَبز قبل الرفع**: الصورة المحفوظة تحمل الفلتر مخبوزًا فيها،
///    فما يراه الناس هو ما رآه الناشر بالضبط. البديل — حفظ اسم الفلتر
///    وإعادة تطبيقه عند العرض — يجعل الصورة تختلف بين جهاز وجهاز وبين
///    نسخة ونسخة، وتعود صورة قديمة بلا فلتر إن حُذف الفلتر من الكتالوج.
@immutable
class MediaFilter {
  const MediaFilter({
    required this.key,
    required this.name,
    required this.emoji,
    required this.kind,
    required this.params,
    this.premium = false,
  });

  final String key;
  final String name;
  final String emoji;

  /// color = يُعدِّل ألوان الصورة · background = خلفية تُرسَم تحتها
  final String kind;
  final Map<String, dynamic> params;
  final bool premium;

  bool get isNone => key == 'none';
  bool get isBackground => kind == 'background';

  static MediaFilter fromJson(Map<String, dynamic> j) => MediaFilter(
        key: j['key']?.toString() ?? 'none',
        name: j['name']?.toString() ?? '',
        emoji: j['emoji']?.toString() ?? '🎨',
        kind: j['kind']?.toString() ?? 'color',
        params: j['params'] is Map
            ? Map<String, dynamic>.from(j['params'] as Map)
            : const {},
        premium: j['premium'] == true,
      );

  static const none = MediaFilter(
      key: 'none', name: 'بلا فلتر', emoji: '🚫', kind: 'color', params: {});

  double _d(String k, double fallback) {
    final v = params[k];
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? fallback;
  }

  /// مصفوفة ألوان 4×5 كما يطلبها [ColorFilter.matrix].
  ///
  /// تُبنى من معاملات الخادم لا من ثوابت في الشيفرة، فتعديل شدّة فلتر
  /// من لوحة المالك يسري بلا بناء.
  List<double>? colorMatrix() {
    if (isBackground || isNone) return null;
    final preset = params['preset']?.toString() ?? 'none';

    switch (preset) {
      case 'none':
        return null;

      case 'saturate':
        return _saturation(_d('saturation', 1.0),
            brightness: _d('brightness', 1.0));

      case 'brightness':
        final b = _d('brightness', 1.0);
        return <double>[
          b, 0, 0, 0, 0,
          0, b, 0, 0, 0,
          0, 0, b, 0, 0,
          0, 0, 0, 1, 0,
        ];

      case 'contrast':
        final c = _d('contrast', 1.0);
        // t يُحافظ على المنتصف الرمادي ثابتًا، وإلّا أظلم التباين الصورة
        final t = (1 - c) * 127.5;
        final sat = _d('saturation', 1.0);
        final base = <double>[
          c, 0, 0, 0, t,
          0, c, 0, 0, t,
          0, 0, c, 0, t,
          0, 0, 0, 1, 0,
        ];
        if (sat == 1.0) return base;
        return _compose(_saturation(sat), base);

      case 'sepia':
        return const <double>[
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0, 0, 0, 1, 0,
        ];

      case 'warm':
      case 'cool':
        final r = _d('r', 1.0), g = _d('g', 1.0), b = _d('b', 1.0);
        return <double>[
          r, 0, 0, 0, 0,
          0, g, 0, 0, 0,
          0, 0, b, 0, 0,
          0, 0, 0, 1, 0,
        ];

      default:
        return null;
    }
  }

  ColorFilter? colorFilter() {
    final m = colorMatrix();
    return m == null ? null : ColorFilter.matrix(m);
  }

  /// تدرّج الخلفية لفلاتر الخلفية.
  Gradient? backgroundGradient() {
    if (!isBackground) return null;
    final c1 = _hex(params['color1']) ?? const Color(0xFF1A0F33);
    final c2 = _hex(params['color2']) ?? const Color(0xFF0B0718);
    final mode = params['mode']?.toString() ?? 'linear';
    if (mode == 'radial') {
      return RadialGradient(colors: [c1, c2], radius: .95);
    }
    return LinearGradient(
      colors: [c1, c2],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
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

  static List<double> _saturation(double s, {double brightness = 1.0}) {
    // أوزان اللمعان القياسية (Rec. 601) — استعمال 1/3 لكل قناة يُنتج
    // رماديًّا خاطئًا يبدو الأخضر فيه باهتًا.
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final b = brightness;
    return <double>[
      ((1 - s) * lr + s) * b, ((1 - s) * lg) * b, ((1 - s) * lb) * b, 0, 0,
      ((1 - s) * lr) * b, ((1 - s) * lg + s) * b, ((1 - s) * lb) * b, 0, 0,
      ((1 - s) * lr) * b, ((1 - s) * lg) * b, ((1 - s) * lb + s) * b, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  /// ضرب مصفوفتين 4×5 (تطبيق b ثم a).
  static List<double> _compose(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        out[row * 5 + col] = sum;
      }
      var off = a[row * 5 + 4];
      for (var k = 0; k < 4; k++) {
        off += a[row * 5 + k] * b[k * 5 + 4];
      }
      out[row * 5 + 4] = off;
    }
    return out;
  }

  /// يَخبِز الفلتر في بايتات الصورة (PNG) بلا أي حزمة خارجية.
  ///
  /// يُرسَم بـdart:ui نفسها التي رسمت المعاينة، فالناتج مطابق لما رآه
  /// الناشر — لا تقريبٌ بمكتبة أخرى بحسابات ألوان مختلفة.
  static Future<Uint8List> bake(Uint8List source, MediaFilter filter) async {
    final cm = filter.colorMatrix();
    final grad = filter.backgroundGradient();
    if (cm == null && grad == null) return source;

    final codec = await ui.instantiateImageCodec(source);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final w = img.width, h = img.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder,
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    if (grad != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()
          ..shader = grad.createShader(
              Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble())),
      );
    }

    final paint = Paint();
    if (cm != null) paint.colorFilter = ColorFilter.matrix(cm);
    canvas.drawImage(img, Offset.zero, paint);

    final picture = recorder.endRecording();
    final out = await picture.toImage(w, h);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);

    img.dispose();
    out.dispose();
    picture.dispose();

    // فشل الترميز يُعيد الأصل: صورة بلا فلتر أهون من نشر لا يكتمل.
    return data?.buffer.asUint8List() ?? source;
  }
}

/// كتالوج الفلاتر من الخادم.
final mediaFiltersProvider = FutureProvider<List<MediaFilter>>((ref) async {
  try {
    final raw = await Supabase.instance.client.rpc('get_media_filters');
    if (raw is! List) return const [MediaFilter.none];
    final list = raw
        .whereType<Map>()
        .map((e) => MediaFilter.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list.isEmpty ? const [MediaFilter.none] : list;
  } catch (_) {
    // بلا كتالوج يبقى النشر ممكنًا بلا فلتر: تعذُّر جلب الفلاتر لا
    // يصحّ أن يمنع نشر إعلان.
    return const [MediaFilter.none];
  }
});
