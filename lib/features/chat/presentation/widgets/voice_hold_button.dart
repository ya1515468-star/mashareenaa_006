import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../data/services/voice_upload_helper.dart';

/// زر تسجيل واضح بالنقر: اضغط لبدء التسجيل، اضغط مرة أخرى لإيقافه، ثم زر
/// "إرسال" منفصل يرسل الفقاعة الصوتية — لا إرسال تلقائي عند مجرّد الإيقاف
/// (كان الإصدار السابق يرسل فورًا عند تحرير ضغطة مطوّلة؛ البند ٩ من وثيقة
/// التنفيذ يشترط خطوتين منفصلتين صراحة: إيقاف، ثم إرسال).
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

enum _VoiceStage { idle, recording, stopped }

class _VoiceHoldButtonState extends State<VoiceHoldButton> {
  final _recorder = AudioRecorder();
  final _elapsed = ValueNotifier<Duration>(Duration.zero);
  Timer? _ticker;
  OverlayEntry? _overlay;
  _VoiceStage _stage = _VoiceStage.idle;
  bool _uploading = false;
  String? _recordedPath;

  @override
  void dispose() {
    _ticker?.cancel();
    _removeOverlay();
    _recorder.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  Future<void> _start() async {
    if (_stage != _VoiceStage.idle || _uploading) return;
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
      _elapsed.value = Duration.zero;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsed.value += const Duration(seconds: 1);
      });
      setState(() => _stage = _VoiceStage.recording);
      _showOverlay();
    } catch (e) {
      _toast('تعذّر بدء التسجيل: $e');
    }
  }

  /// الضغطة الثانية: توقف التسجيل فقط، بلا إرسال. يبقى الشريط ظاهرًا
  /// بزرّي حذف وإرسال صريحين ريثما يقرر المستخدم.
  Future<void> _stop() async {
    if (_stage != _VoiceStage.recording) return;
    _ticker?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (!mounted) return;
    if (path == null || path.isEmpty || _elapsed.value < const Duration(seconds: 1)) {
      _toast(path == null || path.isEmpty ? 'تعذّر حفظ التسجيل.' : 'التسجيل قصير جدًا.');
      _removeOverlay();
      setState(() => _stage = _VoiceStage.idle);
      return;
    }
    _recordedPath = path;
    setState(() => _stage = _VoiceStage.stopped);
    _showOverlay();
  }

  Future<void> _discard() async {
    _ticker?.cancel();
    if (_stage == _VoiceStage.recording) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    _recordedPath = null;
    _removeOverlay();
    if (mounted) setState(() => _stage = _VoiceStage.idle);
  }

  Future<void> _send() async {
    final path = _recordedPath;
    if (path == null) return;
    _removeOverlay();
    setState(() {
      _stage = _VoiceStage.idle;
      _uploading = true;
    });
    try {
      final url = await VoiceUploadHelper.uploadRecording(path);
      await widget.onUploaded(url);
    } catch (e) {
      _toast('تعذّر إرسال الرسالة الصوتية: $e');
    } finally {
      _recordedPath = null;
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
      final recording = _stage == _VoiceStage.recording;
      return Positioned(
        left: 10,
        right: 10,
        bottom: bottom,
        child: Material(
          color: Colors.transparent,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C2E),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
              ),
              child: Row(children: [
                if (recording) const _PulsingDot() else const Icon(Icons.graphic_eq_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                ValueListenableBuilder<Duration>(
                  valueListenable: _elapsed,
                  builder: (_, d, __) => Text(_fmt(d),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                if (recording)
                  // النقر على الأيقونة نفسها مجددًا (أسفل) يوقف التسجيل؛
                  // هذا النص توضيحي فقط ريثما يضغط المستخدم مرة أخرى.
                  const Text('اضغط مجددًا للإيقاف', style: TextStyle(color: Colors.white54, fontSize: 12.5))
                else ...[
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                    onPressed: _discard,
                  ),
                  IconButton(
                    tooltip: 'إرسال',
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF22C55E)),
                    onPressed: _send,
                  ),
                ],
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
    final recording = _stage == _VoiceStage.recording;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // البند ٩ حرفيًا: ضغطة تبدأ، ضغطة تالية توقف — لا ضغط مطوّل، ولا
      // إرسال تلقائي عند التحرير.
      onTap: () {
        if (_stage == _VoiceStage.idle) {
          unawaited(_start());
        } else if (_stage == _VoiceStage.recording) {
          unawaited(_stop());
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AnimatedScale(
          scale: recording ? 1.4 : 1,
          duration: const Duration(milliseconds: 150),
          child: Icon(
            recording
                ? Icons.stop_circle_rounded
                : (_stage == _VoiceStage.stopped ? Icons.graphic_eq_rounded : Icons.mic_none_rounded),
            color: recording ? const Color(0xFFEF4444) : widget.color,
            size: widget.size,
          ),
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
