import 'package:file_picker/file_picker.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/media_upload_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../data/gif_catalog.dart';

class ReplyPreviewBar extends StatelessWidget {
  final ChatMessageEntity replyingTo;
  final VoidCallback onCancel;

  const ReplyPreviewBar(
      {super.key, required this.replyingTo, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: p.surfaceHighlight,
          borderRadius: BorderRadius.circular(10),
          border: Border(right: BorderSide(color: p.accent, width: 3))),
      child: Row(children: [
        IconButton(
            icon: Icon(Icons.close, size: 18, color: p.textMuted),
            onPressed: onCancel,
            visualDensity: VisualDensity.compact),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('الرد على رسالة',
              style: TextStyle(
                  color: p.accent, fontSize: 11, fontWeight: FontWeight.bold)),
          Text(replyingTo.text.isEmpty ? '📎 مرفق' : replyingTo.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.textSecondary, fontSize: 12.5)),
        ])),
      ]),
    );
  }
}

typedef AttachmentPicked = Future<void> Function(
    MessageType type, String url, String name);

/// مرفقات الشات كلها عبر Supabase Storage: صور، فيديو، ملفات، GIF محلية وصوت.
///
/// [onMusicSearch] اختياري: عند تمريره تظهر بطاقة "موسيقى" إضافية تفتح لوحة
/// بحث الأغاني — تنفيذ "نقل زر الموسيقى إلى داخل زر +" بدل أيقونة مستقلة في
/// شريط الكتابة.
class AttachmentMenu extends StatelessWidget {
  final AttachmentPicked onPicked;
  final VoidCallback? onMusicSearch;
  const AttachmentMenu({super.key, required this.onPicked, this.onMusicSearch});

