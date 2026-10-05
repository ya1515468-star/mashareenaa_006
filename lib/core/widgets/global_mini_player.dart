import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../providers/mini_player_provider.dart';

/// مشغل YouTube عائم مشترك بين الغرفة والخاص.
/// يبقى داخل التطبيق أثناء التنقل، مع تكبير/تصغير وإيقاف وإغلاق واضحين.
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
  bool _loading = false;
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
        });
      }
    });
  }

  Future<void> _loadIntoController(
    YoutubePlayerController controller,
    String videoId,
  ) async {
    try {
      await controller.loadVideoById(videoId: videoId);
      if (!mounted || !identical(_controller, controller)) return;
      if (_loading) setState(() => _loading = false);
    } catch (_) {
      if (!mounted || !identical(_controller, controller)) return;
      setState(() {
        _loading = false;
        _blocked = true;
      });
    }
  }

  Future<void> _playCurrent(YoutubePlayerController controller) async {
    try {
      await controller.playVideo();
    } catch (_) {
      if (!mounted || !identical(_controller, controller)) return;
      setState(() => _blocked = true);
    }
  }

  void _syncController(MiniPlayerTrack? track) {
    if (track == null) {
      if (_controller != null) _disposeController();
      _currentId = null;
      _blocked = false;
      _loading = false;
      _errorCode = null;
      return;
    }
    if (_currentId == track.videoId && _controller != null) return;

    _currentId = track.videoId;
    _compact = true;
    _blocked = false;
    _loading = true;
    _errorCode = null;

    final existing = _controller;
    if (existing == null) {
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
        unawaited(_loadIntoController(created, track.videoId));
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_controller, existing)) return;
      unawaited(_loadIntoController(existing, track.videoId));
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

  Widget _fallback(MiniPlayerTrack track) {
    final code = _errorCode;
    final ownerBlocked = code == 101 || code == 150 || code == 152 || code == 153;
    return Container(
      constraints: const BoxConstraints(minWidth: 200, minHeight: 200),
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF221238), Color(0xFF111827)]),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.ondemand_video_rounded, color: Color(0xFFA78BFA), size: 42),
          const SizedBox(height: 12),
          Text(
            ownerBlocked
                ? 'يوتيوب يمنع تضمين هذا الفيديو داخل مشغل خارجي.'
                : 'تعذّر تشغيل فيديو يوتيوب داخل المشغل.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
          ),
          if (code != null) ...[
            const SizedBox(height: 4),
            Text('رمز يوتيوب: $code', style: const TextStyle(color: Colors.white54, fontSize: 11)),
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
          const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFFD600), size: 25),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: _compact ? 'تكبير' : 'تصغير',
            icon: Icon(
              _compact ? Icons.open_in_full_rounded : Icons.close_fullscreen_rounded,
              color: const Color(0xFFA78BFA),
              size: 21,
            ),
            onPressed: () => setState(() => _compact = !_compact),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'إغلاق',
            icon: const Icon(Icons.close_rounded, color: Color(0xFFFCA5A5), size: 22),
            onPressed: () => ref.read(miniPlayerProvider.notifier).state = null,
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
                  playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: const Color(0xFF67E8F9),
                  size: 28,
                ),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'المشغل يبقى معك أثناء التنقل داخل التطبيق',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white60, fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'فتح في يوتيوب',
                onPressed: () {
                  final track = ref.read(miniPlayerProvider);
                  if (track != null) unawaited(_openInYoutube(track.videoId));
                },
                icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFFA78BFA), size: 19),
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
    if (track == null || controller == null) return const SizedBox.shrink();
    final videoHeight = _compact ? 200.0 : 225.0;
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
            constraints: const BoxConstraints(minHeight: 270),
            decoration: BoxDecoration(
              color: const Color(0xFF17101F),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: .55)),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 6))],
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
