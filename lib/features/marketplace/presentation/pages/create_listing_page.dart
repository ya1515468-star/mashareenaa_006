import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/widgets/cross_platform_image.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/auth_button.dart';
import '../../../wallet/domain/entities/currency.dart';
import '../../domain/entities/listing_entity.dart';
import '../providers/marketplace_provider.dart';

class CreateListingPage extends ConsumerStatefulWidget {
  final String? initialCategory;
  const CreateListingPage({super.key, this.initialCategory});

  @override
  ConsumerState<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends ConsumerState<CreateListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  late String _category;
  ListingType _type = ListingType.product;
  Currency _currency = Currency.shamCash;
  XFile? _pickedImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? MarketplaceCategories.other;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) setState(() => _pickedImage = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (uid == null) return;

    String? imageUrl;
    if (_pickedImage != null) {
      setState(() => _isUploading = true);
      try {
        imageUrl = await sl<MediaUploadService>()
            .uploadFile(file: _pickedImage!, folder: 'listings', uid: uid);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذّر رفع الصورة: $e')));
        return;
      }
      if (!mounted) return;
      setState(() => _isUploading = false);
    }

    if (!mounted) return;
    final priceValue = double.tryParse(_priceController.text.trim()) ?? 0;
    final listing = ListingEntity(
      id: '',
      sellerUid: uid,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      price: Money(minorUnits: (priceValue * 100).round(), currency: _currency),
      type: _type,
      category: _category,
      imageUrls: imageUrl != null ? [imageUrl] : const [],
      createdAt: DateTime.now(),
    );

    final messenger = ScaffoldMessenger.of(context);

    final success = await ref
        .read(marketplaceControllerProvider.notifier)
        .createListing(listing);

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      if (imageUrl != null) {
        try {
          await MediaUploadService().deleteFile(imageUrl);
        } catch (_) {}
        if (!mounted) return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر نشر العرض الآن. تحقق من البيانات والاتصال ثم أعد المحاولة.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(marketplaceControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('إعلان جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<ListingType>(
                  segments: const [
                    ButtonSegment(
                        value: ListingType.product, label: Text('منتج')),
                    ButtonSegment(
                        value: ListingType.service, label: Text('خدمة')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'القسم'),
                  items: MarketplaceCategories.all
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(MarketplaceCategories.labelOf(c))))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'الرجاء إدخال عنوان'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'السعر'),
                        validator: (v) {
                          final val = double.tryParse(v ?? '');
                          if (val == null || val <= 0) return 'سعر غير صحيح';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<Currency>(
                      value: _currency,
                      items: const [
                        DropdownMenuItem(
                            value: Currency.shamCash, child: Text('شام كاش')),
                        DropdownMenuItem(
                            value: Currency.usd, child: Text('دولار')),
                      ],
                      onChanged: (v) =>
                          setState(() => _currency = v ?? _currency),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_pickedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CrossPlatformImage(
                        file: _pickedImage!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('إضافة صورة'),
                  ),
                const SizedBox(height: 24),
                AuthButton(
                  label: 'نشر الإعلان',
                  isLoading: controllerState.isLoading || _isUploading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
