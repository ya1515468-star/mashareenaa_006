import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../domain/chat_store_section_icons.dart';
import '../providers/chat_store_sections_provider.dart';

/// Owner-only dialog to rename a store section, pick its icon, set a
/// background image URL, and choose how its items are displayed
/// (details / small icons / large icons) — all saved server-side via
/// admin_update_chat_store_section, one section at a time.
Future<void> showChatStoreSectionsSettingsDialog({
  required BuildContext context,
  required List<ChatStoreSection> sectionsInOrder,
  required VoidCallback onSaved,
}) {
  return showDialog(
    context: context,
    builder: (_) => _SectionsSettingsDialog(sections: sectionsInOrder, onSaved: onSaved),
  );
}

class _SectionsSettingsDialog extends StatefulWidget {
  final List<ChatStoreSection> sections;
  final VoidCallback onSaved;
  const _SectionsSettingsDialog({required this.sections, required this.onSaved});

  @override
  State<_SectionsSettingsDialog> createState() => _SectionsSettingsDialogState();
}

class _SectionsSettingsDialogState extends State<_SectionsSettingsDialog> {
  ChatStoreSection? _editing;

  @override
  Widget build(BuildContext context) {
    if (_editing != null) {
      return _SectionEditor(
        section: _editing!,
        onDone: () { widget.onSaved(); setState(() => _editing = null); },
        onCancel: () => setState(() => _editing = null),
      );
    }
    return AlertDialog(
      title: const Text('تخصيص أقسام المتجر'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in widget.sections)
              ListTile(
                leading: Icon(resolveChatStoreSectionIcon(s.iconName)),
                title: Text(s.nameAr),
                subtitle: Text(_displayModeLabel(s.displayMode), style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () => setState(() => _editing = s),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
    );
  }

  String _displayModeLabel(String m) => switch (m) {
        'small_icons' => 'رموز صغيرة',
        'large_icons' => 'رموز كبيرة',
        _ => 'تفاصيل',
      };
}

class _SectionEditor extends StatefulWidget {
  final ChatStoreSection section;
  final VoidCallback onDone;
  final VoidCallback onCancel;
  const _SectionEditor({required this.section, required this.onDone, required this.onCancel});

  @override
  State<_SectionEditor> createState() => _SectionEditorState();
}

class _SectionEditorState extends State<_SectionEditor> {
  late final _name = TextEditingController(text: widget.section.nameAr);
  late final _bg = TextEditingController(text: widget.section.backgroundImageUrl ?? '');
  late String _icon = widget.section.iconName;
  late String _displayMode = widget.section.displayMode;
  bool _busy = false;
  bool _uploadingBg = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _bg.dispose();
    super.dispose();
  }

  /// Lets the owner pick an image file from their device instead of typing a
  /// URL by hand. Uploads to the public `store-media` bucket under
  /// `store-sections/<section_key>/...` — the only prefix the storage RLS
  /// policies for this bucket allow platform owners to write to — then fills
  /// the same [_bg] field with the resulting public URL, so `_save()` needs
  /// no changes at all. Best-effort deletes the previously uploaded file
  /// (if any) so replacing a background doesn't leave orphaned files.
  Future<void> _pickAndUploadBackground() async {
    if (_uploadingBg) return;
    final picked = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif'],
      withData: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر قراءة الملف المختار.')));
      return;
    }
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'png';
    const supported = {'png', 'jpg', 'jpeg', 'webp', 'gif'};
    if (!supported.contains(ext)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('صيغة غير مدعومة: .$ext (المسموح: png، jpg، webp، gif)')));
      return;
    }
    final oldUrl = _bg.text.trim();
    setState(() { _uploadingBg = true; _error = null; });
    try {
      final uniqueName = '${DateTime.now().microsecondsSinceEpoch}_${widget.section.key}.$ext';
      final url = await MediaUploadService(bucket: 'store-media').uploadBytesAtPath(
        bytes: bytes,
        fileName: uniqueName,
        path: 'store-sections/${widget.section.key}/$uniqueName',
      );
      if (!mounted) return;
      setState(() => _bg.text = url);
      if (oldUrl.isNotEmpty && oldUrl != url) {
        try {
          await MediaUploadService(bucket: 'store-media').deleteFile(oldUrl);
        } catch (_) {
          // Best-effort cleanup only; the new image is already saved above.
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذر رفع الصورة: $e');
    } finally {
      if (mounted) setState(() => _uploadingBg = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'اسم القسم مطلوب.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('admin_update_chat_store_section', params: {
        'p_section_key': widget.section.key,
        'p_name_ar': _name.text.trim(),
        'p_icon_name': _icon,
        'p_background_image_url': _bg.text.trim().isEmpty ? null : _bg.text.trim(),
        'p_display_mode': _displayMode,
        'p_sort_order': widget.section.sortOrder,
        'p_is_active': true,
        'p_request_id': const Uuid().v4(),
      });
      widget.onDone();
    } catch (e) {
      final s = e.toString();
      debugPrint('CHAT_STORE_SECTION_SAVE_ERROR: $s');
      setState(() => _error = s.contains('FORBIDDEN')
          ? 'لا تملك صلاحية تنفيذ هذه العملية.'
          : 'تعذر حفظ إعدادات القسم. تم تسجيل تفاصيل الخطأ.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تخصيص: ${widget.section.nameAr}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم القسم')),
            const SizedBox(height: 12),
            TextField(controller: _bg, decoration: const InputDecoration(labelText: 'رابط صورة خلفية القسم (اختياري)'), onChanged: (_) => setState(() {})),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: _uploadingBg ? null : _pickAndUploadBackground,
                icon: _uploadingBg
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload, size: 16),
                label: Text(_uploadingBg ? 'جاري الرفع...' : 'رفع صورة من الجهاز'),
              ),
              if (_bg.text.trim().isNotEmpty)
                TextButton(
                  onPressed: _uploadingBg ? null : () => setState(() => _bg.clear()),
                  child: const Text('إزالة الخلفية'),
                ),
            ]),
            if (_bg.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _bg.text.trim(),
                  height: 90,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 90,
                    width: double.infinity,
                    alignment: Alignment.center,
                    color: Colors.white10,
                    child: const Text('تعذر تحميل معاينة الصورة', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerRight, child: Text('أيقونة القسم', style: TextStyle(fontSize: 12, color: Colors.white70))),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final entry in kChatStoreSectionIcons.entries)
                InkWell(
                  onTap: () => setState(() => _icon = entry.key),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _icon == entry.key ? Colors.amberAccent : Colors.white24, width: _icon == entry.key ? 2 : 1),
                    ),
                    child: Icon(entry.value, size: 20),
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            const Align(alignment: Alignment.centerRight, child: Text('طريقة العرض', style: TextStyle(fontSize: 12, color: Colors.white70))),
            RadioGroup<String>(
              groupValue: _displayMode,
              onChanged: (v) => setState(() => _displayMode = v!),
              child: const Column(children: [
                RadioListTile<String>(value: 'details', title: Text('تفاصيل (بطاقات كبيرة بالسعر والأزرار)'), contentPadding: EdgeInsets.zero, dense: true),
                RadioListTile<String>(value: 'small_icons', title: Text('رموز صغيرة (كثافة أعلى)'), contentPadding: EdgeInsets.zero, dense: true),
                RadioListTile<String>(value: 'large_icons', title: Text('رموز كبيرة (أقل كثافة، أوضح)'), contentPadding: EdgeInsets.zero, dense: true),
              ]),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: const Text('رجوع')),
        FilledButton(onPressed: _busy ? null : _save, child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ')),
      ],
    );
  }
}
