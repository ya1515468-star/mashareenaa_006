import 'package:mashareena/core/utils/safe_launch.dart';
import 'dart:async';
import '../../../core/services/snack_sfx.dart';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/navigation/app_navigator.dart';
import '../data/ai_assistant_service.dart';
import '../data/video_frames.dart';
import 'ai_assistant_admin_sheet.dart';

const _bg = Color(0xFF17101F);
const _card = Color(0xFF241733);
const _gold = Color(0xFFFFD700);
const _purple = Color(0xFF7D32A6);

class _Msg {
  final bool user;
  String text;
  final List<Uint8List> thumbs;
  Uint8List? image;
  List<AiSource> sources = const [];
  List<AiPhoto> photos = const [];
  String? note;
  bool loading;
  bool error;
  _Msg({
    required this.user,
    this.text = '',
    this.thumbs = const [],
    this.image,
    this.loading = false,
    this.error = false,
  });
}

/// ورقة المساعد الذكي: تسجيل صوت (يُحوَّل لنص ويُرسَل تلقائيًا) أو كتابة،
/// مع إرفاق صور أو فيديو (تُؤخذ منه لقطات). الدفع والحصة يُحسَبان خادميًا.
class AiAssistantSheet extends StatefulWidget {
  const AiAssistantSheet({super.key});

