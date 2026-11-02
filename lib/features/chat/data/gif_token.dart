/// رمز السمايل المتحرك داخل نص الرسالة.
///
/// حقل النص في Flutter يرسم نصًّا فقط ولا يرسم صورًا، فلا يستطيع السمايل
/// المتحرك أن يسكن النص كما يسكنه حرف الإيموجي. الحلّ: يُدرَج رمز نصي
/// قصير عند موضع المؤشر، وتُحفَظ المسارات في `metadata.gif_urls`، ويستبدل
/// العارض كل رمز بصورته. هكذا يُحفَظ موضع السمايل بين الكلمات فعلًا:
/// «مرحبا [g1] كيفك» تُعرَض «مرحبا 🙂 كيفك» — بدل أن تتجمّع السمايلات
/// في طرف الفقاعة بلا مكان.
///
/// الرمز ASCII بحتًا بلا أي محرف نادر، فلا خطر أن يغيب الحرف من الخط
/// ويظهر مربّعًا فارغًا. ورمز لا يقابله مسار يُعرض نصًّا كما كُتب، فلا
/// ينهار شيء إن كتبه المستخدم بيده.
library;

/// يطابق `[g1]`، `[g2]` … والرقم هو موضع المسار في `gif_urls` (1-based).
final RegExp gifTokenPattern = RegExp(r'\[g(\d+)\]');

String gifToken(int id) => '[g$id]';

/// نص الرسالة بعد إعادة الترقيم، مع قائمة المسارات بترتيب ظهورها.
class GifNormalizedMessage {
  final String text;
  final List<String> urls;
  const GifNormalizedMessage({required this.text, required this.urls});
}

/// حالة السمايلات المعلّقة في صندوق الكتابة الواحد.
///
/// المصدر الوحيد للترتيب هو **النص نفسه** لا قائمة منفصلة: فحذف الرمز
/// بالـBackspace يُسقط سمايله تلقائيًا بلا أي مزامنة يدوية، وهذا ما يجعل
/// السلوك مطابقًا للإيموجي الثابت.
class GifComposerDraft {
  final Map<int, String> _paths = <int, String>{};
  int _next = 1;

  /// يسجّل مسارًا ويُعيد رمزه ليُدرَج في النص.
  String register(String assetPath) {
    final id = _next++;
    _paths[id] = assetPath;
    return gifToken(id);
  }

  /// المسارات بترتيب ظهور رموزها في [text] — لشريط المصغّرات فوق الحقل.
  List<String> pathsInTextOrder(String text) {
    final out = <String>[];
    for (final m in gifTokenPattern.allMatches(text)) {
      final path = _paths[int.parse(m.group(1)!)];
      if (path != null) out.add(path);
    }
    return out;
  }

  /// يحذف الرمز رقم [occurrence] (0-based حسب ترتيب الظهور) من [text] —
  /// لزر الحذف على مصغّرة بعينها.
  String removeOccurrence(String text, int occurrence) {
    final matches = gifTokenPattern.allMatches(text).toList();
    if (occurrence < 0 || occurrence >= matches.length) return text;
    final m = matches[occurrence];
    return text.replaceRange(m.start, m.end, '');
  }

  /// يُعيد ترقيم الرموز 1..N حسب ترتيبها في النص، فتصبح الرسالة المحفوظة
  /// مكتفية بنفسها: الرمز `[gi]` يقابل `gif_urls[i-1]` دائمًا، بلا اعتماد
  /// على عدّاد العميل الذي لا يعرفه المستقبِل.
  GifNormalizedMessage normalize(String text) {
    final urls = <String>[];
    final out = StringBuffer();
    var cursor = 0;
    for (final m in gifTokenPattern.allMatches(text)) {
      out.write(text.substring(cursor, m.start));
      final path = _paths[int.parse(m.group(1)!)];
      if (path != null) {
        urls.add(path);
        out.write(gifToken(urls.length));
      } else {
        // رمز مجهول: يبقى نصًّا كما كُتب.
        out.write(m.group(0));
      }
      cursor = m.end;
    }
    out.write(text.substring(cursor));
    return GifNormalizedMessage(text: out.toString(), urls: urls);
  }

  void clear() {
    _paths.clear();
    _next = 1;
  }
}

/// نص للعرض في المواضع التي لا تُرسَم فيها الصور (قائمة المحادثات،
/// معاينة الرد، إشعار): الرمز يُستبدَل بعلامة بدل أن يظهر خامًا.
String gifTokensToPlaceholder(String text, {String placeholder = '🙂'}) =>
    text.replaceAll(gifTokenPattern, placeholder);

/// هل النص بلا أي محتوى غير رموز السمايل؟ (رسالة سمايلات بحتة.)
bool isGifOnlyText(String text) =>
    text.trim().isNotEmpty &&
    text.replaceAll(gifTokenPattern, '').trim().isEmpty;
