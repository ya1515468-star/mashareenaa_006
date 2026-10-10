import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../providers/mini_player_provider.dart';
import '../services/youtube_guard.dart';

/// شريط عائم ثابت فوق التطبيق كله (يُركَّب في MaterialApp.builder في
/// main.dart، لا داخل أي شاشة)، فيبقى حيًّا عبر كل تنقّل — بين الغرف،
/// الخاص، وأقسام المنصة الأخرى — حتى يُغلَق يدويًا. هذا يحقّق "يستمر
/// بالتشغيل عند الانتقال" مع إبقاء مشغّل الفيديو المضمَّن داخل فقاعة
/// الرسالة نفسه محليًّا (يتوقف تلقائيًا بمغادرة تلك الشاشة بحكم دورة
/// حياة الودجت العادية؛ هذان مشغّلان منفصلان تمامًا لا يتداخلان).
///
/// حالتان بصريتان لمتحكّم واحد لا يُعاد بناؤه بين الحالتين (هذا ما يُبقي
/// الصوت متواصلًا بلا أي قطع عند التبديل):
/// - نافذة عائمة (الوضع الافتراضي عند بدء أي مقطع): بطاقة صغيرة فيها
///   الفيديو ظاهرًا فعليًا + زرّا "تصغير" و"إغلاق".
/// - مُصغَّرة: شريط أيقونة فقط (نفس تصميم الإصدار السابق) بعد الضغط على
///   "تصغير"؛ الفيديو يستمر بالتشغيل في الخلفية دون أي تغيير في المتحكّم،
///   والضغط على الشريط أو زر الاستعادة يعيدها نافذة عائمة من جديد.
/// "إغلاق" (✕) في كلتا الحالتين ينهي التشغيل كليًا ويُزيل الشريط.
// ملاحظة: هذا الودجت يُركَّب في MaterialApp.builder فوق Navigator، أي بلا
// أي Overlay سلف — لذلك لا يجوز استعمال tooltip في IconButton هنا (يرمي
// "No Overlay widget found" فينهار التخطيط كله ويظهر الصندوق الأحمر).
class GlobalMiniPlayer extends ConsumerStatefulWidget {
  const GlobalMiniPlayer({super.key});
  @override
  ConsumerState<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends ConsumerState<GlobalMiniPlayer> {
  YoutubePlayerController? _controller;
  String? _currentId;
  // فحص خادمي (youtube-check) قبل التشغيل: إن كان الفيديو ممنوع التضمين
  // يُستبدل بنسخة قابلة للتضمين بنفس العنوان بدل خطأ 152.
  final Map<String, YoutubeResolution> _resolved = {};
  String? _pendingId;

  void _syncController(MiniPlayerTrack? track) {
    if (track == null) {
      _controller?.close();
      _controller = null;
      _currentId = null;
      _pendingId = null;
      return;
    }
    final res = _resolved[track.videoId];
    if (res == null) {
      if (_pendingId != track.videoId) {
        _pendingId = track.videoId;
        final asked = track.videoId;
        unawaited(YoutubeGuard.resolve(asked, track.title).then((r) {
          _resolved[asked] = r;
          if (mounted) setState(() {});
        }));
      }
      return;
    }
    final playId = res.videoId;
    if (_currentId == playId) return;
    _currentId = playId;
    // مقطع جديد يبدأ دائمًا كنافذة عائمة كاملة، بصرف النظر عن حالة التصغير
    // التي رُبما تُركت عليها نافذة المقطع السابق. لا setState هنا: هذا
    // يُستدعى من build قبل استعمال _minimized في هذا التمريرة نفسها.
    if (_controller == null) {
      // نفس الإعداد الافتراضي الذي ثبت استقراره لمشغّل الفقاعة — بلا أي
      // origin مخصّص ولا إعادة تحميل، بعد ثلاث محاولات فاشلة هناك أثبتت
      // أن التدخل اليدوي في هذا المسار يكسر التشغيل أكثر مما يصلحه.
      _controller = YoutubePlayerController.fromVideoId(
        videoId: playId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: false,
          mute: false,
          strictRelatedVideos: false,
        ),
      );
    } else {
      _controller!.loadVideoById(videoId: playId);
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  void _close() => ref.read(miniPlayerProvider.notifier).state = null;

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(miniPlayerProvider);
    final minimized = ref.watch(miniPlayerMinimizedProvider);
    // مقطع جديد يبدأ دائمًا كنافذة عائمة كاملة.
    ref.listen<MiniPlayerTrack?>(miniPlayerProvider, (prev, next) {
      if (next != null && next.videoId != prev?.videoId) {
        ref.read(miniPlayerMinimizedProvider.notifier).state = false;
      }
    });
    _syncController(track);
    final controller = _controller;
    if (track == null || controller == null) return const SizedBox.shrink();

    return _buildPlayer(controller, track, minimized);
  }

  // مفتاح ثابت للمشغّل: تبديل التصغير/التكبير يغيّر خصائص الإطار فقط (حجم،
  // شفافية، إخفاء الرأس) ولا يهدم شجرة الودجت — هدمها كان يُتلف iframe
  // يوتيوب فيتوقف الفيديو. نفس العناصر بنفس الترتيب في الحالتين دائمًا.
  final GlobalKey _playerKey = GlobalKey();

  Widget _buildPlayer(
      YoutubePlayerController controller, MiniPlayerTrack track, bool minimized) {
    const width = 188.0;
    const videoHeight = width * 9 / 16;
    return Positioned(
      left: minimized ? 0 : 14,
      top: minimized ? 0 : 130,
      width: minimized ? 200 : width,
      child: IgnorePointer(
        ignoring: minimized,
        // في التصغير: شبه شفاف (لا Offstage) كي يبقى المشغّل مرسومًا فعليًا
        // ويستمر الصوت، وتظهر أيقونته في شريط الكتابة عبر MiniPlayerChip.
        child: Opacity(
          opacity: minimized ? 0.01 : 1,
          child: Material(
            color: Colors.transparent,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF17101F),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: minimized
                      ? null
                      : const [BoxShadow(color: Colors.black54, blurRadius: 14)],
                  border: Border.all(
                      color: minimized ? Colors.transparent : Colors.white12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Offstage(
                    offstage: minimized,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_rounded,
                              color: Colors.white54, size: 18),
                          onPressed: () => ref
                              .read(miniPlayerMinimizedProvider.notifier)
                              .state = true,
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white54, size: 18),
                          onPressed: _close,
                        ),
                      ]),
                    ),
                  ),
                  SizedBox(
                    width: minimized ? 200 : width,
                    height: minimized ? 200 : videoHeight,
                    child: YoutubePlayer(
                      key: _playerKey,
                      controller: controller,
                      aspectRatio: minimized ? 1 : 16 / 9,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
