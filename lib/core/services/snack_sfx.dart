import 'package:flutter/material.dart';

import 'server_sounds.dart';

/// يربط كل SnackBar في التطبيق بنغمة نجاح/خطأ من الخادم تلقائيًا.
/// التصنيف من نص الرسالة (أو لون الخلفية الأحمر)؛ الرسائل المحايدة بلا نغمة.
extension SnackSfx on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBarSfx(
      SnackBar bar) {
    final kind = classifySnack(bar);
    if (kind != null) playServerSound(kind);
    return showSnackBar(bar);
  }
}

const List<String> _errorWords = [
  'تعذّر', 'تعذر', 'فشل', 'خطأ', 'خطا', 'لا يمكن', 'لا يكفي', 'غير كاف',
  'غير مسموح', 'مرفوض', 'رُفض', 'انتهت', 'ليس دورك', 'ممتلئ', 'استنفدت',
  'لم يتم', 'لم يؤكد', 'غير صالح', 'غير متاح', 'ممنوع', 'Exception', 'error',
  'Error', 'failed', 'Failed',
];
const List<String> _okWords = ['✓', '✔', 'بنجاح', 'تم ', 'تمت', 'نجح', 'شكرًا', 'شكرا'];

/// 'error' | 'success' | null
String? classifySnack(SnackBar bar) {
  var text = '';
  final c = bar.content;
  if (c is Text) {
    text = c.data ?? c.textSpan?.toPlainText() ?? '';
  } else if (c is Row) {
    for (final w in c.children) {
      if (w is Text) text += ' ${w.data ?? ''}';
      if (w is Expanded && w.child is Text) text += ' ${(w.child as Text).data ?? ''}';
    }
  }
  final bg = bar.backgroundColor;
  if (bg != null) {
    final argb = bg.toARGB32();
    final r = (argb >> 16) & 255, g = (argb >> 8) & 255, b = argb & 255;
    if (r > 150 && g < 100 && b < 100) return 'error';
    if (g > 130 && r < 110 && b < 130) return 'success';
  }
  if (text.isEmpty) return null;
  for (final w in _errorWords) {
    if (text.contains(w)) return 'error';
  }
  for (final w in _okWords) {
    if (text.contains(w)) return 'success';
  }
  return null;
}
