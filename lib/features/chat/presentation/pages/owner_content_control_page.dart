import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/content/media_viewer.dart';
import '../../../../core/error/failure_text.dart';
import '../../../../core/services/snack_sfx.dart';

/// تحكّم المالك بحائط المنتجات وبخدمات VIP (البندان ٤ و١١).
///
/// كان المالك يملك ما يملكه أي ناشر: يعدّل ما نشره هو ويحذفه. أمّا ما
/// نشره الأعضاء فلا سبيل إليه — لا إخفاء منتجٍ مخالف، ولا تمديد مدّة
/// لمن دفع وانقطع عنه الظهور، ولا حذف خدمة VIP من الفهرس. كل زرّ هنا
/// ينادي دالة خادم (owner_*) تتحقّق من الملكية بنفسها وتكتب في سجلّ
/// التدقيق، فلا شيء يعتمد على إخفاء زر.
/// (تحكّم الإعلانات في تبويب «📣 الإعلانات» من اللوحة نفسها.)
final _ownerProductsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, filter) async {
  final r = await Supabase.instance.client.rpc('owner_list_wall_products',
      params: {'p_filter': filter, 'p_limit': 120});
  return r is List
      ? r.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : <Map<String, dynamic>>[];
});

final _ownerVipProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final r = await Supabase.instance.client.rpc('get_profile_service_catalog');
  return r is List
      ? r.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : <Map<String, dynamic>>[];
});

class OwnerContentControlPage extends ConsumerStatefulWidget {
  const OwnerContentControlPage({super.key});

  @override
  ConsumerState<OwnerContentControlPage> createState() =>
      _OwnerContentControlPageState();
}

