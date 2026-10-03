import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/widgets/cross_platform_image.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/auth_button.dart';
import '../../domain/entities/content_categories.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/post_provider.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  final String? initialCategory;
  const CreatePostPage({super.key, this.initialCategory});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _textController = TextEditingController();
  final _tagsController = TextEditingController();
  late String _category;
  XFile? _pickedImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? ContentCategories.general;
  }

  @override
  void dispose() {
    _textController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _pickedImage = picked);
    }
  }

  Future<void> _submit() async {
    final uid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (uid == null) return;

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    String? uploadedUrl;
    if (_pickedImage != null) {
      setState(() => _isUploading = true);
      try {
        uploadedUrl = await sl<MediaUploadService>().uploadFile(
          file: _pickedImage!,
          folder: 'posts',
          uid: uid,
        );
      } catch (e) {
        setState(() => _isUploading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر رفع الصورة: $e')),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _isUploading = false);
    }

    if (!mounted) return;
    final post = PostEntity(
      id: '',
      authorUid: uid,
      text: _textController.text.trim(),
      category: _category,
      tags: tags,
      mediaUrls: uploadedUrl != null ? [uploadedUrl] : const [],
      mediaType: uploadedUrl != null ? PostMediaType.image : PostMediaType.none,
      createdAt: DateTime.now(),
    );

    if (!mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final success =
        await ref.read(postControllerProvider.notifier).createPost(post);

    if (!mounted) return;

    if (success) {
      navigator.pop();
    } else {
      if (uploadedUrl != null) {
        try {
          await MediaUploadService().deleteFile(uploadedUrl);
        } catch (_) {}
      }
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر نشر المنشور الآن. تحقق من البيانات والاتصال ثم أعد المحاولة.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(postControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('منشور جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'القسم'),
                items: ContentCategories.all
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(ContentCategories.labelOf(c))))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _textController,
                maxLines: 6,
                textAlign: TextAlign.right,
                decoration:
                    const InputDecoration(labelText: 'ماذا تريد أن تشارك؟'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tagsController,
                textAlign: TextAlign.right,
                decoration:
                    const InputDecoration(labelText: 'وسوم (مفصولة بفاصلة)'),
              ),
              const SizedBox(height: 16),
              if (_pickedImage != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CrossPlatformImage(
                          file: _pickedImage!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() => _pickedImage = null),
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('إضافة صورة'),
                ),
              const SizedBox(height: 24),
              AuthButton(
                label: 'نشر',
                isLoading: controllerState.isLoading || _isUploading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
