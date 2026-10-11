import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// أزرار تحكم أصلية (إعادة، تأخير 10ث، تشغيل/إيقاف مؤقت، تقديم 10ث، صوت)
/// تعمل عبر YoutubePlayerController، فلا تعتمد على ظهور أدوات يوتيوب نفسها
/// داخل الـWebView.
class YoutubeControlBar extends StatefulWidget {
  final YoutubePlayerController controller;
  final Color color;
  const YoutubeControlBar({
    super.key,
    required this.controller,
    this.color = Colors.white,
  });

  @override
  State<YoutubeControlBar> createState() => _YoutubeControlBarState();
}

class _YoutubeControlBarState extends State<YoutubeControlBar> {
  StreamSubscription<YoutubePlayerValue>? _sub;
  bool _playing = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.controller.stream.listen((v) {
      final playing = v.playerState == PlayerState.playing ||
          v.playerState == PlayerState.buffering;
      if (mounted && playing != _playing) setState(() => _playing = playing);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _skip(double delta) async {
    try {
      final now = await widget.controller.currentTime;
      final target = (now + delta) < 0 ? 0.0 : now + delta;
      await widget.controller.seekTo(seconds: target, allowSeekAhead: true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    Widget btn(IconData icon, VoidCallback onTap, {double size = 24}) =>
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 38, minHeight: 36),
          icon: Icon(icon, color: c, size: size),
          onPressed: onTap,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.replay_rounded, () => widget.controller.seekTo(seconds: 0, allowSeekAhead: true)),
        btn(Icons.replay_10_rounded, () => _skip(-10)),
        btn(
          _playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
          () => _playing ? widget.controller.pauseVideo() : widget.controller.playVideo(),
          size: 34,
        ),
        btn(Icons.forward_10_rounded, () => _skip(10)),
        btn(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, () {
          if (_muted) {
            widget.controller.unMute();
          } else {
            widget.controller.mute();
          }
          setState(() => _muted = !_muted);
        }),
      ],
    );
  }
}
