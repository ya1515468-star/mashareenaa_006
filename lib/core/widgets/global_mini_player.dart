import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../providers/mini_player_provider.dart';
import 'youtube_thumbnail.dart';

/// مشغل YouTube عائم واحد مشترك بين الغرفة والخاص.
/// عند التصغير يبقى WebView حيًا بحجم 1px حتى لا ينقطع الصوت، بينما تظهر
/// واجهة mini واضحة فوق التطبيق. وعند التكبير يعود الفيديو بالحجم الكامل.
class GlobalMiniPlayer extends ConsumerStatefulWidget {
  const GlobalMiniPlayer({super.key});

  @override
  ConsumerState<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends ConsumerState<GlobalMiniPlayer> {
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _subscription;
  String? _currentId;
  String? _autoPlayConsumedId;
  bool _compact = true;
  bool _blocked = false;
  bool _loading = false;
  bool _muted = false;
  int? _errorCode;

  // 152 is not a current official IFrame API error code. Do not turn a
  // transient/legacy 152 report into a permanent blocked state.
  static const _blockedCodes = <int>{2, 5, 100, 101, 150, 153};

  void _disposeController() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    final old = _controller;
    _controller = null;
    if (old != null) unawaited(old.close());
  }

  void _attachController(YoutubePlayerController controller) {
    _subscription = controller.listen((value) {
      if (!mounted || !identical(_controller, controller)) return;
      final code = value.error.code;
      final blocked = _blockedCodes.contains(code);
      if (blocked != _blocked || code != _errorCode) {
        setState(() {
          _blocked = blocked;
          _errorCode = blocked ? code : null;
          if (blocked) _loading = false;
        });
      }
    });
  }

  Future<void> _loadIntoController(
    YoutubePlayerController controller,
    String videoId, {
    required bool autoPlay,
  }) async {
    try {
      if (autoPlay) {
        await controller.loadVideoById(videoId: videoId);
      } else {
        await controller.cueVideoById(videoId: videoId);
      }
      // Explicitly restore audio after every load.
      await controller.unMute();
      await controller.setVolume(100);
      _muted = false;

      if (!mounted || !identical(_controller, controller)) return;
      setState(() {
        _loading = false;
        _blocked = false;
        _errorCode = null;
      });
    } catch (_) {
      if (!mounted || !identical(_controller, controller)) return;
      setState(() {
        _loading = false;
        _blocked = true;
        _errorCode ??= 153;
      });
    }
  }

  Future<void> _playCurrent(YoutubePlayerController controller) async {
    try {
      await controller.unMute();
      await controller.setVolume(100);
      _muted = false;
      await controller.playVideo();
      if (mounted && identical(_controller, controller)) {
        setState(() {
          _blocked = false;
          _errorCode = null;
        });
      }
    } catch (_) {
      if (!mounted || !identical(_controller, controller)) return;
      setState(() => _blocked = true);
    }
  }

