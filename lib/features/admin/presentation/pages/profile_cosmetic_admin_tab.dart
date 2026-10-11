import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// البند 22: تحكّم المالك الشامل بعناصر متجر الملف الشخصي — ومنها قسم
/// «تلوين الرتبة».
///
/// كانت هذه اللوحة تربط دالة واحدة فقط (update_profile_cosmetic_price)،
/// بينما الخادم يوفّر أصلًا ثلاث دوال أخرى محميّة لم تكن مربوطة بأي زر:
///   - admin_update_profile_cosmetic  (تعديل الاسم والسعر والتفعيل والترتيب)
///   - admin_force_user_profile_cosmetic (منح/إهداء العنصر لعضو بعينه)
///   - admin_delete_profile_cosmetic  (حذف العنصر)
/// كلها تأخذ p_request_id لمنع التنفيذ المزدوج، وكلها تُنفَّذ خادميًا.
class ProfileCosmeticAdminTab extends StatefulWidget {
  const ProfileCosmeticAdminTab({super.key});
  @override
  State<ProfileCosmeticAdminTab> createState() =>
      _ProfileCosmeticAdminTabState();
}

class _ProfileCosmeticAdminTabState extends State<ProfileCosmeticAdminTab> {
  final _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future = _load();
  final _search = TextEditingController();
  String _category = 'الكل';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _db.rpc('get_profile_cosmetic_catalog', params: {});
    return List<Map<String, dynamic>>.from(rows as List);
  }

  void _reload() => setState(() => _future = _load());

  void _say(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(m)));
  }

  // ─── تعديل شامل ────────────────────────────────────────────────────
  Future<void> _edit(Map<String, dynamic> item) async {
    final name = TextEditingController(text: item['name_ar']?.toString() ?? '');
    final points =
        TextEditingController(text: '${item['price_points'] ?? 0}');
    final gems = TextEditingController(text: '${item['price_gems'] ?? 0}');
    final order = TextEditingController(text: '${item['sort_order'] ?? 0}');
    var active = item['is_active'] != false;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, setLocal) => AlertDialog(
            title: Text(item['item_key']?.toString() ?? 'عنصر'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'الاسم العربي')),
                TextField(
                    controller: points,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'سعر النقاط')),
                TextField(
                    controller: gems,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'سعر الجواهر')),
                TextField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الترتيب')),
                SwitchListTile(
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                  title: const Text('مُفعَّل'),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('حفظ')),
            ],
          ),
        ),
      );
      if (ok != true || !mounted) return;
      await _db.rpc('admin_update_profile_cosmetic', params: {
        'p_item_key': item['item_key'],
        'p_name_ar': name.text.trim(),
        'p_price_points': int.tryParse(points.text.trim()) ?? 0,
        'p_price_gems': int.tryParse(gems.text.trim()) ?? 0,
        'p_is_active': active,
        'p_sort_order': int.tryParse(order.text.trim()) ?? 0,
        'p_request_id': const Uuid().v4(),
      });
      _reload();
      _say('تم الحفظ خادميًا ✓');
    } catch (_) {
      _say('تعذّر الحفظ. حاول مرة أخرى.');
    } finally {
      name.dispose();
      points.dispose();
      gems.dispose();
      order.dispose();
    }
  }

  // ─── منح / إهداء لعضو ──────────────────────────────────────────────
  Future<void> _grant(Map<String, dynamic> item) async {
    final uid = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('منح: ${item['name_ar'] ?? item['item_key']}'),
          content: TextField(
            controller: uid,
            decoration: const InputDecoration(labelText: 'UUID العضو'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('منح')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final target = uid.text.trim();
      if (target.isEmpty) {
        _say('أدخل UUID العضو.');
        return;
      }
      await _db.rpc('admin_force_user_profile_cosmetic', params: {
        'p_user_id': target,
        'p_item_key': item['item_key'],
        'p_request_id': const Uuid().v4(),
      });
      _say('تم المنح خادميًا ✓');
    } catch (_) {
      _say('تعذّر المنح. تحقّق من الـUUID ثم حاول مرة أخرى.');
    } finally {
      uid.dispose();
    }
  }

  // ─── حذف ───────────────────────────────────────────────────────────
  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
            'حذف «${item['name_ar'] ?? item['item_key']}» نهائيًا من المتجر؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _db.rpc('admin_delete_profile_cosmetic', params: {
        'p_item_key': item['item_key'],
        'p_request_id': const Uuid().v4(),
      });
      _reload();
      _say('تم الحذف خادميًا ✓');
    } catch (_) {
      _say('تعذّر الحذف. حاول مرة أخرى.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return const Center(
              child: Text(
                  'تعذر تحميل عناصر متجر الشات الآن. تحقق من الاتصال ثم أعد المحاولة.'));
        }
        final all = s.data ?? const <Map<String, dynamic>>[];
        final categories = <String>{
          'الكل',
          ...all.map((e) => e['category']?.toString() ?? '')
        }..removeWhere((e) => e.isEmpty);
        final q = _search.text.trim();
        final items = all.where((x) {
          if (_category != 'الكل' && x['category']?.toString() != _category) {
            return false;
          }
          if (q.isEmpty) return true;
          final hay =
              '${x['name_ar'] ?? ''} ${x['item_key'] ?? ''}'.toLowerCase();
          return hay.contains(q.toLowerCase());
        }).toList();

        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      hintText: 'ابحث بالاسم أو المفتاح…',
                      prefixIcon: Icon(Icons.search)),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _category,
                items: categories
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? 'الكل'),
              ),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (c, i) {
                final x = items[i];
                final inactive = x['is_active'] == false;
                return ListTile(
                  title: Text(x['name_ar']?.toString() ?? 'عنصر متجر',
                      style: TextStyle(
                          color: inactive ? Colors.white38 : null)),
                  subtitle: Text(
                      '${x['category']} • ${x['price_points']} نقطة • ${x['price_gems']} جوهرة'
                      '${inactive ? ' • معطّل' : ''}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        icon: const Icon(Icons.card_giftcard, size: 20),
                        onPressed: () => _grant(x)),
                    IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _edit(x)),
                    IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _delete(x)),
                  ]),
                );
              },
            ),
          ),
        ]);
      },
    );
  }
}
