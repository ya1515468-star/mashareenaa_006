import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/chat/message_text_style.dart';
import '../../../../core/services/server_fonts.dart';

/// مزوّد تنسيق رسائلي كما يحفظه الخادم.
///
/// الخادم هو المرجع لا الحالة المحلية: المعاينة التي تُبنى من اختيار لم
/// يُحفَظ بعد تُظهر شيئًا والغرف تُظهر غيره — وهي بالضبط شكوى «اخترت
/// ولا يظهر» من الجهة المقابلة.
final myMessageStyleProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final raw = await Supabase.instance.client.rpc('get_my_message_style');
  final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  final key = map['font_key']?.toString();
  if (key != null && key.isNotEmpty) {
    // التنزيل هنا لا في الرسم: المعاينة بلا الخط المحمَّل تُطمئن العضو
    // إلى خطّ ليس خطّه.
    await ServerFonts.ensure(key);
  }
  return map;
});

/// شريط معاينة أعلى قسم ألوان الرسائل وخطوطها.
///
/// يُظهر الرسالة بخطّ العضو وشكله ولونه ومتدرّجه وحجمه وتباعده كما
/// سيراها الآخرون في الغرف وفي الخاص — بالمُفسِّر نفسه الذي ترسم به
/// الغرف (MessageTextStyle)، لا بتقريب خاص بالمعاينة. أي اختلاف بين
/// المعاينة والغرفة يعني عطلًا في مكان واحد لا في مكانين.
class MessageStylePreviewBar extends ConsumerWidget {
  const MessageStylePreviewBar({super.key, this.sampleText});

  final String? sampleText;

  static const _sample = 'هكذا ستظهر رسالتك في الغرف والخاص ✨';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myMessageStyleProvider);

    return ValueListenableBuilder<int>(
      valueListenable: ServerFonts.revision,
      builder: (context, _, __) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF160C2C),
          border: Border.all(color: const Color(0x55FFD700)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(children: [
                const Icon(Icons.visibility_rounded,
                    size: 16, color: Color(0xFFFFD700)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('معاينة مباشرة',
                      style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  tooltip: 'تحديث',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => ref.invalidate(myMessageStyleProvider),
                  icon: const Icon(Icons.refresh_rounded,
                      size: 16, color: Colors.white54),
                ),
              ]),
            ),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(22),
                child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(14),
                child: Text('تعذّر جلب تنسيقك: $e',
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 11)),
              ),
              data: (raw) => _body(context, raw),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> raw) {
    final text = sampleText ?? _sample;

    // خلفيتان عمدًا: الغرف تُرسم على فاتح والخاص على غامق، ولون قد
    // يُقرأ على إحداهما ويغيب على الأخرى — فإظهار واحدة فقط يخفي
    // نصف الحقيقة.
    final roomStyle = MessageTextStyle.fromMyStyle(raw,
        fallbackColor: const Color(0xFF1E293B));
    final dmStyle =
        MessageTextStyle.fromMyStyle(raw, fallbackColor: Colors.white);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _surface(
          label: 'في الغرف',
          background: const Color(0xFFF1F5F9),
          child: MessageText(
            text: text,
            style: roomStyle,
            baseFontSize: 14,
            height: 1.4,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(height: 8),
        _surface(
          label: 'في الخاص',
          background: const Color(0xFF0E1526),
          child: MessageText(
            text: text,
            style: dmStyle,
            baseFontSize: 14,
            height: 1.4,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(height: 10),
        _details(raw, roomStyle),
      ]),
    );
  }

  Widget _surface({
    required String label,
    required Color background,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label,
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: background.computeLuminance() > .5
                    ? const Color(0xFF64748B)
                    : Colors.white38)),
        const SizedBox(height: 4),
        Directionality(textDirection: TextDirection.rtl, child: child),
      ]),
    );
  }

  /// تفاصيل التنسيق مكتوبة: بلا سردها لا يعرف العضو أنّ ما يراه ناتج
  /// خطٍّ بعينه ومقياسٍ بعينه، فيعجز عن تغيير ما لا يعرف اسمه.
  Widget _details(Map<String, dynamic> raw, MessageTextStyle st) {
    final fontKey = raw['font_key']?.toString();
    final fontName = (fontKey == null || fontKey.isEmpty)
        ? (raw['font_family']?.toString().isNotEmpty == true
            ? '${raw['font_family']}'
            : 'الخط الافتراضي')
        : fontKey;

    final chips = <(String, String)>[
      ('🔤', fontName),
      if (st.bold) ('🅱️', 'غامق'),
      if (st.italic) ('🖋️', 'مائل'),
      if (st.underline) ('⎁', 'تحته خط'),
      if (st.letterSpacing > 0)
        ('↔️', 'تعريض ${st.letterSpacing.toStringAsFixed(1)}'),
      if (st.scale != 1.0) ('🔎', 'حجم ×${st.scale.toStringAsFixed(2)}'),
      (
        '🎨',
        st.isGradient
            ? 'لون مدمَّج ${_hex(st.color)} ← ${_hex(st.gradientTo!)}'
            : 'لون ${_hex(st.color)}'
      ),
      if ((raw['color_key']?.toString() ?? '').isNotEmpty)
        ('🏷️', '${raw['color_key']}'),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (emoji, label) in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(emoji, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10.5, color: Colors.white70)),
            ]),
          ),
      ],
    );
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// يُبطِل معاينة التنسيق بعد أي حفظ خادمي، فتتحدّث فورًا.
void refreshMessageStylePreview(WidgetRef ref) {
  ref.invalidate(myMessageStyleProvider);
}
