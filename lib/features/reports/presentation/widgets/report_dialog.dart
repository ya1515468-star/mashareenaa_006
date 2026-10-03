import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/widgets/cross_platform_image.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/report_entity.dart';
import '../providers/report_provider.dart';

/// نقطة الاستدعاء الوحيدة لتقديم بلاغ عبر كل التطبيق — أي شاشة
/// تحتاج زر "إبلاغ" تستدعي [showReportDialog] بدل بناء حوار خاص بها.
/// يطلب صورة توثيق اختيارية مع سبب البلاغ (بند و من مواصفة
/// التعديلات: "زر الإبلاغ ... مع طلب صورة للتوثيق والابلاغ").
Future<void> showReportDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ReportTargetType targetType,
  required String targetId,
}) async {
  final uid = ref.read(authControllerProvider).valueOrNull?.uid;
  if (uid == null) return;

  final result = await showDialog<_ReportDraft>(
    context: context,
    builder: (context) => _ReportDialogBody(uid: uid),
  );
  if (result == null) return;

  final success =
      await ref.read(reportControllerProvider.notifier).submitReport(
            ReportEntity(
              id: '',
              reporterUid: uid,
              targetType: targetType,
              targetId: targetId,
              reason: result.reason,
              createdAt: DateTime.now(),
              evidenceUrl: result.evidenceUrl,
            ),
          );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
        content:
            Text(success ? 'تم إرسال البلاغ، شكرًا لك' : 'تعذّر إرسال البلاغ')),
  );
}

class _ReportDraft {
  final String reason;
  final String? evidenceUrl;
  const _ReportDraft(this.reason, this.evidenceUrl);
}

class _ReportDialogBody extends StatefulWidget {
  final String uid;
  const _ReportDialogBody({required this.uid});

  @override
  State<_ReportDialogBody> createState() => _ReportDialogBodyState();
}

class _ReportDialogBodyState extends State<_ReportDialogBody> {
  final _reasonController = TextEditingController();
  XFile? _evidenceFile;
  bool _uploading = false;

  Future<void> _pickEvidence() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _evidenceFile = picked);
  }

  Future<void> _submit() async {
    if (_reasonController.text.trim().isEmpty) return;
    String? evidenceUrl;
    if (_evidenceFile != null) {
      setState(() => _uploading = true);
      try {
        evidenceUrl = await MediaUploadService().uploadFile(
          file: _evidenceFile!,
          folder: 'reports',
          uid: widget.uid,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _uploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل رفع صورة التوثيق: $e')),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    }
    if (!mounted) return;
    Navigator.pop(
        context, _ReportDraft(_reasonController.text.trim(), evidenceUrl));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تقديم بلاغ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _reasonController,
            maxLines: 3,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(hintText: 'اذكر سبب البلاغ...'),
          ),
          const SizedBox(height: 10),
          if (_evidenceFile != null)
            Stack(
              alignment: Alignment.topLeft,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CrossPlatformImage(
                      file: _evidenceFile!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() => _evidenceFile = null),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickEvidence,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('إرفاق صورة للتوثيق (اختياري)'),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: _uploading ? null : () => Navigator.pop(context),
            child: const Text('إلغاء')),
        TextButton(
            onPressed: _uploading ? null : _submit,
            child: _uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('إرسال')),
      ],
    );
  }
}
