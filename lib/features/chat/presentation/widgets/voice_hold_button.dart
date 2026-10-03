import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'voice_recorder_sheet.dart';

/// زر التسجيل الصوتي بنمط واتساب:
///   • اضغط مطوّلًا لبدء التسجيل، وحرّر للإرسال.
///   • اسحب جانبًا للإلغاء.
///   • اسحب للأعلى للقفل، فيستمر التسجيل بلا إمساك مع زرّي حذف وإرسال.
///   • التسجيل الأقصر من ثانية يُلغى مع تلميح.
class VoiceHoldButton extends StatefulWidget {
  final Future<void> Function(String url) onUploaded;
  final Color color;
  final double size;

  const VoiceHoldButton({
    super.key,
    required this.onUploaded,
    this.color = const Color(0xFFFFD700),
    this.size = 24,
  });

  @override
  State<VoiceHoldButton> createState() => _VoiceHoldButtonState();
}

class _VoiceHoldButtonState extends State<VoiceHoldButton> {
  static const _cancelDistance = 110.0;
  static const _lockDistance = 80.0;

  final _recorder = AudioRecorder();
  final _elapsed = ValueNotifier<Duration>(Duration.zero);
  final _dragX = ValueNotifier<double>(0);
  final _locked = ValueNotifier<bool>(false);
  Timer? _ticker;
  OverlayEntry? _overlay;
  Offset _origin = Offset.zero;
  bool _recording = false;
  bool _finishing = false;
  bool _uploading = false;

  @override
  void dispose() {
    _ticker?.cancel();
    _removeOverlay();
    _recorder.dispose();
    _elapsed.dispose();
    _dragX.dispose();
    _locked.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  Future<void> _begin(Offset origin) async {
    if (_recording || _uploading) return;
    _origin = origin;
    try {
      if (!await _recorder.hasPermission()) {
        _toast('اسمح بالوصول إلى الميكروفون من إعدادات الجهاز.');
        return;
      }
      final name = 'chat_${DateTime.now().microsecondsSinceEpoch}.m4a';
      final path = kIsWeb ? '' : '${(await getTemporaryDirectory()).path}/$name';
      await _recorder.start(const RecordConfig(), path: path);
      if (!mounted) {
        await _recorder.stop();
        return;
      }
      _recording = true;
      _finishing = false;
      _elapsed.value = Duration.zero;
      _dragX.value = 0;
      _locked.value = false;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsed.value += const Duration(seconds: 1);
      });
      _showOverlay();
      setState(() {});
    } catch (e) {
      _toast('تعذّر بدء التسجيل: $e');
    }
  }

  void _move(Offset position) {
    if (!_recording || _locked.value) return;
    final dx = position.dx - _origin.dx;
    final dy = position.dy - _origin.dy;
    if (dy < -_lockDistance) {
      _locked.value = true;
      _dragX.value = 0;
      return;
    }
    _dragX.value = dx;
    if (dx.abs() > _cancelDistance) unawaited(_finish(send: false));
  }

  Future<void> _release() async {
    if (!_recording || _locked.value) return;
    await _finish(send: true);
  }

  Future<void> _finish({required bool send}) async {
    if (!_recording || _finishing) return;
    _finishing = true;
    _ticker?.cancel();
    final duration = _elapsed.value;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    _recording = false;
    _removeOverlay();
    if (mounted) setState(() {});

    if (!send) return;
    if (duration < const Duration(seconds: 1)) {
      _toast('اضغط مطوّلًا للتسجيل، وحرّر للإرسال.');
      return;
    }
    if (path == null || path.isEmpty) {
      _toast('تعذّر حفظ التسجيل.');
      return;
    }
    setState(() => _uploading = true);
    try {
      final url = await VoiceRecorderSheet.uploadRecording(path);
      await widget.onUploaded(url);
    } catch (e) {
      _toast('تعذّر إرسال الرسالة الصوتية: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context, rootOverlay: true);
    _overlay = OverlayEntry(builder: (ctx) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom + 86;
      return Positioned(
        left: 10,
        right: 10,
        bottom: bottom,
        child: Material(
          color: Colors.transparent,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: ValueListenableBuilder<bool>(
              valueListenable: _locked,
              builder: (_, locked, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C2E),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
                ),
                child: Row(children: [
                  const _PulsingDot(),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<Duration>(
                    valueListenable: _elapsed,
                    builder: (_, d, __) => Text(_fmt(d),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  if (!locked)
                    ValueListenableBuilder<double>(
                      valueListenable: _dragX,
                      builder: (_, x, __) => Opacity(
                        opacity: (1 - x.abs() / _cancelDistance).clamp(.2, 1),
                        child: const Row(children: [
                          Icon(Icons.lock_outline, color: Colors.white54, size: 18),
                          SizedBox(width: 4),
                          Text('↑ للقفل  •  ↔ للإلغاء',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ]),
                      ),
                    )
                  else ...[
                    IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                      onPressed: () => _finish(send: false),
                    ),
                    IconButton(
                      tooltip: 'إرسال',
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF22C55E)),
                      onPressed: () => _finish(send: true),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      );
    });
    overlay.insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) {
    if (_uploading) {
      return SizedBox(
        width: widget.size + 16,
        height: widget.size + 16,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2, color: widget.color),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toast('اضغط مطوّلًا للتسجيل، وحرّر للإرسال.'),
      onLongPressStart: (d) => _begin(d.globalPosition),
      onLongPressMoveUpdate: (d) => _move(d.globalPosition),
      onLongPressEnd: (_) => _release(),
      onLongPressCancel: () => _finish(send: false),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AnimatedScale(
          scale: _recording ? 1.4 : 1,
          duration: const Duration(milliseconds: 150),
          child: Icon(_recording ? Icons.mic : Icons.mic_none_rounded,
              color: _recording ? const Color(0xFFEF4444) : widget.color,
              size: widget.size),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .3, end: 1.0).animate(_c),
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
        ),
      );
}
