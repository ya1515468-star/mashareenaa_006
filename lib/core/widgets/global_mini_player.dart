import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../providers/mini_player_provider.dart';

/// شريط عائم ثابت فوق التطبيق كله (يُركَّب في MaterialApp.builder في
/// main.dart، لا داخل أي شاشة)، فيبقى حيًّا عبر كل تنقّل — بين الغرف،
/// الخاص، وأقسام المنصة الأخرى — حتى يُغلَق يدويًا. هذا يحقّق "يستمر
/// بالتشغيل عند الانتقال" مع إبقاء مشغّل الفيديو المضمَّن داخل فقاعة
/// الرسالة نفسه محليًّا (يتوقف تلقائيًا بمغادرة تلك الشاشة بحكم دورة
/// حياة الودجت العادية؛ هذان مشغّلان منفصلان تمامًا لا يتداخلان).
class GlobalMiniPlayer extends ConsumerStatefulWidget {
  const GlobalMiniPlayer({super.key});
  @override
  ConsumerState<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends ConsumerState<GlobalMiniPlayer> {
  YoutubePlayerController? _controller;
  String? _currentId;

  void _syncController(MiniPlayerTrack? track) {
    if (track == null) {
      _controller?.close();
      _controller = null;
      _currentId = null;
      return;
    }
    if (_currentId == track.videoId) return;
    _currentId = track.videoId;
    if (_controller == null) {
      // نفس الإعداد الافتراضي الذي ثبت استقراره لمشغّل الفقاعة — بلا أي
      // origin مخصّص ولا إعادة تحميل، بعد ثلاث محاولات فاشلة هناك أثبتت
      // أن التدخل اليدوي في هذا المسار يكسر التشغيل أكثر مما يصلحه.
      _controller = YoutubePlayerController.fromVideoId(
        videoId: track.videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: false,
          mute: false,
          strictRelatedVideos: false,
        ),
      );
    } else {
      _controller!.loadVideoById(videoId: track.videoId);
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(miniPlayerProvider);
    _syncController(track);
    final controller = _controller;
    if (track == null || controller == null) return const SizedBox.shrink();

    return Positioned(
      left: 10,
      right: 10,
      // يرتفع فوق الشريط السفلي لتبويبات التطبيق، فلا يحجبها ولا تحجبه.
      bottom: 74,
      child: Material(
        color: Colors.transparent,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF17101F),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
              border: Border.all(color: Colors.white12),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 70,
                  height: 42,
                  child: IgnorePointer(
                    // عرض تصغير فعلي للفيديو (لا صورة ثابتة)، بلا أزرار
                    // تحكّم مضمَّنة لأن الشريط نفسه ضيق جدًا لاحتوائها.
                    child: YoutubePlayer(controller: controller, aspectRatio: 70 / 42),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                onPressed: () => ref.read(miniPlayerProvider.notifier).state = null,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