  static Future<void> show(BuildContext context,
      {required AttachmentPicked onPicked, VoidCallback? onMusicSearch}) {
    return showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            AttachmentMenu(onPicked: onPicked, onMusicSearch: onMusicSearch));
  }

  /// [extensions] فارغة أو null = أي ملف من الهاتف بلا قيد امتداد (الحد
  /// الفعلي للحجم مفروض خادميًا على مستوى سطل التخزين نفسه، لا قيمة
  /// يختارها التطبيق فقط — انظر الفحص الخادمي الحقيقي أدناه عبر
  /// get_profile_service_runtime ثم رفض Supabase Storage لأي تجاوز).
  Future<void> _pick(BuildContext context,
      {required MessageType type, List<String>? extensions}) async {
    final authUid = await userId();
    if (authUid == null) return;
    final result = await FilePicker.pickFiles(
        withData: true,
        type: extensions == null ? FileType.any : FileType.custom,
        allowedExtensions: extensions);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) return;
    final vipRaw = await Supabase.instance.client.rpc(
      'get_profile_service_runtime',
      params: {'p_feature_key': 'chat_media_plus'},
    );
    final vipPlus = vipRaw is Map && vipRaw['enabled'] == true;
    final limit = vipPlus ? 25 * 1024 * 1024 : 10 * 1024 * 1024;
    final user = MediaUploadService(bucket: vipPlus ? 'chat-media-plus' : 'media');
    if (bytes.length > limit) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(vipPlus ? 'حد الوسائط Plus هو 25MB.' : 'الحد الأساسي 10MB. فعّل وسائط Plus للوصول إلى 25MB.')));
      return;
    }
    try {
      final url = await user.uploadBytes(
          bytes: bytes,
          fileName: f.name,
          folder: 'chat/attachments',
          uid: authUid);
      if (context.mounted) Navigator.pop(context);
      await onPicked(type, url, f.name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          SnackBar(content: Text('فشل رفع المرفق: $e')),
        );
      }
    }
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final uid = await userId();
    if (uid == null) return;
    final file =
        await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final vipRaw = await Supabase.instance.client.rpc(
      'get_profile_service_runtime',
      params: {'p_feature_key': 'chat_media_plus'},
    );
    final vipPlus = vipRaw is Map && vipRaw['enabled'] == true;
    final limit = vipPlus ? 25 * 1024 * 1024 : 10 * 1024 * 1024;
    final user = MediaUploadService(bucket: vipPlus ? 'chat-media-plus' : 'media');
    if (bytes.length > limit) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(vipPlus ? 'حد الوسائط Plus هو 25MB.' : 'الحد الأساسي 10MB. فعّل وسائط Plus للوصول إلى 25MB.')));
      return;
    }
    try {
      final url = await user.uploadBytes(
          bytes: bytes,
          fileName: file.name,
          folder: 'chat/attachments',
          uid: uid);
      if (context.mounted) Navigator.pop(context);
      await onPicked(MessageType.image, url, file.name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
          SnackBar(content: Text('فشل رفع الصورة: $e')),
        );
      }
    }
  }

  Future<void> _showGifs(BuildContext context) async {
    const gifs = mashareenaChatGifCatalog;

    final surfaceColor = context.palette.surfaceElevated;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // كان onTap أدناه يستعمل context الخارجي (معامل الدالة) بدل سياق
      // الورقة نفسها لِـNavigator.pop — فإن لم يعد لذاك السياق سلف
      // Navigator حيّ (الشاشة الأصل أُغلقت أو أُعيد بناؤها بين فتح الورقة
      // والنقر على GIF)، يرمي Navigator.of فحص-لا‑قيمة فارغًا بلا شاشة
      // حمراء مرئية — وهذا طابق تمامًا خطأ "Null check operator used on
      // a null value" المسجَّل من AttachmentMenu._showGifs في المراقبة.
      // استعمال sheetContext (سياق الورقة ذاتها) هو الإصلاح الصحيح.
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final gif in gifs)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      await onPicked(MessageType.gif, gif, gif);
                    },
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: Image.asset(
                        gif,
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        // صورة واحدة فاسدة في الفهرس كانت تُسقط الشبكة
                        // كلها بخطأ "asset does not exist or has empty
                        // data" مسجَّل فعليًا في المراقبة — هذا يستبدلها
                        // بأيقونة بديلة بدل كسر الصف بأكمله.
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            size: 20,
                            color: Colors.white38),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> userId() async {
    // Deferred import-free access is intentionally kept in this small helper.
    return await _currentUserId();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: p.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child:
          Wrap(alignment: WrapAlignment.spaceEvenly, runSpacing: 16, children: [
        _AttachmentAction(
            icon: Icons.image_outlined,
            label: 'صورة',
            color: Colors.purpleAccent,
            onTap: () => _pickImage(context, ImageSource.gallery)),
        _AttachmentAction(
            icon: Icons.videocam_outlined,
            label: 'فيديو',
            color: Colors.redAccent,
            onTap: () => _pick(context,
                type: MessageType.video, extensions: ['mp4', 'webm', 'mov'])),
        _AttachmentAction(
            icon: Icons.camera_alt_outlined,
            label: 'كاميرا',
            color: Colors.blueAccent,
            onTap: () => _pickImage(context, ImageSource.camera)),
        _AttachmentAction(
            icon: Icons.gif_box_outlined,
            label: 'GIF',
            color: Colors.tealAccent,
            onTap: () {
              Navigator.pop(context);
              _showGifs(context);
            }),
        _AttachmentAction(
            icon: Icons.insert_drive_file_outlined,
            label: 'ملف',
            color: Colors.amberAccent,
            // بلا قيد امتداد بعد الآن — "أي ملف من الهاتف"؛ الحد الفعلي
            // للحجم يبقى مفروضًا خادميًا (bucket file_size_limit)، لا
            // بقائمة امتدادات محلية فقط.
            onTap: () => _pick(context, type: MessageType.file)),
        if (onMusicSearch != null)
          _AttachmentAction(
              icon: Icons.music_note_rounded,
              label: 'موسيقى',
              color: Colors.pinkAccent,
              onTap: () {
                Navigator.pop(context);
                onMusicSearch!();
              }),
      ]),
    );
  }
}

class _AttachmentAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachmentAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
            width: 88,
            child: Column(children: [
              CircleAvatar(
                  radius: 26,
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Icon(icon, color: color)),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
            ])));
  }
}

Future<String?> _currentUserId() async =>
    Supabase.instance.client.auth.currentUser?.id;
