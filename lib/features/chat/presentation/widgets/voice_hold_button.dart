import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../data/services/voice_upload_helper.dart';
import '../../data/services/voice_file_cleanup.dart';

/// تسجيل صوتي بنمط WhatsApp: بدء واضح، إيقاف/استئناف مؤقت، حذف وإرسال صريح.
/// الشريط يبقى ظاهرًا أثناء التسجيل ولا يستبدل زر الميكروفون بواجهة مخفية.
class VoiceHoldButton extends StatefulWidget {
  final Future<void> Function(String url) onUploaded;
  final Color color;
  final double size;
  final bool privateChat;

  const VoiceHoldButton({
    super.key,
    required this.onUploaded,
    this.color = const Color(0xFFFFD700),
    this.size = 24,
    this.privateChat = false,
  });

  @override
  State<VoiceHoldButton> createState() => _VoiceHoldButtonState();
}

enum _VoiceStage { idle, recording, paused, stopped }

class _VoiceHoldButtonState extends State<VoiceHoldButton> {
  final _recorder = AudioRecorder();
  final _elapsed = ValueNotifier<Duration>(Duration.zero);
  final _amplitude = ValueNotifier<double>(0);
  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;
  OverlayEntry? _overlay;
  _VoiceStage _stage = _VoiceStage.idle;
  bool _uploading = false;
  bool _starting = false;
  String? _recordedPath;

  @override
  void initState() {
    super.initState();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((a) {
      final v = a.current.isFinite ? a.current : -60;
      _amplitude.value = ((v + 60) / 60).clamp(0.0, 1.0);
    });
  }