  void _syncController(MiniPlayerTrack? track) {
    if (track == null) {
      if (_controller != null) _disposeController();
      _currentId = null;
      _autoPlayConsumedId = null;
      _blocked = false;
      _loading = false;
      _errorCode = null;
      _muted = false;
      return;
    }

    if (_currentId == track.videoId && _controller != null) {
      if (track.autoPlay && _autoPlayConsumedId != track.videoId) {
        _autoPlayConsumedId = track.videoId;
        final controller = _controller!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !identical(_controller, controller)) return;
          unawaited(_playCurrent(controller));
        });
      }
      return;
    }

    _currentId = track.videoId;
    _autoPlayConsumedId = track.autoPlay ? track.videoId : null;
    _compact = true;
    _blocked = false;
    _loading = true;
    _errorCode = null;
    _muted = false;

    _disposeController();

    final created = YoutubePlayerController(
      key: track.videoId,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        strictRelatedVideos: false,
        interfaceLanguage: 'ar',
        privacyEnhancedMode: true,
        origin: 'https://com.mashareena.mashareena',
      ),
    );
    _controller = created;
    _attachController(created);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_controller, created)) return;
      unawaited(
        _loadIntoController(
          created,
          track.videoId,
          autoPlay: track.autoPlay,
        ),
      );
    });
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

  Future<void> _toggleMute(YoutubePlayerController controller) async {
    try {
      if (_muted) {
        await controller.unMute();
        await controller.setVolume(100);
      } else {
        await controller.mute();
      }
      if (mounted) setState(() => _muted = !_muted);
    } catch (_) {}
  }

  void _close() {
    ref.read(miniPlayerProvider.notifier).state = null;
  }

  Widget _playPauseButton(
    YoutubePlayerController controller, {
    double size = 40,
    Color background = const Color(0xFF111827),
  }) {
    return YoutubeValueBuilder(
      controller: controller,
      builder: (_, value) {
        final playing = value.playerState == PlayerState.playing;
        return Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _loading
                ? null
                : () => unawaited(
                      (playing
                              ? controller.pauseVideo()
                              : _playCurrent(controller))
                          .catchError((_) {}),
                    ),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: size * .55,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _compactView(MiniPlayerTrack track, YoutubePlayerController controller) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1230), Color(0xFF302060)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF8D6BFF).withValues(alpha: .65)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 64,
              child: YoutubeThumbnail(videoId: track.videoId),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        _muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: _muted
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFF4ADE80),
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _muted ? 'مكتوم' : 'الصوت يعمل',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: _muted ? 'إلغاء الكتم' : 'كتم',
            onPressed: _loading
                ? null
                : () => unawaited(_toggleMute(controller)),
            icon: Icon(
              _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: _muted
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFF4ADE80),
              size: 21,
            ),
          ),
          _playPauseButton(controller),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'تكبير',
            onPressed: () => setState(() => _compact = false),
            icon: const Icon(
              Icons.open_in_full_rounded,
              color: Color(0xFFD9CCFF),
              size: 21,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'إغلاق',
            onPressed: _close,
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFFFCA5A5),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expandedView(
    MiniPlayerTrack track,
    YoutubePlayerController controller,
  ) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 470),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF17101F), Color(0xFF21163A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: .65),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Color(0xFFFFD600),
                size: 24,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'تصغير',
                onPressed: () => setState(() => _compact = true),
                icon: const Icon(
                  Icons.remove_rounded,
                  color: Color(0xFFD9CCFF),
                  size: 22,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'إغلاق',
                onPressed: _close,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFFFCA5A5),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          if (_blocked)
            _fallback(track)
          else
            SizedBox(
              width: double.infinity,
              height: 220,
              child: YoutubePlayer(
                controller: controller,
                aspectRatio: 16 / 9,
              ),
            ),
          YoutubeValueBuilder(
            controller: controller,
            builder: (_, value) {
              final playing = value.playerState == PlayerState.playing;
              return Row(
                textDirection: TextDirection.rtl,
                children: [
                  IconButton(
                    tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل',
                    onPressed: _loading
                        ? null
                        : () => unawaited(
                              (playing
                                      ? controller.pauseVideo()
                                      : _playCurrent(controller))
                                  .catchError((_) {}),
                            ),
                    icon: Icon(
                      playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: const Color(0xFF67E8F9),
                      size: 31,
                    ),
                  ),
                  IconButton(
                    tooltip: _muted ? 'إلغاء الكتم' : 'كتم',
                    onPressed: _loading
                        ? null
                        : () => unawaited(_toggleMute(controller)),
                    icon: Icon(
                      _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: _muted
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF4ADE80),
                      size: 23,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => unawaited(_openInYoutube(track.videoId)),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text('فتح في يوتيوب'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFC4B5FD),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _fallback(MiniPlayerTrack track) {
    final ownerBlocked =
        _errorCode == 101 || _errorCode == 150 || _errorCode == 153;
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF221238), Color(0xFF111827)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.ondemand_video_rounded,
            color: Color(0xFFA78BFA),
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            ownerBlocked
                ? 'هذا الفيديو يمنع التضمين داخل المشغل.'
                : 'تعذّر تشغيل فيديو يوتيوب داخل المشغل.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (_errorCode != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'رمز YouTube: $_errorCode',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          const SizedBox(height: 11),
          FilledButton.icon(
            onPressed: () => unawaited(_openInYoutube(track.videoId)),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: const Text('فتح في يوتيوب'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(miniPlayerProvider);
    _syncController(track);

    final controller = _controller;
    if (track == null || controller == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 8,
      right: 8,
      bottom: 72,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Keep the same platform view/controller mounted while compact.
            // The visible UI becomes a real mini bar instead of a shrunken
            // full WebView, so navigation does not stop playback.
            if (_compact)
              Positioned(
                left: 0,
                top: 0,
                width: 1,
                height: 1,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.01,
                    child: YoutubePlayer(
                      controller: controller,
                      aspectRatio: 16 / 9,
                    ),
                  ),
                ),
              ),
            if (_compact)
              _compactView(track, controller)
            else
              _expandedView(track, controller),
          ],
        ),
      ),
    );
  }
}
