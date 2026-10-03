import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/widgets/cross_platform_image.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../wallet/domain/entities/currency.dart';
import '../../domain/entities/pattern_enums.dart';
import '../../domain/entities/pattern_request_entity.dart';
import '../providers/pattern_studio_provider.dart';

class AdminPatternStudioTab extends ConsumerWidget {
  const AdminPatternStudioTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;
    final configAsync = ref.watch(patternConfigProvider);
    final requestsAsync =
        ref.watch(allPatternRequestsProvider(PatternRequestStatus.queued));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('إعدادات الميزة', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          configAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.'),
            data: (config) => _ConfigCard(config: config, myUid: myUid),
          ),
          const SizedBox(height: 20),
          Text('طلبات قيد الانتظار',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          requestsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.'),
            data: (requests) {
              if (requests.isEmpty) {
                return const Text('لا توجد طلبات قيد الانتظار',
                    style: TextStyle(color: AppColors.textSecondary));
              }
              return Column(
                children: requests
                    .map((r) => _RequestCard(request: r, myUid: myUid))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConfigCard extends ConsumerStatefulWidget {
  final PatternStudioConfigEntity config;
  final String? myUid;
  const _ConfigCard({required this.config, required this.myUid});

  @override
  ConsumerState<_ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends ConsumerState<_ConfigCard> {
  late bool _enabled;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _enabled = widget.config.enabled;
    _priceController = TextEditingController(
        text: widget.config.price.value.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: const Text('تفعيل الميزة للمستخدمين'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'السعر (شام كاش)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: widget.myUid == null
                  ? null
                  : () async {
                      final priceValue =
                          double.tryParse(_priceController.text.trim()) ?? 0;
                      final newConfig = PatternStudioConfigEntity(
                        enabled: _enabled,
                        price: Money(
                            minorUnits: (priceValue * 100).round(),
                            currency: Currency.shamCash),
                      );
                      final success = await ref
                          .read(patternStudioControllerProvider.notifier)
                          .updateConfig(
                              config: newConfig, requestedByUid: widget.myUid!);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(success ? 'تم الحفظ' : 'فشل الحفظ')),
                      );
                    },
              child: const Text('حفظ الإعدادات'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  final PatternRequestEntity request;
  final String? myUid;
  const _RequestCard({required this.request, required this.myUid});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  XFile? _resultImage;
  final _noteController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickResultImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked != null && mounted) setState(() => _resultImage = picked);
  }

  Future<void> _submitResult() async {
    if (widget.myUid == null || _resultImage == null) return;

    setState(() => _isUploading = true);
    String resultUrl;
    try {
      resultUrl = await sl<MediaUploadService>().uploadFile(
        file: _resultImage!,
        folder: 'pattern_results',
        uid: widget.myUid!,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل الرفع: $e')));
      return;
    }
    setState(() => _isUploading = false);

    final success =
        await ref.read(patternStudioControllerProvider.notifier).submitResult(
              requestId: widget.request.id,
              requesterUid: widget.request.uid,
              reviewedByUid: widget.myUid!,
              resultImageUrl: resultUrl,
              reviewerNote: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!success) {
      try {
        await MediaUploadService().deleteFile(resultUrl);
      } catch (_) {}
      if (!mounted) return;
    }
    messenger.showSnackBar(
      SnackBar(
          content: Text(success ? 'تم تسليم النتيجة للمستخدم' : 'فشل التسليم')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(r.mannequinType.label)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('المستخدم: ${r.uid}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11))),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(r.sourceImageUrl,
                  height: 140, fit: BoxFit.cover),
            ),
            if (r.notes != null) ...[
              const SizedBox(height: 6),
              Text('ملاحظة المستخدم: ${r.notes}',
                  style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 10),
            if (_resultImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CrossPlatformImage(
                    file: _resultImage!, height: 140, fit: BoxFit.cover),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickResultImage,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('رفع صورة الباترون النهائية'),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration:
                  const InputDecoration(labelText: 'ملاحظة للمستخدم (اختياري)'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed:
                  _resultImage == null || _isUploading ? null : _submitResult,
              child: Text(_isUploading ? 'جارٍ الرفع...' : 'تسليم النتيجة'),
            ),
          ],
        ),
      ),
    );
  }
}
