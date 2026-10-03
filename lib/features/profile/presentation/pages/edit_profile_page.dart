import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/cross_platform_image.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/auth_button.dart';
import '../../../auth/presentation/widgets/auth_text_field.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/profile_storage_cleanup.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/manual_avatar_cropper.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  final ProfileEntity profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _statusController;
  late final TextEditingController _musicUrlController;
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  late final TextEditingController _professionController;
  late ProfileVisibility _visibility;
  XFile? _pickedAvatar;
  XFile? _pickedCover;
  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _bioController = TextEditingController(text: widget.profile.bio);
    _statusController =
        TextEditingController(text: widget.profile.statusText ?? '');
    _musicUrlController =
        TextEditingController(text: widget.profile.profileMusicUrl ?? '');
    _countryController =
        TextEditingController(text: widget.profile.country ?? '');
    _cityController = TextEditingController(text: widget.profile.city ?? '');
    _professionController =
        TextEditingController(text: widget.profile.profession ?? '');
    _visibility = widget.profile.visibility;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _statusController.dispose();
    _musicUrlController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      final cropped = await cropAvatarBeforeUpload(context, picked);
      if (cropped != null && mounted) {
        setState(() => _pickedAvatar = cropped);
      }
    }
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _pickedCover = picked);
    }
  }


  String _profileUploadError(Object error, String label) {
    final raw = error is ServerException ? error.message : error.toString();
    final quota = RegExp(r'AVATAR_QUOTA_EXCEEDED\s*:\s*([^,\)]+)').firstMatch(raw);
    if (quota != null) return quota.group(1)!.trim();
    if (error is ServerException) return error.message;
    final text = error.toString().trim();
    return text.isEmpty ? 'لم يتم رفع $label. تحقق من نوع الملف وحاول مرة أخرى.' : text;
  }

  Future<bool> _confirmPendingUploads() async {
    final labels = <String>[];
    if (_pickedAvatar != null) labels.add('صورة المستخدم');
    if (_pickedCover != null) labels.add('خلفية البروفايل');
    if (labels.isEmpty) return true;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد رفع الصور'),
        content: Text(
          'سيتم رفع ${labels.join(' و ')} إلى خادم Mashareena ثم حفظ الروابط وتحديث البروفايل فورًا.\n\nهل تريد المتابعة؟',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('رفع وحفظ'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _confirmPendingUploads()) return;

    final uid = ref.read(authControllerProvider).valueOrNull?.uid;
    String? newAvatarUrl = widget.profile.avatarUrl;
    String? newCoverUrl = widget.profile.coverUrl;
    var avatarWasUploaded = false;
    var coverWasUploaded = false;

    // الحصة تُفحص قبل الرفع حتى لا يُرفع ملف ثم يرفضه الخادم. الفرض الحقيقي
    // خادمي (trg_enforce_avatar_quota)؛ هذا الفحص لتجربة أوضح فقط.
    if (_pickedAvatar != null && uid != null) {
      try {
        final q = await Supabase.instance.client.rpc('get_my_avatar_quota');
        if (q is Map && q['unlimited'] != true && (q['remaining'] as num? ?? 1) <= 0) {
          if (!mounted) return;
          final resets = DateTime.tryParse(q['resets_at']?.toString() ?? '');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('استنفدت حصتك من تغيير الصورة هذا الشهر '
                '(${q['used']} من ${q['limit']}).'
                '${resets == null ? '' : ' تتجدد في ${resets.year}/${resets.month}/${resets.day}.'}'),
          ));
          return;
        }
      } catch (_) {/* الخادم يفرض الحصة على أي حال */}
    }

    try {
      if (_pickedAvatar != null && uid != null) {
        setState(() => _isUploadingAvatar = true);
        newAvatarUrl =
            await MediaUploadService(bucket: 'profile-avatars').uploadFile(
          file: _pickedAvatar!,
          folder: uid,
          uid: uid,
        );
        avatarWasUploaded = true;
        if (mounted) setState(() => _isUploadingAvatar = false);
      }

      if (_pickedCover != null && uid != null) {
        setState(() => _isUploadingCover = true);
        newCoverUrl =
            await MediaUploadService(bucket: 'profile-avatars').uploadFile(
          file: _pickedCover!,
          folder: uid,
          uid: uid,
        );
        coverWasUploaded = true;
        if (mounted) setState(() => _isUploadingCover = false);
      }

      final updated = widget.profile.copyWith(
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: newAvatarUrl,
        coverUrl: newCoverUrl,
        statusText: _statusController.text.trim(),
        profileMusicUrl: _musicUrlController.text.trim(),
        country: _countryController.text.trim(),
        city: _cityController.text.trim(),
        profession: _professionController.text.trim(),
        visibility: _visibility,
        updatedAt: DateTime.now(),
        // When a new static avatar was uploaded, clear the previous animated avatar.
        animatedAvatarUrl: avatarWasUploaded ? '' : widget.profile.animatedAvatarUrl,
      );

      final success = await ref
          .read(profileControllerProvider.notifier)
          .updateProfile(updated);

      if (!success) {
        if (avatarWasUploaded) {
          try {
            await ProfileStorageCleanup.deletePublicFile(
              bucket: 'profile-avatars',
              publicUrl: newAvatarUrl,
            );
          } catch (_) {}
        }
        if (coverWasUploaded) {
          try {
            await ProfileStorageCleanup.deletePublicFile(
              bucket: 'profile-avatars',
              publicUrl: newCoverUrl,
            );
          } catch (_) {}
        }
        if (!mounted) return;
        final state = ref.read(profileControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.error?.toString() ?? 'فشل تحديث الملف الشخصي',
            ),
          ),
        );
        return;
      }

      // Remove replaced files only after the new profile row is confirmed.
      if (avatarWasUploaded &&
          widget.profile.avatarUrl != null &&
          widget.profile.avatarUrl != newAvatarUrl) {
        try {
          await ProfileStorageCleanup.deletePublicFile(
            bucket: 'profile-avatars',
            publicUrl: widget.profile.avatarUrl,
          );
        } catch (_) {}
      }
      if (coverWasUploaded &&
          widget.profile.coverUrl != null &&
          widget.profile.coverUrl != newCoverUrl) {
        try {
          await ProfileStorageCleanup.deletePublicFile(
            bucket: 'profile-avatars',
            publicUrl: widget.profile.coverUrl,
          );
        } catch (_) {}
      }

      ref.invalidate(currentProfileProvider);
      ref.invalidate(profileByIdProvider(widget.profile.uid));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
          _isUploadingCover = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_profileUploadError(e, 'الملف الشخصي'))),
        );
      }
      // If an upload succeeded but the following step failed, clean it.
      if (avatarWasUploaded) {
        try {
          await ProfileStorageCleanup.deletePublicFile(
            bucket: 'profile-avatars',
            publicUrl: newAvatarUrl,
          );
        } catch (_) {}
      }
      if (coverWasUploaded) {
        try {
          await ProfileStorageCleanup.deletePublicFile(
            bucket: 'profile-avatars',
            publicUrl: newCoverUrl,
          );
        } catch (_) {}
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
          _isUploadingCover = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(profileControllerProvider);
    final isLoading =
        controllerState.isLoading || _isUploadingAvatar || _isUploadingCover;

    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الملف الشخصي')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: _pickCover,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_pickedCover != null)
                          CrossPlatformImage(
                              file: _pickedCover!, fit: BoxFit.cover)
                        else if (widget.profile.coverUrl != null &&
                            widget.profile.coverUrl!.isNotEmpty)
                          Image.network(
                            widget.profile.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: Theme.of(context).colorScheme.surface),
                          )
                        else
                          Container(
                              color: Theme.of(context).colorScheme.surface),
                        const Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircleAvatar(
                              radius: 14,
                              child: Icon(Icons.camera_alt, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        _pickedAvatar != null
                            ? ClipOval(
                                child: SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: CrossPlatformImage(
                                      file: _pickedAvatar!, fit: BoxFit.cover),
                                ),
                              )
                            : ProfileAvatar(
                                avatarUrl: widget.profile.avatarUrl,
                                userId: widget.profile.uid,
                                displayName: widget.profile.displayName,
                                radius: 48,
                              ),
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 14,
                            child: Icon(Icons.camera_alt, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AuthTextField(
                  controller: _nameController,
                  label: 'الاسم الكامل',
                  prefixIcon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال الاسم';
                    }
                    if (value.trim().length >
                        AppValidation.maxDisplayNameLength) {
                      return 'الاسم طويل جدًا';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _bioController,
                  label: 'نبذة عني',
                  prefixIcon: Icons.info_outline,
                  validator: (value) {
                    if (value != null &&
                        value.length > AppValidation.maxBioLength) {
                      return 'النبذة طويلة جدًا';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _statusController,
                  label: 'الحالة (مثال: متاح، مشغول، بعيد قليلاً)',
                  prefixIcon: Icons.emoji_emotions_outlined,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _musicUrlController,
                  label: 'رابط موسيقى/يوتيوب للبروفايل (اختياري)',
                  prefixIcon: Icons.music_note_outlined,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _professionController,
                  label: 'المهنة',
                  prefixIcon: Icons.work_outline,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AuthTextField(
                        controller: _countryController,
                        label: 'الدولة',
                        prefixIcon: Icons.public,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AuthTextField(
                        controller: _cityController,
                        label: 'المدينة',
                        prefixIcon: Icons.location_city,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('خصوصية الحساب',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ProfileVisibility>(
                  segments: const [
                    ButtonSegment(
                        value: ProfileVisibility.public, label: Text('عام')),
                    ButtonSegment(
                        value: ProfileVisibility.private, label: Text('خاص')),
                  ],
                  selected: {_visibility},
                  onSelectionChanged: (s) =>
                      setState(() => _visibility = s.first),
                ),
                AuthButton(
                    label: 'حفظ التعديلات',
                    isLoading: isLoading,
                    onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
