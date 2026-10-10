import 'package:audioplayers/audioplayers.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter/material.dart';

/// مشغّل صوت داخلي حصراً ضمن الفقاعة نفسها — تشغيل/إيقاف وشريط تقدّم
/// ومدة، بلا أي فتح لتطبيق خارجي. كانت الرسائل الصوتية (في الغرفة
/// والخاص معاً) تُفتح عبر launchUrl(mode: externalApplication)، فيُغادر
/// المستخدم التطبيق كلياً لسماع تسجيل مدته ثوانٍ.
class VoiceMessagePlayer extends StatefulWidget {
  final String url;
  final Color accentColor;
  const VoiceMessagePlayer({super.key, required this.url, this.accentColor = const Color(0xFFFFD700)});

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _loading = true);
    try {
      await _player.play(UrlSource(widget.url));
      if (mounted) setState(() => _playing = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBarSfx(SnackBar(content: Text('تعذّر تشغيل الصوت: $e')));
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
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1;
    final progress = (_position.inMilliseconds / total).clamp(0.0, 1.0);
    return SizedBox(
      width: 190,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: _loading ? null : _toggle,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.accentColor),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(widget.accentColor),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _duration > Duration.zero ? '${_fmt(_position)} / ${_fmt(_duration)}' : 'رسالة صوتية',
              style: const TextStyle(color: Colors.white60, fontSize: 10.5),
            ),
          ]),
        ),
      ]),
    );
  }
}
