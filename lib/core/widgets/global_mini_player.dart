import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../providers/mini_player_provider.dart';

/// مشغل YouTube عائم واحد مشترك بين الغرفة والخاص.
/// التشغيل الفعلي يمر من مشغل واحد بدل إنشاء WebView لكل فقاعة، لتقليل
/// التقطّع وتحسين استقرار الصوت. ويُعالج منع التضمين بدل عرض خطأ خام.
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
      await controller.unMute();
      await controller.setVolume(100);
      _muted = false;

      if (autoPlay) {
        await controller.loadVideoById(videoId: videoId);
      } else {
        await controller.cueVideoById(videoId: videoId);
      }

      if (!mounted || !identical(_controller, controller)) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted || !identical(_controller, controller)) return;
      setState(() {
        _loading = false;
        _blocked = true;
        _errorCode ??= 152;
      });
    }
  }

  Future<void> _playCurrent(YoutubePlayerController controller) async {
    try {
      await controller.unMute();
      await controller.setVolume(100);
      _muted = false;
      await controller.playVideo();
      if (mounted) setState(() => _blocked = false);
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
          unawaited(_playCurrent(controller).catchError((_) {}));
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
        ).catchError((_) {}),
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

  Widget _fallback(MiniPlayerTrack track) {
    final ownerBlocked = _errorCode == 101 ||
        _errorCode == 150 ||
        _errorCode == 152 ||
        _errorCode == 153;
    return Container(
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(18),
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
            size: 42,
          ),
          const SizedBox(height: 12),
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
          if (_errorCode != null) ...[
            const SizedBox(height: 4),
            Text(
              'رمز YouTube: $_errorCode',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _openInYoutube(track.videoId),
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

  Widget _header(MiniPlayerTrack track) => Row(
        children: [
          const Icon(
            Icons.play_circle_fill_rounded,
            color: Color(0xFFFFD600),
            size: 25,
          ),
          const SizedBox(width: 8),
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
            tooltip: _compact ? 'تصغير' : 'تكبير',
            icon: Icon(
              _compact
                  ? Icons.remove_rounded
                  : Icons.open_in_full_rounded,
              color: const Color(0xFFA78BFA),
              size: 23,
            ),
            onPressed: () => setState(() => _compact = !_compact),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'إغلاق',
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFFFCA5A5),
              size: 22,
            ),
            onPressed: () =>
                ref.read(miniPlayerProvider.notifier).state = null,
          ),
        ],
      );

  Widget _footer(YoutubePlayerController controller) => YoutubeValueBuilder(
        controller: controller,
        builder: (_, value) {
          final playing = value.playerState == PlayerState.playing;
          return Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
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
                  size: 29,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
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
                  size: 22,
                ),
              ),
              const SizedBox(width: 3),
              const Expanded(
                child: Text(
                  'المشغل العائم يعمل أثناء التنقل داخل التطبيق',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'فتح في يوتيوب',
                onPressed: () {
                  final track = ref.read(miniPlayerProvider);
                  if (track != null) {
                    unawaited(_openInYoutube(track.videoId));
                  }
                },
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  color: Color(0xFFA78BFA),
                  size: 19,
                ),
              ),
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(miniPlayerProvider);
    _syncController(track);

    final controller = _controller;
    if (track == null || controller == null) {
      return const SizedBox.shrink();
    }

    final videoHeight = _compact ? 200.0 : 270.0;

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
            constraints: BoxConstraints(
              minHeight: _compact ? 270 : 340,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF17101F),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF7C3AED).withValues(alpha: .55),
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
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(track),
                if (_blocked)
                  _fallback(track)
                else
                  SizedBox(
                    width: double.infinity,
                    height: videoHeight,
                    child: YoutubePlayer(
                      controller: controller,
                      aspectRatio: _compact ? 1.45 : 16 / 9,
                    ),
                  ),
                _footer(controller),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