class _OwnerContentControlPageState
    extends ConsumerState<OwnerContentControlPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  String _productFilter = 'all';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBarSfx(SnackBar(content: Text(msg)));

  Future<void> _call(Future<void> Function() action, String okMsg,
      {VoidCallback? then}) async {
    try {
      await action();
      if (!mounted) return;
      _toast(okMsg);
      then?.call();
    } catch (e) {
      if (mounted) _toast(FailureText.of(e));
    }
  }

  Future<bool> _confirm(String title, String body,
      {String yes = 'تأكيد'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(yes)),
        ],
      ),
    );
    return ok == true;
  }

  /// سبب الإجراء يُكتب ويُحفظ في سجلّ التدقيق خادميًّا، فيبقى لكل حذفٍ
  /// أو إيقافٍ أثرٌ يُراجَع لاحقًا.
  Future<String?> _askReason(String title) async {
    final c = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          maxLength: 200,
          decoration: const InputDecoration(hintText: 'السبب (اختياري)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(d, c.text.trim()),
              child: const Text('تنفيذ')),
        ],
      ),
    );
    c.dispose();
    return r;
  }

  Future<int?> _askDays(String title) async {
    final options = [0, 3, 7, 15, 30, 90, 365];
    return showDialog<int>(
      context: context,
      builder: (d) => SimpleDialog(
        title: Text(title),
        children: [
          for (final n in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(d, n),
              child: Text(n == 0 ? 'بلا نهاية (ظهور دائم)' : '$n يومًا من الآن'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحكّم المالك بالمحتوى'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'حائط المنتجات'),
            Tab(text: 'خدمات VIP'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_productsTab(), _vipTab()],
      ),
    );
  }

  // ───────────────────────────── المنتجات ─────────────────────────────
  Widget _productsTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          for (final f in const [
            ('all', 'الكل'),
            ('active', 'يعمل'),
            ('hidden', 'مخفي'),
            ('expired', 'منتهي'),
          ])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ChoiceChip(
                label: Text(f.$2),
                selected: _productFilter == f.$1,
                onSelected: (_) => setState(() => _productFilter = f.$1),
              ),
            ),
        ]),
      ),
      Expanded(
        child: ref.watch(_ownerProductsProvider(_productFilter)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  _Error(message: FailureText.of(e, subject: 'المنتجات')),
              data: (items) {
                if (items.isEmpty) {
                  return const _Error(message: 'لا منتجات في هذا التصنيف.');
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(_ownerProductsProvider(_productFilter)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _productCard(items[i]),
                  ),
                );
              },
            ),
      ),
    ]);
  }

  Widget _productCard(Map<String, dynamic> pr) {
    final id = pr['id'].toString();
    final active = pr['is_active'] == true;
    final images = (pr['images'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final video = pr['video']?.toString() ?? '';
    final media = [...images, if (video.isNotEmpty) video];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (media.isNotEmpty)
              GestureDetector(
                onTap: () => MediaViewer.open(context,
                    items: media, title: pr['name']?.toString()),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(images.isEmpty ? video : images.first,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 56, height: 56, color: Colors.white10)),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pr['name']?.toString() ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${pr['owner_name'] ?? 'عضو'} • '
                      'متوفّر ${pr['quantity'] ?? 0} • '
                      'تفاعل ${pr['likes'] ?? 0} • تعليق ${pr['comments'] ?? 0}',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ]),
            ),
            if (pr['expired'] == true)
              const _Pill('منتهي', Colors.orange)
            else if (active)
              const _Pill('يعمل', Colors.green)
            else
              const _Pill('مخفي', Colors.grey),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            TextButton.icon(
              onPressed: () => _editProductField(pr, 'name', 'اسم المنتج'),
              icon: const Icon(Icons.edit_rounded, size: 17),
              label: const Text('الاسم'),
            ),
            TextButton.icon(
              onPressed: () =>
                  _editProductField(pr, 'description', 'وصف المنتج', lines: 4),
              icon: const Icon(Icons.notes_rounded, size: 17),
              label: const Text('الوصف'),
            ),
            TextButton.icon(
              onPressed: () async {
                final days = await _askDays('مدّة ظهور المنتج');
                if (days == null) return;
                await _patchProduct(id, {'extend_days': days},
                    days == 0 ? 'صار الظهور دائمًا' : 'تم التمديد $days يومًا');
              },
              icon: const Icon(Icons.more_time_rounded, size: 17),
              label: const Text('المدّة'),
            ),
            TextButton.icon(
              onPressed: () => _patchProduct(id, {'is_active': !active},
                  active ? 'أُخفي المنتج' : 'أُظهر المنتج'),
              icon: Icon(
                  active
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 17),
              label: Text(active ? 'إخفاء' : 'إظهار'),
            ),
            TextButton.icon(
              onPressed: () async {
                if (!await _confirm('حذف المنتج',
                    'سيُحذف المنتج وتفاعلاته وتعليقاته نهائيًّا.',
                    yes: 'حذف')) {
                  return;
                }
                final reason = await _askReason('سبب الحذف');
                if (reason == null) return;
                await _call(
                  () => Supabase.instance.client.rpc(
                      'owner_delete_wall_product',
                      params: {'p_id': id, 'p_reason': reason}),
                  'حُذف المنتج',
                  then: () =>
                      ref.invalidate(_ownerProductsProvider(_productFilter)),
                );
              },
              icon: const Icon(Icons.delete_forever_rounded,
                  size: 17, color: Colors.redAccent),
              label:
                  const Text('حذف', style: TextStyle(color: Colors.redAccent)),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _patchProduct(
          String id, Map<String, dynamic> patch, String okMsg) =>
      _call(
        () => Supabase.instance.client.rpc('owner_update_wall_product',
            params: {'p_id': id, 'p_patch': patch}),
        okMsg,
        then: () => ref.invalidate(_ownerProductsProvider(_productFilter)),
      );

  Future<void> _editProductField(
      Map<String, dynamic> pr, String key, String label,
      {int lines = 1}) async {
    final c = TextEditingController(text: pr[key]?.toString() ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(label),
        content: TextField(controller: c, maxLines: lines, maxLength: 500),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(d, c.text.trim()),
              child: const Text('حفظ')),
        ],
      ),
    );
    c.dispose();
    if (v == null) return;
    if (key == 'name' && v.isEmpty) {
      _toast('الاسم لا يصحّ فارغًا.');
      return;
    }
    await _patchProduct(pr['id'].toString(), {key: v}, 'حُدِّث $label');
  }

  // ───────────────────────────── خدمات VIP ─────────────────────────────
  // البند ١١: حذف أي خدمة من الخادم نفسه، لا إخفاؤها من الواجهة.
  Widget _vipTab() {
    return ref.watch(_ownerVipProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Error(message: FailureText.of(e, subject: 'الخدمات')),
          data: (items) {
            if (items.isEmpty) {
              return const _Error(message: 'لا خدمات في الفهرس.');
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_ownerVipProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = items[i];
                  final key = s['feature_key']?.toString() ?? '';
                  final active = s['is_active'] == true;
                  return ListTile(
                    title: Text(s['name_ar']?.toString() ??
                        s['name']?.toString() ??
                        key),
                    subtitle: Text(
                      '$key • ${s['price_points'] ?? 0} نقطة / '
                      '${s['price_gems'] ?? 0} جوهرة',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Switch(
                        value: active,
                        onChanged: (v) => _call(
                          () => Supabase.instance.client
                              .rpc('update_profile_service_price', params: {
                            'p_feature_key': key,
                            'p_price_points': (s['price_points'] as num?)?.toInt() ?? 0,
                            'p_price_gems': (s['price_gems'] as num?)?.toInt() ?? 0,
                            'p_is_active': v,
                          }),
                          v ? 'فُعِّلت الخدمة' : 'أُوقفت الخدمة',
                          then: () => ref.invalidate(_ownerVipProvider),
                        ),
                      ),
                      IconButton(
                        tooltip: 'حذف الخدمة نهائيًّا',
                        icon: const Icon(Icons.delete_forever_rounded,
                            color: Colors.redAccent),
                        onPressed: () async {
                          if (!await _confirm(
                            'حذف الخدمة نهائيًّا',
                            'ستُحذف «${s['name_ar'] ?? key}» من الفهرس ومن كل '
                                'مَن يملكها. لا رجوع عن هذا.',
                            yes: 'حذف نهائي',
                          )) {
                            return;
                          }
                          final reason = await _askReason('سبب الحذف');
                          if (reason == null) return;
                          await _call(
                            () => Supabase.instance.client.rpc(
                                'owner_delete_profile_service',
                                params: {
                                  'p_feature_key': key,
                                  'p_reason': reason
                                }),
                            'حُذفت الخدمة نهائيًّا',
                            then: () => ref.invalidate(_ownerVipProvider),
                          );
                        },
                      ),
                    ]),
                  );
                },
              ),
            );
          },
        );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      );
}

class _Error extends StatelessWidget {
  const _Error({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60)),
        ),
      );
}
