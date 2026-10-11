import 'dart:async';

import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../monitoring/error_monitor.dart';
import 'youtube_origin.dart';

/// تشخيص مشغّل يوتيوب من الجهاز الحقيقي.
///
/// ثلاث محاولات على إعداد المشغّل بُنيت على استنتاج لا على دليل، لأن
/// المشغّل لا يرمي أي استثناء حين يفشل العرض — يبقى صامتًا. هذا يُبلِّغ
/// الخادم (client_error_logs) بما يقوله يوتيوب نفسه:
///   • YT_ERROR  — رمز خطأ يوتيوب الحقيقي (2/5/100/101/150/152…).
///   • YT_STATE  — أول وصول لكل حالة (unStarted/buffering/playing…)،
///     فنعرف هل بدأ التشغيل فعلًا أم توقّف قبله.
/// كل رسالة تحمل videoId والـorigin المستعمل، فلا يبقى شيء للتخمين.
StreamSubscription<YoutubePlayerValue> attachYoutubeDiagnostics(
  YoutubePlayerController controller, {
  required String videoId,
  required String where,
}) {
  final seenStates = <PlayerState>{};
  var errorReported = false;
  return controller.stream.listen((v) {
    if (v.hasError && !errorReported) {
      errorReported = true;
      unawaited(ErrorMonitor.report(
        'YT_ERROR where=$where video=$videoId error=${v.error} '
        'origin=$kYoutubeEmbedOrigin',
        source: 'youtube_player',
        severity: 'warning',
      ));
    }
    if (seenStates.add(v.playerState)) {
      unawaited(ErrorMonitor.report(
        'YT_STATE where=$where video=$videoId state=${v.playerState.name} '
        'origin=$kYoutubeEmbedOrigin',
        source: 'youtube_player',
        severity: 'info',
      ));
    }
  }, onError: (Object e, StackTrace st) {
    unawaited(ErrorMonitor.report(
      'YT_STREAM_EXCEPTION where=$where video=$videoId $e',
      stack: st,
      source: 'youtube_player',
      severity: 'warning',
    ));
  });
}
