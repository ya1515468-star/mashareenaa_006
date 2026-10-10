import 'package:video_player/video_player.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/media_upload_service.dart';
import '../providers/producers_market_provider.dart';

/// ورقة نشر الريل — تتحقق من حصة العضوية أولاً قبل السماح بالرفع
/// كل شيء خادمي: الخادم هو من يقرر إذا كان الرفع مسموحاً أم لا
class PublishReelSheet extends ConsumerStatefulWidget {
  const PublishReelSheet({super.key});

  @override
  ConsumerState<PublishReelSheet> createState() => _PublishReelSheetState();
}

class _PublishReelSheetState extends ConsumerState<PublishReelSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  String _selectedCategory = 'other';
  String? _videoUrl;

  /// مدة الفيديو بالثواني، تُقاس بعد الرفع.
  ///
  /// الخادم يرفض النشر بـ DURATION_EXCEEDED إن تجاوزت المدة حدّ
  /// عضوية العضو (30ث مجاني … 600ث للمستوى النهائي). كانت تُرسل
  /// 30 افتراضيًا دون قياس، فيُرفض فيديو طويل بلا سبب مفهوم أو
  /// يُقبل قصير بقيمة خاطئة.
  int _durationSeconds = 0;
  String? _thumbnailUrl;
  bool _uploading = false;
  bool _publishing = false;
  String? _error;

  /// الموافقة على شروط الاستخدام ودليل المجتمع (يفرضها الخادم قبل أي نشر).
  /// null = جارٍ التحقق، true = موافق مسبقًا فلا نعرض الخانة.
  bool? _legalOk;
  bool _legalChecked = false;

  @override
  void initState() {
    super.initState();
    _loadLegal();
  }

  Future<void> _loadLegal() async {
    try {
      final r = await Supabase.instance.client
          .rpc('has_current_ugc_legal_acceptance');
      if (mounted) setState(() => _legalOk = r == true);
    } catch (_) {
      if (mounted) setState(() => _legalOk = false);
    }
  }

  static const List<Map<String, String>> _categories = [
    {'key': 'packaging', 'label': 'أمبلاج 📦'},
    {'key': 'cutting', 'label': 'قطاعة ✂️'},
    {'key': 'washing', 'label': 'غسيل 🫧'},
    {'key': 'dyeing', 'label': 'صباغة 🎨'},
    {'key': 'embroidery', 'label': 'تطريز 🪡'},
    {'key': 'ironing', 'label': 'كوي 🔥'},
    {'key': 'printing', 'label': 'طباعة 🖨️'},
    {'key': 'fabric', 'label': 'أقمشة 🧵'},
    {'key': 'accessories', 'label': 'إكسسوار 💎'},
    {'key': 'pattern', 'label': 'باترون 📐'},
    {'key': 'other', 'label': 'أخرى 🏷️'},
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      final ext = file.name.split('.').last;
      final path = '$uid/producer_reels/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final url = await MediaUploadService(bucket: 'media').uploadBytesAtPath(
        bytes: file.bytes!,
        fileName: file.name,
        path: path,
        contentType: 'video/$ext',
      );
      // نقيس المدة من الملف المرفوع نفسه قبل عرض زر النشر
      int seconds = 0;
      try {
        final probe = VideoPlayerController.networkUrl(Uri.parse(url));
        await probe.initialize();
        seconds = probe.value.duration.inSeconds;
        await probe.dispose();
      } catch (_) {
        // تعذّر القياس — نترك 0 والخادم يحكم بحدّ العضوية
      }
      if (mounted) {
        setState(() {
          _videoUrl = url;
          _durationSeconds = seconds;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'فشل رفع الفيديو: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickThumbnail() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;

    setState(() => _uploading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      final ext = file.name.split('.').last;
      final path = '$uid/reel_thumbnails/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final url = await MediaUploadService(bucket: 'media').uploadBytesAtPath(
        bytes: file.bytes!,
        fileName: file.name,
        path: path,
        contentType: 'image/$ext',
      );
      if (mounted) setState(() => _thumbnailUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = 'فشل رفع الصورة: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _publish() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'يرجى إدخال عنوان المنتج.');
      return;
    }
    if (_videoUrl == null) {
      setState(() => _error = 'يرجى رفع مقطع الفيديو أولاً.');
      return;
    }

    if (_legalOk != true && !_legalChecked) {
      setState(() => _error =
          'يجب الموافقة على شروط الاستخدام ودليل المجتمع قبل النشر (فعّل الخانة أعلاه).');
      return;
    }

    setState(() {
      _publishing = true;
      _error = null;
    });

    try {
      if (_legalOk != true) {
        await Supabase.instance.client.rpc('accept_required_legal_documents');
        _legalOk = true;
      }
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      await ref.read(producerMarketControllerProvider.notifier).publishReel(
            videoUrl: _videoUrl!,
            thumbnailUrl: _thumbnailUrl ?? '',
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            category: _selectedCategory,
            tags: tags,
            durationSeconds: _durationSeconds,
          );

      if (mounted) {
        // true تُخبر الصفحة الخلفية أن ريلًا جديدًا نُشر فتُحدّث القائمة
        // وتقفز له؛ النشر كان ينجح فعليًا لكن لا يظهر فورًا لأن القائمة
        // لا تتحرك لرأسها حيث يُدرَج الريل الجديد (الأحدث أولًا).
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBarSfx(
          const SnackBar(
            content: Text('✅ نُشر الريل وخُصمت رسوم النشر من رصيدك'),
            backgroundColor: Color(0xFF2D7A4F),
          ),
        );
      }
    } catch (e) {
      // الترجمة مركزية في المتحكّم لتغطّي كل أخطاء المسار المدفوع
      // (الحصة، المدة، الرصيد، الموافقة القانونية، القطاع).
      if (mounted) {
        setState(() =>
            _error = ProducerMarketController.publishErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotaAsync = ref.watch(myReelQuotaProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── العنوان والحصة ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('🎬 نشر ريل منتج',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                quotaAsync.when(
                  data: (q) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${q['used']}/${q['limit']} ريل',
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ─── رفع الفيديو ──────────────────────────────────
            GestureDetector(
              onTap: _uploading ? null : _pickVideo,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _videoUrl != null
                          ? const Color(0xFFFFD700)
                          : Colors.white24,
                      style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                child: Center(
                  child: _uploading
                      ? const CircularProgressIndicator(
                          color: Color(0xFFFFD700))
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _videoUrl != null
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.videocam_outlined,
                              color: _videoUrl != null
                                  ? const Color(0xFFFFD700)
                                  : Colors.white38,
                              size: 36,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _videoUrl != null
                                  ? '✅ تم رفع الفيديو'
                                  : 'اضغط لرفع مقطع الفيديو',
                              style: TextStyle(
                                  color: _videoUrl != null
                                      ? const Color(0xFFFFD700)
                                      : Colors.white38,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ─── صورة مصغرة اختيارية ─────────────────────────
            TextButton.icon(
              onPressed: _uploading ? null : _pickThumbnail,
              icon: Icon(
                _thumbnailUrl != null
                    ? Icons.image_rounded
                    : Icons.image_outlined,
                color: _thumbnailUrl != null
                    ? const Color(0xFFFFD700)
                    : Colors.white54,
              ),
              label: Text(
                _thumbnailUrl != null
                    ? '✅ تم رفع الصورة المصغرة'
                    : 'رفع صورة مصغرة (اختياري)',
                style: TextStyle(
                    color: _thumbnailUrl != null
                        ? const Color(0xFFFFD700)
                        : Colors.white54,
                    fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),

            // ─── فئة المنتج ───────────────────────────────────
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              dropdownColor: const Color(0xFF1A1A2E),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'فئة المنتج',
                labelStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c['key'],
                        child: Text(c['label']!),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedCategory = v);
              },
            ),
            const SizedBox(height: 10),

            // ─── العنوان ──────────────────────────────────────
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white),
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'عنوان المنتج *',
                labelStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 10),

            // ─── الوصف ────────────────────────────────────────
            TextField(
              controller: _descCtrl,
              style: const TextStyle(color: Colors.white),
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'وصف المنتج',
                labelStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 10),

            // ─── الوسوم ───────────────────────────────────────
            TextField(
              controller: _tagsCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'الوسوم (افصل بين كل وسم بفاصلة)',
                hintText: 'مثال: قطاعة, دمشق, شتاء',
                labelStyle: TextStyle(color: Colors.white54),
                hintStyle: TextStyle(color: Colors.white30),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
            ),

            if (_legalOk == false) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _legalChecked,
                onChanged: (v) => setState(() => _legalChecked = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: const Color(0xFFFFD700),
                checkColor: Colors.black,
                title: const Text(
                  'أوافق على شروط الاستخدام وسياسة الخصوصية ودليل المجتمع، وأتعهّد بعدم نشر محتوى مسيء أو مخالف.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ],

            const SizedBox(height: 16),

            // ─── زر النشر ─────────────────────────────────────
            FilledButton.icon(
              onPressed: (_publishing || _uploading) ? null : _publish,
              icon: _publishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.send_rounded),
              label: Text(_publishing ? 'جارٍ النشر...' : 'نشر الريل'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
