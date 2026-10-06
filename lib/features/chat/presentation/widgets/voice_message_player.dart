import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../data/services/chat_media_url_resolver.dart';

/// مشغل صوت داخلي موحّد لرسائل الصوت في الخاص والغرف.
/// لا يخرج المستخدم من التطبيق ولا يعتمد على مشغل خارجي.
class VoiceMessagePlayer extends StatefulWidget {
  final String url;
  final Color accentColor;

  const VoiceMessagePlayer({
    super.key,
    required this.url,
    this.accentColor = const Color(0xFFFFD700),
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<void>? _completeSubscription;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    unawaited(
      _player
          .setAudioContext(
            AudioContextConfig(
              route: AudioContextConfigRoute.speaker,
              respectSilence: false,
              stayAwake: true,
            ).build(),
          )
          .catchError((_) {}),
    );

    _positionSubscription = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSubscription = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _loading = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void didUpdateWidget(covariant VoiceMessagePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    unawaited(_resetForNewUrl());
  }

  Future<void> _resetForNewUrl() async {
    try {
      await _player.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _position = Duration.zero;
      _duration = Duration.zero;
      _playing = false;
      _loading = false;
    });
  }

  Future<void> _toggle() async {
    if (_loading) return;

    if (_playing) {
      try {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text('تعذّر إيقاف الصوت: $e')),
          );
        }
      }
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final raw = widget.url.trim();
      if (raw.isEmpty) throw StateError('رابط الصوت فارغ.');

      // Resolve on every play so private chat-voice objects always receive a
      // fresh signed URL instead of reusing an expired one.
      final resolved = await ChatMediaUrlResolver.resolve(raw);
      if (resolved.trim().isEmpty) {
        throw StateError('تعذّر تجهيز رابط الصوت.');
      }

      await _player.stop();
      await _player.play(
        UrlSource(resolved),
        mode: PlayerMode.mediaPlayer,
      );

      if (mounted) {
        setState(() {
          _playing = true;
          _position = Duration.zero;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('تعذّر تشغيل الصوت: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(_completeSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total =
        _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1;
    final progress =
        (_position.inMilliseconds / total).clamp(0.0, 1.0);

    return SizedBox(
      width: 190,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: _loading ? null : _toggle,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accentColor,
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Icon(
                      _playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.white24,
                    valueColor:
                        AlwaysStoppedAnimation(widget.accentColor),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _duration > Duration.zero
                      ? '${_fmt(_position)} / ${_fmt(_duration)}'
                      : 'رسالة صوتية',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
