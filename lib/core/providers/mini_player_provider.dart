import 'package:flutter_riverpod/flutter_riverpod.dart';

/// فيديو يوتيوب قيد التشغيل حالياً في المشغّل المصغّر العائم. null = لا شيء
/// يُشغَّل، فيختفي الشريط. القيمة الوحيدة (لا قائمة) لأن المطلوب مشغّل واحد
/// عائم فقط، لا قائمة انتظار.
class MiniPlayerTrack {
  final String videoId;
  final String title;
  const MiniPlayerTrack({required this.videoId, required this.title});
}

final miniPlayerProvider = StateProvider<MiniPlayerTrack?>((ref) => null);

/// true = النافذة العائمة مصغَّرة: لا نافذة ولا شريط، فقط أيقونة تشغيل
/// صغيرة بجانب زر السمايل في شريط الكتابة (MiniPlayerChip)، والصوت يستمر.
final miniPlayerMinimizedProvider = StateProvider<bool>((ref) => false);
