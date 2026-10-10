import 'dart:typed_data';
import '../../../../core/services/snack_sfx.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../member_badges/data/member_badge_repository.dart';
import '../../../member_badges/domain/member_badge.dart';
import '../../../member_badges/presentation/member_badge_providers.dart';
import '../../../search/presentation/providers/search_provider.dart';

class AdminChatBadgesTab extends ConsumerStatefulWidget {
  const AdminChatBadgesTab({super.key});

  @override
  ConsumerState<AdminChatBadgesTab> createState() => _AdminChatBadgesTabState();
}

class _AdminChatBadgesTabState extends ConsumerState<AdminChatBadgesTab> {
  final MemberBadgeRepository _repo = MemberBadgeRepository();
  final _searchController = TextEditingController();
  Future<List<MemberBadge>>? _future;
  String _query = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    _future = _repo.listForAdmin();
    if (mounted) setState(() {});
  }

  Future<_ValidatedGif?> _pickGif() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gif'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) throw StateError('EMPTY_GIF');
    if (bytes.length > 512 * 1024) throw StateError('GIF_TOO_LARGE');
    final extension = (file.extension ?? '').toLowerCase();
    // file_picker 11.x exposes the selected file extension, but PlatformFile
    // does not expose mimeType. The actual GIF header is validated below, so
    // extension + binary signature gives us the required format validation.
    if (extension != 'gif') throw StateError('GIF_REQUIRED');
    final metadata = _analyzeGif(Uint8List.fromList(bytes));
    if (!metadata.valid) throw StateError(metadata.errorCode);
    if (metadata.frameCount < 2) throw StateError('GIF_NOT_ANIMATED');
    if (!metadata.transparent) throw StateError('GIF_NOT_TRANSPARENT');
    return _ValidatedGif(
      file: file,
      metadata: metadata,
      bytes: Uint8List.fromList(bytes),
    );
  }

  _GifMetadata _analyzeGif(Uint8List bytes) {
    if (bytes.length < 13) return const _GifMetadata.invalid('GIF_INVALID');
    final header = String.fromCharCodes(bytes.sublist(0, 6));
    if (header != 'GIF87a' && header != 'GIF89a') {
      return const _GifMetadata.invalid('GIF_INVALID');
    }
    final width = bytes[6] | (bytes[7] << 8);
    final height = bytes[8] | (bytes[9] << 8);
    if (width <= 0 || height <= 0) {
      return const _GifMetadata.invalid('GIF_INVALID');
    }
    var index = 13;
    final logicalPacked = bytes[10];
    if ((logicalPacked & 0x80) != 0) {
      index += 3 * (1 << ((logicalPacked & 0x07) + 1));
    }
    var frameCount = 0;
    var transparent = false;

    while (index < bytes.length) {
      final marker = bytes[index++];
      if (marker == 0x3b) break;
      if (marker == 0x2c) {
        if (index + 9 > bytes.length) return const _GifMetadata.invalid('GIF_INVALID');
        final packed = bytes[index + 8];
        frameCount++;
        index += 9;
        if ((packed & 0x80) != 0) {
          index += 3 * (1 << ((packed & 0x07) + 1));
          if (index > bytes.length) return const _GifMetadata.invalid('GIF_INVALID');
        }
        if (index >= bytes.length) return const _GifMetadata.invalid('GIF_INVALID');
        index++; // LZW minimum code size
        index = _skipSubBlocks(bytes, index);
        if (index < 0) return const _GifMetadata.invalid('GIF_INVALID');
        continue;
      }
      if (marker == 0x21) {
        if (index >= bytes.length) return const _GifMetadata.invalid('GIF_INVALID');
        final label = bytes[index++];
        if (label == 0xf9) {
          if (index >= bytes.length || bytes[index] != 4) {
            return const _GifMetadata.invalid('GIF_INVALID');
          }
          index++;
          if (index + 4 > bytes.length) return const _GifMetadata.invalid('GIF_INVALID');
          transparent = transparent || (bytes[index] & 0x01) != 0;
          index += 4;
          if (index >= bytes.length) return const _GifMetadata.invalid('GIF_INVALID');
          index++; // block terminator
        } else {
          index = _skipSubBlocks(bytes, index);
          if (index < 0) return const _GifMetadata.invalid('GIF_INVALID');
        }
        continue;
      }
      return const _GifMetadata.invalid('GIF_INVALID');
    }

    return _GifMetadata(
      width: width,
      height: height,
      frameCount: frameCount,
      transparent: transparent,
      errorCode: '',
    );
  }

  int _skipSubBlocks(Uint8List bytes, int index) {
    while (index < bytes.length) {
      final size = bytes[index++];
      if (size == 0) return index;
      index += size;
      if (index > bytes.length) return -1;
    }
    return -1;
  }

  Future<void> _createBadge() async {
    final form = await _showBadgeForm();
    if (form == null) return;
    setState(() => _busy = true);
    String? path;
    try {
      final picked = await _pickGif();
      if (picked == null) return;
      path = 'badges/v1/${form.badgeKey}.gif';
      final url = await SupabaseService.uploadBytesToBucket(
        bucket: 'member-badges',
        path: path,
        bytes: picked.bytes,
        contentType: 'image/gif',
        upsert: false,
        fileName: picked.file.name,
      );
      await _repo.create(
        badgeKey: form.badgeKey,
        nameAr: form.nameAr,
        category: form.category,
        description: form.description,
        assetPath: path,
        assetUrl: url,
        fileSizeBytes: picked.bytes.length,
        width: picked.metadata.width,
        height: picked.metadata.height,
        sortOrder: form.sortOrder,
      );
      if (mounted) _showMessage('تم إنشاء الشارة وحفظها في الخادم.');
      _reload();
    } catch (error) {
      if (path != null) {
        try {
          await SupabaseService.deleteStoragePath(bucket: 'member-badges', path: path);
        } catch (_) {}
      }
      if (mounted) _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editBadge(MemberBadge badge) async {
    final form = await _showBadgeForm(
      initialKey: badge.badgeKey,
      initialName: badge.nameAr,
      initialCategory: badge.category,
      initialDescription: badge.description ?? '',
    );
    if (form == null) return;
    setState(() => _busy = true);
    String assetPath = badge.assetPath;
    String assetUrl = badge.assetUrl;
    var fileSize = badge.fileSizeBytes;
    int? width = badge.width;
    int? height = badge.height;
    String? replacementPath;
    try {
      final picked = await _pickGif();
      if (picked != null) {
        replacementPath = 'badges/v1/${form.badgeKey}-${const Uuid().v4()}.gif';
        assetUrl = await SupabaseService.uploadBytesToBucket(
          bucket: 'member-badges',
          path: replacementPath,
          bytes: picked.bytes,
          contentType: 'image/gif',
          upsert: false,
          fileName: picked.file.name,
        );
        assetPath = replacementPath;
        fileSize = picked.bytes.length;
        width = picked.metadata.width;
        height = picked.metadata.height;
      }
      await _repo.update(
        badgeId: badge.id,
        badgeKey: form.badgeKey,
        nameAr: form.nameAr,
        category: form.category,
        description: form.description,
        assetPath: assetPath,
        assetUrl: assetUrl,
        fileSizeBytes: fileSize,
        width: width,
        height: height,
        sortOrder: form.sortOrder,
      );
      if (replacementPath != null && badge.assetPath.isNotEmpty) {
        try {
          await SupabaseService.deleteStoragePath(
            bucket: 'member-badges',
            path: badge.assetPath,
          );
        } catch (_) {}
      }
      if (mounted) _showMessage('تم تحديث الشارة.');
      _reload();
    } catch (error) {
      if (replacementPath != null) {
        try {
          await SupabaseService.deleteStoragePath(bucket: 'member-badges', path: replacementPath);
        } catch (_) {}
      }
      if (mounted) _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(MemberBadge badge) async {
    setState(() => _busy = true);
    try {
      await _repo.setActive(badge.id, !badge.active);
      if (mounted) _showMessage(badge.active ? 'تم إيقاف الشارة.' : 'تم تفعيل الشارة.');
      _reload();
    } catch (error) {
      if (mounted) _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignDialog(MemberBadge badge) async {
    _searchController.clear();
    _query = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final results = ref.watch(profileSearchResultsProvider(_query));
          return AlertDialog(
            title: Text('تعيين ${badge.nameAr}'),
            content: SizedBox(
              width: 540,
              height: 430,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(labelText: 'ابحث باسم المستخدم'),
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _query.isEmpty
                        ? const Center(child: Text('اكتب اسمًا للبحث'))
                        : results.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (_, __) => const Center(child: Text('تعذر تحميل المستخدمين الآن.')),
                            data: (profiles) => profiles.isEmpty
                                ? const Center(child: Text('لا توجد نتائج'))
                                : ListView.separated(
                                    itemCount: profiles.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (_, index) {
                                      final profile = profiles[index];
                                      return ListTile(
                                        title: Text(profile.displayName),
                                        subtitle: Text(profile.email),
                                        // mainAxisSize.min لا يحمي هنا:
                                        // RenderFlex يمرّر نفس قيد العرض
                                        // اللانهائي من trailing للأبناء
                                        // غير المرنين بصرف النظر عنه.
                                        trailing: ConstrainedBox(
                                          constraints:
                                              const BoxConstraints(maxWidth: 120),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                            IconButton(
                                              tooltip: 'إلغاء الشارة',
                                              icon: const Icon(Icons.remove_circle_outline),
                                              onPressed: _busy ? null : () async {
                                                try {
                                                  await _repo.clearForUser(profile.uid);
                                                  if (context.mounted) Navigator.pop(context);
                                                } catch (error) {
                                                  if (context.mounted) _showError(_friendlyError(error));
                                                }
                                              },
                                            ),
                                            FilledButton(
                                              onPressed: _busy ? null : () async {
                                                try {
                                                  await _repo.assignToUser(userId: profile.uid, badgeKey: badge.badgeKey);
                                                  ref.invalidate(memberBadgeForUserProvider(profile.uid));
                                                  if (context.mounted) Navigator.pop(context);
                                                } catch (error) {
                                                  if (context.mounted) _showError(_friendlyError(error));
                                                }
                                              },
                                              child: const Text('تعيين'),
                                            ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
            ],
          );
        },
      ),
    );
  }

  Future<_BadgeForm?> _showBadgeForm({
    String initialKey = '',
    String initialName = '',
    String initialCategory = 'animal',
    String initialDescription = '',
  }) {
    final key = TextEditingController(text: initialKey);
    final name = TextEditingController(text: initialName);
    final category = TextEditingController(text: initialCategory);
    final description = TextEditingController(text: initialDescription);
    final sort = TextEditingController(text: '0');
    return showDialog<_BadgeForm>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(initialKey.isEmpty ? 'إنشاء شارة عضو' : 'تحديث شارة عضو'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: key, enabled: initialKey.isEmpty, decoration: const InputDecoration(labelText: 'المفتاح التقني')),
              TextField(controller: name, maxLength: 80, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: 'اسم الشارة')),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'التصنيف')),
              TextField(controller: description, maxLength: 300, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: 'الوصف (اختياري)')),
              TextField(controller: sort, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ترتيب العرض')),
              const SizedBox(height: 8),
              const Text('GIF متحرك وشفاف فقط • الحد الأقصى 512KB'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final k = key.text.trim().toLowerCase();
              final n = name.text.trim();
              if (k.length < 3 || n.isEmpty) return;
              Navigator.pop(dialogContext, _BadgeForm(
                badgeKey: k,
                nameAr: n,
                category: category.text.trim().isEmpty ? 'general' : category.text.trim(),
                description: description.text.trim().isEmpty ? null : description.text.trim(),
                sortOrder: int.tryParse(sort.text.trim()) ?? 0,
              ));
            },
            child: const Text('متابعة ثم اختيار GIF'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('FORBIDDEN')) return 'لا تملك صلاحية إدارة الشارات.';
    if (raw.contains('AUTH_REQUIRED')) return 'انتهت الجلسة. سجّل الدخول مجددًا.';
    if (raw.contains('GIF_REQUIRED')) return 'الأصل المطلوب GIF فقط.';
    if (raw.contains('GIF_TOO_LARGE')) return 'حجم GIF يتجاوز 512KB.';
    if (raw.contains('GIF_NOT_ANIMATED')) return 'يجب أن يكون GIF متحركًا ويحتوي على أكثر من إطار.';
    if (raw.contains('GIF_NOT_TRANSPARENT')) return 'يجب أن يحتوي GIF على شفافية.';
    if (raw.contains('GIF_INVALID')) return 'ملف GIF غير صالح.';
    if (raw.contains('BADGE_KEY_EXISTS')) return 'المفتاح التقني مستخدم بالفعل.';
    if (raw.contains('BADGE_NOT_AVAILABLE')) return 'الشارة غير متاحة أو متوقفة.';
    if (raw.contains('USER_NOT_AVAILABLE')) return 'المستخدم غير متاح حاليًا.';
    return 'تعذر تنفيذ العملية الآن.';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error));
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: _busy,
      child: FutureBuilder<List<MemberBadge>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(_friendlyError(snapshot.error!)));
          final badges = snapshot.data ?? const <MemberBadge>[];
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: Text('شارة العضو', textAlign: TextAlign.right, style: Theme.of(context).textTheme.titleLarge)),
                    FilledButton.icon(onPressed: _createBadge, icon: const Icon(Icons.gif_box_outlined), label: const Text('إضافة GIF')),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('كتالوج مستقل: إنشاء ورفع وتحديث وتفعيل/إيقاف وإسناد للمستخدمين.', textAlign: TextAlign.right),
                const SizedBox(height: 16),
                if (badges.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد شارات منشأة بعد.'))),
                for (final badge in badges)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(width: 64, height: 64, child: Image.network(badge.assetUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(badge.nameAr, style: const TextStyle(fontWeight: FontWeight.w900)),
                                Text(badge.badgeKey),
                                Text('${badge.category} • ${(badge.fileSizeBytes / 1024).toStringAsFixed(0)}KB • ${badge.active ? 'مفعلة' : 'متوقفة'}${badge.width != null && badge.height != null ? ' • ${badge.width}×${badge.height}' : ''}'),
                                const SizedBox(height: 7),
                                Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 6, children: [
                                  OutlinedButton.icon(onPressed: () => _editBadge(badge), icon: const Icon(Icons.edit, size: 18), label: const Text('تحديث')),
                                  OutlinedButton.icon(onPressed: badge.active ? () => _assignDialog(badge) : null, icon: const Icon(Icons.person_add_alt_1), label: const Text('تعيين للمستخدم')),
                                ]),
                              ],
                            ),
                          ),
                          Switch(value: badge.active, onChanged: (_) => _toggle(badge)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ValidatedGif {
  final PlatformFile file;
  final _GifMetadata metadata;
  final Uint8List bytes;

  const _ValidatedGif({required this.file, required this.metadata, required this.bytes});
}

class _GifMetadata {
  final int width;
  final int height;
  final int frameCount;
  final bool transparent;
  final String errorCode;

  const _GifMetadata({required this.width, required this.height, required this.frameCount, required this.transparent, required this.errorCode});
  const _GifMetadata.invalid(String code) : width = 0, height = 0, frameCount = 0, transparent = false, errorCode = code;
  bool get valid => errorCode.isEmpty;
}

class _BadgeForm {
  final String badgeKey;
  final String nameAr;
  final String category;
  final String? description;
  final int sortOrder;

  const _BadgeForm({required this.badgeKey, required this.nameAr, required this.category, required this.description, required this.sortOrder});
}
