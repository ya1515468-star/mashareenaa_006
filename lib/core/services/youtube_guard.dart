import 'package:supabase_flutter/supabase_flutter.dart';

/// نتيجة فحص خادمي لفيديو يوتيوب قبل تشغيله.
class YoutubeResolution {
  /// المعرّف الذي يجب تشغيله فعليًا (الأصلي أو بديل قابل للتضمين).
  final String videoId;
  final String? title;
  final bool embeddable;
  final bool replaced;
  const YoutubeResolution(this.videoId,
      {this.title, this.embeddable = true, this.replaced = false});
}

/// بعض الفيديوهات (غالبًا الأغاني الرسمية) يمنع صاحبها تضمينها خارج يوتيوب،
/// فيظهر "This video is unavailable — 152". الدالة الخادمية youtube-check
/// تفحص القابلية عبر oEmbed وتبحث عن نسخة بديلة قابلة للتضمين بنفس العنوان.
/// أي فشل في الفحص (بلا اتصال…) يعيد المعرّف الأصلي دون تعطيل التشغيل.
class YoutubeGuard {
  YoutubeGuard._();
  static final Map<String, Future<YoutubeResolution>> _cache = {};

  static Future<YoutubeResolution> resolve(String videoId, String title) {
    return _cache.putIfAbsent(videoId, () async {
      try {
        final res = await Supabase.instance.client.functions
            .invoke('youtube-check', body: {'videoId': videoId, 'title': title});
        final d = res.data;
        if (d is Map) {
          final emb = d['embeddable'] != false;
          if (emb) return YoutubeResolution(videoId, title: d['title']?.toString());
          final alt = d['alternative'];
          if (alt is Map && (alt['videoId']?.toString().length ?? 0) == 11) {
            return YoutubeResolution(alt['videoId'].toString(),
                title: alt['title']?.toString(),
                embeddable: true,
                replaced: true);
          }
          return YoutubeResolution(videoId, embeddable: false);
        }
      } catch (_) {}
      return YoutubeResolution(videoId);
    });
  }
}