  static Future<void> open() async {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiAssistantSheet(),
    );
  }

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = AudioRecorder();
  final _msgs = <_Msg>[];
  final _pending = <AiImage>[];
  AiAssistantStatus? _status;
  bool _recording = false;
  bool _busy = false;
  bool _extracting = false;
  bool _imageMode = false;
  bool _webMode = false;
  int _seconds = 0;
  Timer? _ticker;

  // رسم/تصميم → توليد صورة. طلب "صورة" لشيء موجود → بحث في الإنترنت (صور
  // حقيقية). يُفعَّل الوضع تلقائيًا ويظهر بوضوح قبل الإرسال حتى لا تُخصم
  // نقاط دون علم المستخدم.
  static const _imageTriggers = [
    'ارسم', 'ولد صورة', 'ولّد صورة', 'صمم لي', 'صمّم لي', 'اعمل صورة',
    'سوي صورة', 'انشئ صورة', 'أنشئ صورة', 'اعمل لي صورة',
  ];
  static const _webTriggers = [
    'اعطيني صورة', 'أعطيني صورة', 'اعطني صورة', 'أعطني صورة', 'اريد صورة',
    'أريد صورة', 'ارني', 'أرني', 'اعرض لي صورة', 'صورة ماكينة', 'صور ماكينة',
    'ابحث', 'سعر ', 'اسعار', 'أسعار',
  ];

  void _onTyped(String v) {
    if (_imageMode || _webMode) return;
    if (_imageTriggers.any(v.contains)) {
      setState(() => _imageMode = true);
      _toast('تم تفعيل «توليد صورة». اضغط زر الفرشاة لإلغائه.');
    } else if (_webTriggers.any(v.contains)) {
      setState(() => _webMode = true);
      _toast('تم تفعيل «بحث في الإنترنت». اضغط زر الكرة الأرضية لإلغائه.');
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    try {
      final s = await AiAssistantService.status();
      if (mounted) setState(() => _status = s);
    } catch (_) {}
  }

  void _toast(String t) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBarSfx(SnackBar(content: Text(t)));

  void _scrollEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  String _mimeFor(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_pending.length >= 4) return _toast('الحد الأقصى 4 صور.');
    try {
      final f = await ImagePicker()
          .pickImage(source: source, maxWidth: 1280, imageQuality: 75);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      setState(() => _pending.add(AiImage(bytes, _mimeFor(f.name))));
    } catch (e) {
      _toast('تعذّر اختيار الصورة.');
    }
  }

  Future<void> _pickVideo() async {
    if (_pending.length >= 4) return _toast('الحد الأقصى 4 صور/لقطات.');
    try {
      final f = await ImagePicker()
          .pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
      if (f == null) return;
      setState(() => _extracting = true);
      final frames = await extractVideoFrames(f, count: 3);
      if (!mounted) return;
      setState(() {
        _extracting = false;
        for (final b in frames) {
          if (_pending.length < 4) _pending.add(AiImage(b, 'image/jpeg'));
        }
      });
      if (frames.isEmpty) _toast('تعذّر قراءة الفيديو، جرّب صورة بدلًا منه.');
    } catch (e) {
      if (mounted) setState(() => _extracting = false);
      _toast('تعذّر اختيار الفيديو.');
    }
  }

  Future<void> _toggleRecord() async {
    if (_busy || _extracting) return;
    if (_recording) return _stopAndSend();
    if (_webMode) return _toast('البحث في الإنترنت يحتاج سؤالًا مكتوبًا. ألغِ وضع البحث للتسجيل الصوتي.');
    if (_imageMode) return _toast('وضع الصورة يحتاج وصفًا مكتوبًا. ألغِ «توليد صورة» لتسجيل صوتي.');
    try {
      if (!await _recorder.hasPermission()) {
        return _toast('اسمح بالوصول إلى الميكروفون.');
      }
      final path = kIsWeb
          ? ''
          : '${(await getTemporaryDirectory()).path}/ai_${DateTime.now().microsecondsSinceEpoch}.m4a';
      // الويب: Opus/WebM (m4a غير مدعوم هناك) — نفس ما يعمل في تسجيل المحادثة.
      const webCfg = RecordConfig(encoder: AudioEncoder.opus);
      await _recorder.start(kIsWeb ? webCfg : const RecordConfig(), path: path);
      _seconds = 0;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= 90) _stopAndSend();
      });
      setState(() => _recording = true);
    } catch (e) {
      _toast('تعذّر بدء التسجيل.');
    }
  }

  Future<void> _stopAndSend() async {
    _ticker?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (!mounted) return;
    final secs = _seconds;
    setState(() => _recording = false);
    if (path == null || path.isEmpty || secs < 1) {
      return _toast('التسجيل قصير جدًا.');
    }
    try {
      final bytes = await XFile(path).readAsBytes();
      await _send(audio: bytes, audioMime: kIsWeb ? 'audio/webm' : 'audio/mp4');
    } catch (e) {
      _toast('تعذّر قراءة التسجيل.');
    }
  }

  Future<void> _send({Uint8List? audio, String audioMime = 'audio/webm'}) async {
    if (_busy) return;
    final typed = _text.text.trim();
    if (audio == null && typed.isEmpty && _pending.isEmpty) return;
    final wantImage = _imageMode;
    final wantWeb = _webMode;
    if (wantImage && typed.isEmpty) return _toast('اكتب وصف الصورة المطلوبة.');
    if (wantWeb && typed.isEmpty) return _toast('اكتب ما تريد البحث عنه.');
    final images = List<AiImage>.of(_pending);
    final userMsg = _Msg(
      user: true,
      text: audio != null ? '🎤 رسالة صوتية…' : typed,
      thumbs: [for (final i in images) i.bytes],
    );
    final botMsg = _Msg(user: false, loading: true);
    setState(() {
      _msgs..add(userMsg)..add(botMsg);
      _pending.clear();
      _text.clear();
      _busy = true;
    });
    _scrollEnd();
    try {
      final r = await AiAssistantService.ask(
        requestId: const Uuid().v4(),
        text: typed,
        audio: audio,
        audioMime: audioMime,
        images: images,
        image: wantImage,
        web: wantWeb,
      );
      if (!mounted) return;
      setState(() {
        if (audio != null && r.transcript.isNotEmpty) {
          userMsg.text = '🎤 «${r.transcript}»';
        }
        botMsg
          ..loading = false
          ..image = r.image
          ..sources = r.sources
          ..photos = r.photos
          ..note = r.photosMissing && _status?.isOwner == true
              ? 'لتفعيل الصور الحقيقية أضف السرّين GOOGLE_CSE_KEY و GOOGLE_CSE_CX في Supabase.'
              : null
          ..text = r.answer;
      });
    } on AiAssistantException catch (e) {
      if (!mounted) return;
      setState(() {
        if (audio != null) userMsg.text = '🎤 رسالة صوتية';
        botMsg
          ..loading = false
          ..error = true
          ..text = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        botMsg
          ..loading = false
          ..error = true
          ..text = const AiAssistantException('AI_FAILED').message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollEnd();
      unawaited(_refreshStatus());
    }
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Container(
          height: mq.size.height * 0.82,
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
              child: Row(children: [
                const Icon(Icons.auto_awesome, color: _gold),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('المساعد الذكي',
                      style: TextStyle(
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                if (_status?.isOwner == true)
                  IconButton(
                    icon: const Icon(Icons.settings_rounded, color: _gold),
                    onPressed: () async {
                      await AiAssistantAdminSheet.open(context);
                      _refreshStatus();
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ]),
            ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _card, borderRadius: BorderRadius.circular(20)),
                    child: Text(_imageMode ? _status!.imageHint : _status!.hint,
                        style: const TextStyle(color: _gold, fontSize: 12)),
                  ),
                ),
              ),
            Expanded(
              child: _msgs.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                          'سجّل سؤالك بصوتك أو اكتبه، أو أرفق صورة/فيديو للعطل.\nمثال: «كيف أصلح ماكينة جاك لا تقص الخيط؟»',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, height: 1.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) => _bubble(_msgs[i]),
                    ),
            ),
            if (_pending.isNotEmpty || _extracting)
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  children: [
                    for (var i = 0; i < _pending.length; i++)
                      Stack(children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(_pending[i].bytes,
                                width: 52, height: 52, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: () => setState(() => _pending.removeAt(i)),
                            child: const CircleAvatar(
                                radius: 9,
                                backgroundColor: Colors.black87,
                                child: Icon(Icons.close, size: 12, color: Colors.white)),
                          ),
                        ),
                      ]),
                    if (_extracting)
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                  ],
                ),
              ),
            _inputBar(),
            SizedBox(height: mq.padding.bottom),
          ]),
        ),
      ),
    );
  }

  Widget _bubble(_Msg m) {
    final isUser = m.user;
    return Align(
      alignment: isUser ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: m.error ? const Color(0xFF4A1620) : (isUser ? _purple : _card),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m.thumbs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(spacing: 4, runSpacing: 4, children: [
                for (final b in m.thumbs)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(b, width: 58, height: 58, fit: BoxFit.cover),
                  ),
              ]),
            ),
          if (m.loading)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _gold))
          else
            ...[
              if (m.image != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: () => _zoom(m.image!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(m.image!, fit: BoxFit.cover),
                    ),
                  ),
                ),
              if (m.photos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final ph in m.photos)
                      GestureDetector(
                        onTap: () => _zoom(ph.bytes),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(ph.bytes, width: 120, height: 120, fit: BoxFit.cover),
                        ),
                      ),
                  ]),
                ),
              if (m.text.isNotEmpty)
                SelectableText(m.text,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.55)),
              if (m.sources.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final src in m.sources)
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: _bg,
                        avatar: const Icon(Icons.link_rounded, size: 14, color: _gold),
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 170),
                          child: Text(src.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ),
                        onPressed: () => safeLaunch(src.url),
                      ),
                  ]),
                ),
              if (m.note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(m.note!,
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ),
            ],
        ]),
      ),
    );
  }

  void _zoom(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(children: [
          InteractiveViewer(child: Image.memory(bytes)),
          Positioned(
            top: 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _inputBar() {
    if (_recording) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Row(children: [
          const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Text(_fmt(_seconds),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const Expanded(
            child: Text('  اضغط الإيقاف للإرسال',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent, size: 34),
            onPressed: _toggleRecord,
          ),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        IconButton(
          icon: Icon(Icons.public_rounded, color: _webMode ? _gold : Colors.white70),
          style: _webMode
              ? IconButton.styleFrom(backgroundColor: _purple.withValues(alpha: 0.55))
              : null,
          onPressed: _busy
              ? null
              : () => setState(() {
                    _webMode = !_webMode;
                    if (_webMode) _imageMode = false;
                  }),
        ),
        IconButton(
          icon: Icon(Icons.brush_rounded, color: _imageMode ? _gold : Colors.white70),
          style: _imageMode
              ? IconButton.styleFrom(backgroundColor: _purple.withValues(alpha: 0.55))
              : null,
          onPressed: _busy
              ? null
              : () => setState(() {
                    _imageMode = !_imageMode;
                    if (_imageMode) _webMode = false;
                  }),
        ),
        IconButton(
          icon: const Icon(Icons.mic_rounded, color: _gold),
          onPressed: _busy ? null : _toggleRecord,
        ),
        IconButton(
          icon: const Icon(Icons.image_outlined, color: Colors.white70),
          onPressed: _busy ? null : () => _pickImage(ImageSource.gallery),
        ),
        if (!kIsWeb)
          IconButton(
            icon: const Icon(Icons.photo_camera_outlined, color: Colors.white70),
            onPressed: _busy ? null : () => _pickImage(ImageSource.camera),
          ),
        IconButton(
          icon: const Icon(Icons.videocam_outlined, color: Colors.white70),
          onPressed: _busy ? null : _pickVideo,
        ),
        Expanded(
          child: TextField(
            controller: _text,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              counterText: '',
              hintText: _imageMode
                  ? 'صف الصورة التي تريدها…'
                  : (_webMode ? 'ابحث في الإنترنت عن…' : 'اكتب سؤالك…'),
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: _card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
            ),
            onChanged: _onTyped,
            onSubmitted: (_) => _send(),
          ),
        ),
        IconButton(
          icon: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _gold))
              : const Icon(Icons.send_rounded, color: _gold),
          onPressed: _busy ? null : () => _send(),
        ),
      ]),
    );
  }
}
