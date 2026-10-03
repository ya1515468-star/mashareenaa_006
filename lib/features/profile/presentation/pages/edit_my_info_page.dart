import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/profile_entity.dart';
import '../providers/profile_provider.dart';

/// "تحرير معلوماتي" — منفصلة عن "تحرير البيانات" الأساسية: تُدير
/// قائمة الخبرات وروابط التواصل الاجتماعي فقط.
class EditMyInfoPage extends ConsumerStatefulWidget {
  final ProfileEntity profile;
  const EditMyInfoPage({super.key, required this.profile});

  @override
  ConsumerState<EditMyInfoPage> createState() => _EditMyInfoPageState();
}

class _EditMyInfoPageState extends ConsumerState<EditMyInfoPage> {
  late List<String> _experiences;
  late List<SocialLink> _socialLinks;
  final _experienceController = TextEditingController();
  final _platformController = TextEditingController();
  final _urlController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _experiences = List.of(widget.profile.experiences);
    _socialLinks = List.of(widget.profile.socialLinks);
  }

  @override
  void dispose() {
    _experienceController.dispose();
    _platformController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _addExperience() {
    final text = _experienceController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _experiences.add(text);
      _experienceController.clear();
    });
  }

  void _addSocialLink() {
    final platform = _platformController.text.trim();
    final url = _urlController.text.trim();
    if (platform.isEmpty || url.isEmpty) return;
    setState(() {
      _socialLinks.add(SocialLink(platform: platform, url: url));
      _platformController.clear();
      _urlController.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.profile.copyWith(
      experiences: _experiences,
      socialLinks: _socialLinks,
      updatedAt: DateTime.now(),
    );
    final success = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('فشل حفظ التعديلات')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحرير معلوماتي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('الخبرات', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _experiences
                .map((e) => Chip(
                      label: Text(e),
                      onDeleted: () => setState(() => _experiences.remove(e)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _experienceController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'أضف خبرة'),
                  onSubmitted: (_) => _addExperience(),
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.gold),
                  onPressed: _addExperience),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 16),
          Text('روابط التواصل الاجتماعي',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._socialLinks.map((s) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link, color: AppColors.gold),
                title: Text(s.platform),
                subtitle: Text(s.url,
                    style: const TextStyle(color: AppColors.textSecondary)),
                trailing: IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => setState(() => _socialLinks.remove(s)),
                ),
              )),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _platformController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'المنصة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _urlController,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'الرابط'),
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.gold),
                  onPressed: _addSocialLink),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
