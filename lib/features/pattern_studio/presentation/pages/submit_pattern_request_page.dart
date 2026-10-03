import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/widgets/cross_platform_image.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/auth_button.dart';
import '../../domain/entities/pattern_enums.dart';
import '../providers/pattern_studio_provider.dart';
import 'my_pattern_requests_page.dart';

class SubmitPatternRequestPage extends ConsumerStatefulWidget {
  const SubmitPatternRequestPage({super.key});

  @override
  ConsumerState<SubmitPatternRequestPage> createState() =>
      _SubmitPatternRequestPageState();
}

class _SubmitPatternRequestPageState
    extends ConsumerState<SubmitPatternRequestPage> {
  final _notesController = TextEditingController();
  MannequinType _mannequinType = MannequinType.men;
  XFile? _pickedImage;
  bool _isUploading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked != null && mounted) setState(() => _pickedImage = picked);
  }

  Future<void> _submit() async {
    final uid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (uid == null || _pickedImage == null) return;

    setState(() => _isUploading = true);
    String imageUrl;
    try {
      imageUrl = await sl<MediaUploadService>().uploadFile(
        file: _pickedImage!,
        folder: 'pattern_requests',
        uid: uid,
      );
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذّر رفع الصورة: $e')));
      return;
    }
    if (!mounted) return;
    setState(() => _isUploading = false);

    final success =
        await ref.read(patternStudioControllerProvider.notifier).submitRequest(
              uid: uid,
              sourceImageUrl: imageUrl,
              mannequinType: _mannequinType,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تم إرسال طلبك وخصم الرسوم من محفظتك')),
      );
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const MyPatternRequestsPage()),
      );
    } else {
      try {
        await MediaUploadService().deleteFile(imageUrl);
      } catch (_) {}
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الطلب الآن. تحقق من البيانات والاتصال ثم أعد المحاولة.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(patternConfigProvider);
    final controllerState = ref.watch(patternStudioControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('استوديو الباترون'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MyPatternRequestsPage()));
            },
          ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.')),
        data: (config) {
          if (!config.enabled) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('هذه الميزة غير مفعّلة حاليًا من إدارة المنصة',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'رسوم الخدمة: ${config.price.formatted}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('اختر نوع المانيكان'),
                const SizedBox(height: 8),
                SegmentedButton<MannequinType>(
                  segments: MannequinType.values
                      .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                      .toList(),
                  selected: {_mannequinType},
                  onSelectionChanged: (s) =>
                      setState(() => _mannequinType = s.first),
                ),
                const SizedBox(height: 20),
                if (_pickedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CrossPlatformImage(
                        file: _pickedImage!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('رفع صورة القطعة'),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                      labelText: 'ملاحظات إضافية للمصمم (اختياري)'),
                ),
                const SizedBox(height: 24),
                AuthButton(
                  label: 'دفع وإرسال الطلب',
                  isLoading: controllerState.isLoading || _isUploading,
                  onPressed: _pickedImage == null ? null : _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
