import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';

/// الإعلانات الممولة: كل إعلان يُنشَر مقابل ذهب أو جواهر تحت أيقونة
/// يختارها الناشر من كتالوج يديره المالك (سعرًا وإضافةً وحذفًا)، ويُعرض
/// مصنَّفًا تحت تلك الأيقونة. استُبدلت بوابة العضوية (canCreateAds) التي
/// لم تكن تخصم شيئًا فعليًا بدفع مباشر لكل إعلان.
class SponsoredAdsPage extends ConsumerStatefulWidget {
  const SponsoredAdsPage({super.key});
  @override
  ConsumerState<SponsoredAdsPage> createState() => _SponsoredAdsPageState();
}

class _SponsoredAdsPageState extends ConsumerState<SponsoredAdsPage> {
  bool _isOwner = false;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final owner = await Supabase.instance.client.rpc('is_my_platform_owner');
      final cats = await Supabase.instance.client
          .from('sponsored_ad_categories')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      if (mounted) {
        setState(() {
          _isOwner = owner == true;
          _categories = List<Map<String, dynamic>>.from(cats as List);
        });
      }
    } catch (_) {}
  }

  Future<void> _manageCategories() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF120A24),
      builder: (_) => _CategoryManagerSheet(onChanged: _load),
    );
  }

  Future<void> _create() async {
    final textCtrl = TextEditingController();
    String? selectedCategory;
    Uint8List? imageBytes;
    String? imageName;
    bool uploading = false;
    await _load();
    if (!mounted) return;
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد فئات إعلانات متاحة بعد.')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) => AlertDialog(
          title: const Text('إعلان ممول جديد'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('اختر الفئة', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in _categories)
                  ChoiceChip(
                    label: Text('${c['emoji']} ${c['label_ar']} • ${((c['gems_cost'] as num?) ?? 0) > 0 ? '💎${c['gems_cost']}' : '⭐${c['points_cost']}'}'),
                    selected: selectedCategory == c['category_key'],
                    onSelected: (_) => setLocal(() => selectedCategory = c['category_key'].toString()),
                  ),
              ]),
              const SizedBox(height: 12),
              TextField(controller: textCtrl, maxLines: 3, maxLength: 200,
                  decoration: const InputDecoration(labelText: 'نص الإعلان')),
              const SizedBox(height: 4),
              // صورة اختيارية من معرض الهاتف — تُرفع للخادم عند النشر.
              Row(children: [
                if (imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(imageBytes!, width: 56, height: 56, fit: BoxFit.cover),
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (picked == null) return;
                    final bytes = await picked.readAsBytes();
                    setLocal(() {
                      imageBytes = bytes;
                      imageName = picked.name;
                    });
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text(imageBytes == null ? 'إضافة صورة (اختياري)' : 'تغيير الصورة'),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: selectedCategory == null || textCtrl.text.trim().isEmpty || uploading
                  ? null
                  : () => Navigator.pop(d, true),
              child: const Text('نشر'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || selectedCategory == null) return;
    final text = textCtrl.text.trim();
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    try {
      String? imageUrl;
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (imageBytes != null && uid != null) {
        imageUrl = await MediaUploadService(bucket: 'media').uploadBytes(
          bytes: imageBytes!,
          fileName: imageName ?? 'ad.jpg',
          folder: 'sponsored_ads',
          uid: uid,
        );
      }
      await Supabase.instance.client.rpc('create_sponsored_ad', params: {
        'p_text': text,
        'p_category_key': selectedCategory,
        if (imageUrl != null) 'p_image_url': imageUrl,
      });
      m.showSnackBar(const SnackBar(content: Text('تم نشر الإعلان ✓')));
    } catch (e) {
      final t = e.toString();
      m.showSnackBar(SnackBar(content: Text(
        t.contains('INSUFFICIENT_GEMS') ? 'رصيدك من الجواهر لا يكفي.'
        : t.contains('INSUFFICIENT_POINTS') ? 'رصيدك من النقاط لا يكفي.'
        : 'تعذّر نشر الإعلان: $e',
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعلانات الممولة — مشاريعنا'),
        actions: [
          if (_isOwner)
            IconButton(
                tooltip: 'إدارة الفئات والأسعار',
                onPressed: _manageCategories,
                icon: const Icon(Icons.admin_panel_settings_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('نشر إعلان'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('sponsored_ads')
            .stream(primaryKey: ['id'])
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .limit(100),
        builder: (context, s) {
          if (s.hasError) {
            return Center(child: Text('تعذر تحميل الإعلانات: ${s.error}'));
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = s.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('لا توجد إعلانات ممولة حاليًا'));
          }
          // تُعرض مصنَّفة تحت أيقونتها (التصنيف المختار عند النشر).
          final byCategory = <String, List<Map<String, dynamic>>>{};
          for (final r in rows) {
            final key = r['category_key']?.toString() ?? 'بلا فئة';
            byCategory.putIfAbsent(key, () => []).add(r);
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final entry in byCategory.entries) ...[
                _categoryHeader(entry.key),
                const SizedBox(height: 6),
                for (final ad in entry.value) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.gold.withValues(alpha: .3))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // اسم الناشر — بنفس مكوّن الغرف، فيحمل معه الألوان
                      // والشارات والتأثيرات التي اشتراها العضو. لم يكن
                      // يُعرض إطلاقًا هنا رغم أنه هوية صاحب الإعلان.
                      if ((ad['author_uid']?.toString() ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ServerUsernameDisplay(
                            uid: ad['author_uid'].toString(),
                            fallbackName: 'عضو',
                            fallbackFontSize: 13,
                            showBadges: true,
                            compactBadges: true,
                          ),
                        ),
                      if ((ad['image_url']?.toString() ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(ad['image_url'].toString(),
                                height: 150, width: double.infinity, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                          ),
                        ),
                      Text(ad['text']?.toString() ?? '',
                          style: const TextStyle(color: Colors.white)),
                    ]),
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _categoryHeader(String key) {
    final cat = _categories.where((c) => c['category_key'] == key).firstOrNull;
    final label = cat == null ? key : '${cat['emoji']} ${cat['label_ar']}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(label,
          style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w900)),
    );
  }
}

/// إدارة فئات الإعلانات للمالك: إضافة، تعديل السعر، حذف. يتحكم بها
/// بالكامل — الرمز، الاسم، السعر بالنقاط أو الجواهر، التفعيل.
class _CategoryManagerSheet extends StatefulWidget {
  final VoidCallback onChanged;
  const _CategoryManagerSheet({required this.onChanged});
  @override
  State<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<_CategoryManagerSheet> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await Supabase.instance.client
        .from('sponsored_ad_categories')
        .select()
        .order('sort_order');
    if (mounted) {
      setState(() {
        _all = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    }
  }

  Future<void> _edit([Map<String, dynamic>? c]) async {
    final key = TextEditingController(text: c?['category_key']?.toString() ?? '');
    final emoji = TextEditingController(text: c?['emoji']?.toString() ?? '🧵');
    final label = TextEditingController(text: c?['label_ar']?.toString() ?? '');
    final gems = TextEditingController(text: '${c?['gems_cost'] ?? 100}');
    final points = TextEditingController(text: '${c?['points_cost'] ?? 0}');
    var active = c?['is_active'] != false;
    final m = ScaffoldMessenger.maybeOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) => AlertDialog(
          title: Text(c == null ? 'فئة جديدة' : 'تعديل الفئة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: key, enabled: c == null,
                  decoration: const InputDecoration(labelText: 'المعرّف (إنجليزي، مثل tailoring)')),
              TextField(controller: emoji, decoration: const InputDecoration(labelText: 'الرمز (إيموجي)')),
              TextField(controller: label, decoration: const InputDecoration(labelText: 'الاسم الظاهر')),
              Row(children: [
                Expanded(child: TextField(controller: points, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'نقاط ⭐'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: gems, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'جواهر 💎'))),
              ]),
              SwitchListTile(value: active, onChanged: (v) => setLocal(() => active = v),
                  title: const Text('مفعّلة')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await Supabase.instance.client.rpc('owner_upsert_sponsored_ad_category', params: {
          'p_category_key': key.text.trim(),
          'p_emoji': emoji.text.trim(),
          'p_label_ar': label.text.trim(),
          'p_points_cost': int.tryParse(points.text.trim()) ?? 0,
          'p_gems_cost': int.tryParse(gems.text.trim()) ?? 0,
          'p_is_active': active,
        });
        await _load();
        widget.onChanged();
      } catch (e) {
        m?.showSnackBar(SnackBar(content: Text('تعذّر الحفظ: $e')));
      }
    }
  }

  Future<void> _delete(String key) async {
    final m = ScaffoldMessenger.maybeOf(context);
    try {
      await Supabase.instance.client
          .rpc('owner_delete_sponsored_ad_category', params: {'p_category_key': key});
      await _load();
      widget.onChanged();
    } catch (e) {
      m?.showSnackBar(SnackBar(content: Text('تعذّر الحذف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Expanded(
                  child: Text('فئات الإعلانات الممولة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => _edit(), icon: const Icon(Icons.add_circle, color: Color(0xFFFFD700))),
            ]),
            const Divider(color: Colors.white24),
            if (_loading)
              const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
            else
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final c in _all)
                    ListTile(
                      leading: Text(c['emoji']?.toString() ?? '🧵', style: const TextStyle(fontSize: 20)),
                      title: Text(c['label_ar']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '${((c['gems_cost'] as num?) ?? 0) > 0 ? '💎 ${c['gems_cost']}' : '⭐ ${c['points_cost']}'}'
                        '${c['is_active'] == false ? ' — معطّلة' : ''}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => _edit(c)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _delete(c['category_key'].toString())),
                      ]),
                    ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
