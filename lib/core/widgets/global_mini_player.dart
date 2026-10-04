import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../providers/mini_player_provider.dart';

/// مشغل يوتيوب عائم واحد مشترك بين الغرف والخاص.
///
/// يبقى مشغل YouTube الحقيقي mounted حتى أثناء التصغير، لكن يُقص بصريًا
/// خلف شريط صغير. وعند وجود فيديو غير قابل للتضمين يظهر بديل واضح بدل ترك
/// خطأ YouTube الخام داخل التطبيق.
class GlobalMiniPlayer extends ConsumerStatefulWidget {
  const GlobalMiniPlayer({super.key});

  @override
  ConsumerState<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends ConsumerState<GlobalMiniPlayer> {
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _subscription;
  String? _currentId;
  bool _compact = true;
  bool _blocked = false;
  int? _errorCode;

  static const _blockedCodes = <int>{2, 100, 101, 150, 152, 153};

  void _disposeController() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    final old = _controller;
    _controller = null;
    if (old != null) unawaited(old.close());
  }

  void _attachController(YoutubePlayerController controller) {
    _subscription = controller.listen((value) {
      if (!mounted) return;
      final code = value.error.code;
      if (_blockedCodes.contains(code)) {
        if (!_blocked || _errorCode != code) {
          setState(() {
            _blocked = true;
            _errorCode = code;
          });
        }
      }
    });
  }

  void _syncController(MiniPlayerTrack? track) {
    if (track == null) {
      if (_controller != null) _disposeController();
      _currentId = null;
      _blocked = false;
      _errorCode = null;
      return;
    }
    if (_currentId == track.videoId && _controller != null) return;

    _currentId = track.videoId;
    _compact = true;
    _blocked = false;
    _errorCode = null;
    if (_controller == null) {
      final controller = YoutubePlayerController.fromVideoId(
        videoId: track.videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: false,
          mute: false,
          strictRelatedVideos: false,
          interfaceLanguage: 'ar',
          privacyEnhancedMode: true,
        ),
      );
      _controller = controller;
      _attachController(controller);
    } else {
      unawaited(_controller!.loadVideoById(videoId: track.videoId));
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Future<void> _openInYoutube(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _fallback(MiniPlayerTrack track) {
    final code = _errorCode;
    final ownerBlocked = code == 101 || code == 150 || code == 152;
    final message = ownerBlocked
        ? 'هذا الفيديو لا يسمح يوتيوب بتشغيله داخل مشغّل مضمّن.'
        : 'تعذّر تشغيل فيديو يوتيوب داخل المشغّل.';
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF221238), Color(0xFF111827)]),
      ),
      child: Row(children: [
        const Icon(Icons.ondemand_video_rounded, color: Color(0xFFA78BFA), size: 25),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _compact ? message : '$message\nرمز الحالة: ${code ?? '-'}',
            maxLines: _compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ),
        if (!_compact)
          FilledButton.icon(
            onPressed: () => _openInYoutube(track.videoId),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('يوتيوب'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
      ]),
    );
  }

  Widget _youtubeSurface(YoutubePlayerController controller) {
    if (_blocked) return _fallback(ref.read(miniPlayerProvider)!);
    if (_compact) {
      return Positioned(
        left: -62,
        top: -67,
        width: 200,
        height: 200,
        child: IgnorePointer(
          ignoring: true,
          child: Opacity(
            opacity: 0,
            child: YoutubePlayer(controller: controller, aspectRatio: 1),
          ),
        ),
      );
    }
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: YoutubePlayer(controller: controller, aspectRatio: 1),
      ),
    );
  }

  Widget _playPause(YoutubePlayerController controller) => YoutubeValueBuilder(
        controller: controller,
        builder: (_, value) {
          final playing = value.playerState == PlayerState.playing;
          return IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل',
            icon: Icon(
              playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: const Color(0xFF67E8F9),
              size: 31,
            ),
            onPressed: !value.isReady
                ? null
                : () => playing ? controller.pauseVideo() : controller.playVideo(),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(miniPlayerProvider);
    _syncController(track);
    final controller = _controller;
    if (track == null || controller == null) return const SizedBox.shrink();

    return Positioned(
      left: 8,
      right: 8,
      bottom: 72,
      child: Material(
        color: Colors.transparent,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: _compact ? 66 : 250,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF17101F),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 13, offset: Offset(0, 5)),
              ],
              border: Border.all(
                color: const Color(0xFF7C3AED).withValues(alpha: .55),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (!_blocked) _youtubeSurface(controller),
                if (_blocked) _fallback(track),
                if (_compact)
                  Positioned.fill(
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 78,
                          height: 52,
                          child: Image.network(
                            'https://i.ytimg.com/vi/${track.videoId}/hqdefault.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Color(0xFF2A2038),
                              child: Icon(Icons.ondemand_video_rounded, color: Color(0xFFA78BFA)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (!_blocked) _playPause(controller),
                      if (_blocked)
                        IconButton(
                          tooltip: 'فتح في يوتيوب',
                          icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFFA78BFA), size: 21),
                          onPressed: () => _openInYoutube(track.videoId),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'تكبير',
                        icon: const Icon(Icons.open_in_full_rounded, color: Color(0xFFA78BFA), size: 21),
                        onPressed: () => setState(() => _compact = false),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'إغلاق',
                        icon: const Icon(Icons.close_rounded, color: Color(0xFFFCA5A5), size: 22),
                        onPressed: () => ref.read(miniPlayerProvider.notifier).state = null,
                      ),
                    ]),
                  )
                else
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 43,
                    child: Container(
                      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF17101F), Color(0xFF17101F)])),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (!_blocked) _playPause(controller),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'تصغير',
                          icon: const Icon(Icons.close_fullscreen_rounded, color: Color(0xFFA78BFA), size: 21),
                          onPressed: () => setState(() => _compact = true),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'إغلاق',
                          icon: const Icon(Icons.close_rounded, color: Color(0xFFFCA5A5), size: 22),
                          onPressed: () => ref.read(miniPlayerProvider.notifier).state = null,
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