  Future<void> _disposeRecorder() async {
    try {
      final active = await _recorder.isRecording() || await _recorder.isPaused();
      if (active) {
        await _recorder.cancel();
      }
    } catch (_) {}
    try {
      await _recorder.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_amplitudeSub?.cancel());
    _removeOverlay();
    unawaited(_disposeRecorder());
    _elapsed.dispose();
    _amplitude.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_stage == _VoiceStage.recording) {
        _elapsed.value += const Duration(seconds: 1);
        _refreshOverlay();
      }
    });
  }

  Future<void> _start() async {
    if (_stage != _VoiceStage.idle || _uploading || _starting) return;
    _starting = true;
    try {
      if (!await _recorder.hasPermission(request: true)) {
        _toast('اسمح بالوصول إلى الميكروفون من إعدادات الجهاز.');
        return;
      }
      if (kIsWeb) {
        _toast('التسجيل الصوتي متاح في تطبيق الهاتف.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final name = 'voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      final path = '${dir.path}/$name';
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      );
      await _recorder.start(config, path: path);
      if (!await _recorder.isRecording()) {
        throw StateError('لم يبدأ المسجل على الجهاز.');
      }
      if (!mounted) {
        await _recorder.stop();
        return;
      }
      _elapsed.value = Duration.zero;
      _amplitude.value = 0;
      _recordedPath = null;
      setState(() => _stage = _VoiceStage.recording);
      _startTicker();
      _showOverlay();
    } catch (e) {
      _toast('تعذّر بدء التسجيل: $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> _pauseResume() async {
    if (_stage == _VoiceStage.recording) {
      try {
        await _recorder.pause();
        if (!mounted) return;
        setState(() => _stage = _VoiceStage.paused);
        _refreshOverlay();
      } catch (e) {
        _toast('تعذّر إيقاف التسجيل مؤقتًا: $e');
      }
      return;
    }
    if (_stage == _VoiceStage.paused) {
      try {
        await _recorder.resume();
        if (!mounted) return;
        setState(() => _stage = _VoiceStage.recording);
        _refreshOverlay();
      } catch (e) {
        _toast('تعذّر استئناف التسجيل: $e');
      }
    }
  }

  Future<void> _stopForPreview() async {
    if (_starting || !(_stage == _VoiceStage.recording || _stage == _VoiceStage.paused)) return;
    _ticker?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      _toast('تعذّر حفظ التسجيل: $e');
      return;
    }
    if (!mounted) return;
    if (path == null || path.isEmpty || _elapsed.value < const Duration(seconds: 1)) {
      _toast(path == null || path.isEmpty ? 'تعذّر حفظ التسجيل.' : 'التسجيل قصير جدًا.');
      await _discardFile(path);
      _recordedPath = null;
      setState(() => _stage = _VoiceStage.idle);
      _removeOverlay();
      return;
    }
    _recordedPath = path;
    setState(() => _stage = _VoiceStage.stopped);
    _refreshOverlay();
  }

  Future<void> _discardFile(String? path) async {
    if (path == null || path.isEmpty || kIsWeb) return;
    await deleteVoiceFile(path);
  }

  Future<void> _discard() async {
    _ticker?.cancel();
    String? path = _recordedPath;
    if (_stage == _VoiceStage.recording || _stage == _VoiceStage.paused) {
      try {
        await _recorder.cancel();
        path = null;
      } catch (_) {
        try {
          path = await _recorder.stop();
        } catch (_) {}
      }
    }
    await _discardFile(path);
    _recordedPath = null;
    _removeOverlay();
    if (mounted) setState(() => _stage = _VoiceStage.idle);
  }

  Future<void> _send() async {
    if (_stage == _VoiceStage.recording || _stage == _VoiceStage.paused) {
      await _stopForPreview();
    }
    final path = _recordedPath;
    if (path == null || path.isEmpty || _stage != _VoiceStage.stopped) return;
    setState(() => _uploading = true);
    _refreshOverlay();
    try {
      final url = await VoiceUploadHelper.uploadRecording(
        path,
        privateChat: widget.privateChat,
      );
      await widget.onUploaded(url);
      _recordedPath = null;
      _removeOverlay();
      if (mounted) setState(() => _stage = _VoiceStage.idle);
    } catch (e) {
      _toast('تعذّر إرسال الرسالة الصوتية: $e');
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
        _refreshOverlay();
      }
    }
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _refreshOverlay() {
    if (_overlay == null) return;
    _overlay!.markNeedsBuild();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context, rootOverlay: true);
    _overlay = OverlayEntry(builder: (ctx) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom + 74;
      return Positioned(
        left: 8,
        right: 8,
        bottom: bottom,
        child: Material(
          color: Colors.transparent,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF8F8FA), Color(0xFFEDEDF1)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 5))],
              ),
              child: Row(children: [
                // RTL layout: delete stays on the right and send stays on the left,
                // matching the WhatsApp-style recorder shown in the reference image.
                _RoundAction(
                  icon: Icons.delete_outline_rounded,
                  background: const Color(0xFFFFE8ED),
                  foreground: const Color(0xFFE11D48),
                  onTap: _uploading ? null : _discard,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: const Color(0xFFD9D9DF)),
                    ),
                    child: Row(children: [
                      _RoundAction(
                        icon: _stage == _VoiceStage.recording
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        background: const Color(0xFF111827),
                        foreground: Colors.white,
                        onTap: _uploading ? null : _pauseResume,
                        size: 38,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ValueListenableBuilder<double>(
                          valueListenable: _amplitude,
                          builder: (_, level, __) => _Waveform(level: level),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<Duration>(
                        valueListenable: _elapsed,
                        builder: (_, d, __) => Text(
                          _fmt(d),
                          style: const TextStyle(
                            color: Color(0xFF15151B),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_stage == _VoiceStage.paused)
                        const Padding(
                          padding: EdgeInsetsDirectional.only(start: 8),
                          child: Text('متوقف', style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      if (_uploading)
                        const Padding(
                          padding: EdgeInsetsDirectional.only(start: 8),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                _RoundAction(
                  icon: Icons.send_rounded,
                  background: const Color(0xFF16A34A),
                  foreground: Colors.white,
                  onTap: _uploading ? null : _send,
                ),
              ]),
            ),
          ),
        ),
      );
    });
    overlay.insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) {
    final active = _stage != _VoiceStage.idle;
    return SizedBox(
      width: widget.size + 20,
      height: widget.size + 20,
      child: Stack(alignment: Alignment.center, children: [
        if (!active && !_uploading)
          IconButton(
            tooltip: 'تسجيل صوتي',
            onPressed: _start,
            icon: Icon(Icons.mic_rounded, color: widget.color, size: widget.size),
            padding: EdgeInsets.zero,
          )
        else
          IconButton(
            tooltip: _uploading ? 'جاري الرفع' : 'تسجيل نشط',
            onPressed: _uploading ? null : _stopForPreview,
            icon: _uploading
                ? SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: CircularProgressIndicator(strokeWidth: 2, color: widget.color),
                  )
                : Icon(
                    Icons.mic_rounded,
                    color: _stage == _VoiceStage.paused
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFFE11D48),
                    size: widget.size,
                  ),
          ),
        if (active && !_uploading)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle),
            ),
          ),
      ]),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;
  final double size;
  const _RoundAction({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.size = 44,
  });
  @override
  Widget build(BuildContext context) => Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: foreground, size: size * .52),
          ),
        ),
      );
}

class _Waveform extends StatelessWidget {
  final double level;
  const _Waveform({required this.level});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 30,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(20, (i) {
            final wave = (0.18 + ((i % 5) / 7)) * (0.65 + level);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.1),
                child: FractionallySizedBox(
                  heightFactor: wave.clamp(.15, .95),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: i.isEven ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );

}
