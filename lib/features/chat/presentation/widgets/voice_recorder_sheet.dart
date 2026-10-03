import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/media_upload_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceRecorderSheet extends StatefulWidget {
  /// رفع تسجيل صوتي من مساره المحلي وإرجاع رابطه. مشتركة بين هذه الورقة وزر
  /// التسجيل بالضغط المطوّل (نمط واتساب) حتى يتطابق الرفع في المسارين.
  static Future<String> uploadRecording(String path) async {
    final bytes = await XFile(path).readAsBytes();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) throw StateError('لا توجد جلسة مستخدم.');
    final vipRaw = await Supabase.instance.client.rpc(
      'get_profile_service_runtime',
      params: {'p_feature_key': 'chat_media_plus'},
    );
    final vipPlus = vipRaw is Map && vipRaw['enabled'] == true;
    if (bytes.length > (vipPlus ? 25 : 10) * 1024 * 1024) {
      throw StateError(vipPlus ? 'حد الوسائط Plus هو 25MB.' : 'الحد الأساسي للوسائط الصوتية 10MB؛ فعّل وسائط Plus للوصول إلى 25MB.');
    }
    return MediaUploadService(bucket: vipPlus ? 'chat-media-plus' : 'media').uploadBytes(
      bytes: bytes,
      fileName: 'voice_.m4a',
      folder: 'chat/audio',
      uid: uid,
    );
  }

  final ValueChanged<String>? onUploaded;

  const VoiceRecorderSheet({super.key, this.onUploaded});

  static Future<void> show(BuildContext context,
      {ValueChanged<String>? onUploaded}) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceRecorderSheet(onUploaded: onUploaded),
    );
  }

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  final _recorder = AudioRecorder();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  String? _path;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!mounted) return;
      if (!hasPermission) {
        setState(() =>
            _error = 'الرجاء منح صلاحية الوصول للمايكروفون من إعدادات الجهاز');
        return;
      }

      // كان المسار نسبيًا ('recordings/…'): على أندرويد يحاول مسجّل النظام
      // الكتابة في مجلد غير موجود من جذر الجهاز فيرمي خطأً داخل الكود الأصلي
      // لا يلتقطه Dart، فيُغلَق التطبيق كليًا عند ضغط المايك. المسار المطلق
      // في المجلد المؤقت للتطبيق مضمون الوجود وقابل للكتابة. الويب لا يستعمل
      // المسار (يسجّل في blob) فيُمرَّر فارغًا.
      final name = 'chat_${DateTime.now().microsecondsSinceEpoch}.m4a';
      final preferredPath =
          kIsWeb ? '' : '${(await getTemporaryDirectory()).path}/$name';
      await _recorder.start(const RecordConfig(), path: preferredPath);
      if (!mounted) {
        await _recorder.stop();
        return;
      }

      setState(() {
        _recording = true;
        _path = null;
      });

      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر بدء التسجيل: $e');
    }
  }

  Future<void> _stopAndDiscard() async {
    _ticker?.cancel();
    if (_recording) await _recorder.stop();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _stopAndSend() async {
    _ticker?.cancel();
    String? path = _path;
    if (_recording) {
      path = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _path = path;
      });
    }
    if (!mounted || path == null || path.isEmpty) return;
    try {
      final url = await VoiceRecorderSheet.uploadRecording(path);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      widget.onUploaded?.call(url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر رفع الرسالة الصوتية: $e');
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Icon(Icons.mic_off, size: 40, color: p.error),
            const SizedBox(height: 10),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.error, fontSize: 13)),
            const SizedBox(height: 16),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق')),
          ] else ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.error.withValues(alpha: 0.15),
                border: Border.all(color: p.error, width: 2),
              ),
              child: Icon(Icons.mic, color: p.error, size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              _formatDuration(_elapsed),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary),
            ),
            const SizedBox(height: 4),
            Text('جارٍ التسجيل...',
                style: TextStyle(color: p.textSecondary, fontSize: 12)),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: _stopAndDiscard,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  // كان معطّلًا طوال التسجيل: _path لا يُعيَّن إلا بعد الإيقاف،
                  // فلم يكن الإرسال ممكنًا أبدًا. صار يوقف التسجيل ويرسله.
                  onPressed: (_recording || _path != null) ? _stopAndSend : null,
                  icon: const Icon(Icons.send),
                  label: const Text('إرسال'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
