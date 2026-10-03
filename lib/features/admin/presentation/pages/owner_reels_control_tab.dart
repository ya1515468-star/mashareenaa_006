import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تحكّم المالك الشامل بريلز سوق المنتجين.
///
/// كل شيء خادمي عبر owner_list_reels / owner_update_reel /
/// owner_delete_reel — محميّة بـ is_my_platform_owner، وكل إجراء
/// يُسجَّل في owner_action_log ويُشعِر صاحب الريل بالقرار وسببه.

final _db = Supabase.instance.client;

final ownerReelsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, filter) async {
  final raw = await _db.rpc('owner_list_reels',
      params: {'p_filter': filter, 'p_limit': 100, 'p_offset': 0});
  return raw is List ? List<Map<String, dynamic>>.from(raw) : const [];
});

class OwnerReelsControlTab extends ConsumerStatefulWidget {
  const OwnerReelsControlTab({super.key});

  @override
  ConsumerState<OwnerReelsControlTab> createState() =>
      _OwnerReelsControlTabState();
}

class _OwnerReelsControlTabState extends ConsumerState<OwnerReelsControlTab> {
  static const _gold = Color(0xFFFFD700);
  String _filter = 'all';

  static const _filters = <String, String>{
    'all': 'الكل',
    'pending': 'بانتظار النشر',
    'published': 'منشورة',
    'blocked': 'محجوبة',
    'pinned': 'مثبّتة',
  };

  @override
  Widget build(BuildContext context) {
    final reels = ref.watch(ownerReelsProvider(_filter));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _filters.entries.map((e) {
                final on = _filter == e.key;
                return Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: on ? _gold : Colors.white10,
                      ),
                      child: Text(e.value,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: on ? Colors.black : Colors.white60,
                              fontWeight:
                                  on ? FontWeight.w900 : FontWeight.w500)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: reels.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: _gold)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      e.toString().contains('OWNER_ONLY')
                          ? 'هذا القسم للمالك فقط.'
                          : '$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54)),
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Text('لا ريلز في هذا التصنيف',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 13)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 9),
                      itemBuilder: (_, i) => _ReelAdminCard(
                        reel: list[i],
                        onChanged: () =>
                            ref.invalidate(ownerReelsProvider(_filter)),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelAdminCard extends StatelessWidget {
  final Map<String, dynamic> reel;
  final VoidCallback onChanged;
  const _ReelAdminCard({required this.reel, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final thumb = reel['thumbnail_url']?.toString() ?? '';
    final blocked = reel['is_blocked'] == true;
    final published = reel['is_published'] == true;
    final until = DateTime.tryParse(reel['visible_until']?.toString() ?? '');
    final expired = until != null && until.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0530), Color(0xFF0A1A3A)],
        ),
        border: Border.all(
            color: blocked
                ? const Color(0xFFEF4444).withValues(alpha: .5)
                : const Color(0xFFFFD700).withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: thumb.isEmpty
                  ? Container(
                      width: 52,
                      height: 68,
                      color: Colors.white10,
                      child: const Icon(Icons.movie_rounded,
                          color: Colors.white24, size: 20))
                  : Image.network(thumb,
                      width: 52,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 52, height: 68, color: Colors.white10)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reel['title']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900)),
                  Text('👤 ${reel['owner_name'] ?? 'عضو'}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    _pill(
                        blocked
                            ? 'محجوب'
                            : published
                                ? (expired ? 'انتهت المدة' : 'منشور')
                                : 'مسودّة',
                        blocked
                            ? const Color(0xFFEF4444)
                            : published && !expired
                                ? const Color(0xFF34D399)
                                : const Color(0xFFF59E0B)),
                    if (reel['is_pinned'] == true)
                      _pill('📌 مثبّت', const Color(0xFF8B5CF6)),
                    if (reel['is_featured'] == true)
                      _pill('⭐ مميّز', const Color(0xFFFFD700)),
                    _pill('👁 ${reel['views_count'] ?? 0}', Colors.white30),
                    _pill('❤ ${reel['likes_count'] ?? 0}', Colors.white30),
                  ]),
                  if (until != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                          'يظهر حتى ${until.toLocal()}'.split('.').first,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white38)),
                    ),
                ],
              ),
            ),
          ]),
          const Divider(height: 16, color: Colors.white12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _act(context, Icons.edit_rounded, 'تعديل', () => _edit(context)),
            _act(
                context,
                published ? Icons.visibility_off_rounded : Icons.check_rounded,
                published ? 'إخفاء' : 'موافقة ونشر',
                () => _patch(context, {'is_published': !published}),
                color: published ? null : const Color(0xFF34D399)),
            _act(
                context,
                blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                blocked ? 'رفع الحجب' : 'حجب',
                () => blocked
                    ? _patch(context, {'is_blocked': false})
                    : _blockWithReason(context),
                color: blocked ? const Color(0xFF34D399) : const Color(0xFFEF4444)),
            _act(
                context,
                Icons.push_pin_rounded,
                reel['is_pinned'] == true ? 'إلغاء التثبيت' : 'تثبيت',
                () => _patch(context, {'is_pinned': reel['is_pinned'] != true})),
            _act(context, Icons.delete_outline, 'حذف',
                () => _delete(context),
                color: const Color(0xFFEF4444)),
          ]),
        ],
      ),
    );
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
            color: c.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(6)),
        child: Text(t,
            style: TextStyle(
                fontSize: 10, color: c, fontWeight: FontWeight.w700)),
      );

  Widget _act(BuildContext context, IconData icon, String label,
          VoidCallback onTap, {Color? color}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: (color ?? Colors.white24).withValues(alpha: .13),
            border: Border.all(
                color: (color ?? Colors.white30).withValues(alpha: .4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: color ?? Colors.white60),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color ?? Colors.white70,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Future<void> _patch(BuildContext context, Map<String, dynamic> patch) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await _db.rpc('owner_update_reel',
          params: {'p_reel_id': reel['id'].toString(), 'p_patch': patch});
      onChanged();
      messenger?.showSnackBar(const SnackBar(
          content: Text('نُفّذ'), backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(
          content: Text('فشل: $e'),
          backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<void> _blockWithReason(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حجب الفيديو'),
          content: TextField(
            controller: c,
            autofocus: true,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'السبب', hintText: 'يصل الناشر في إشعار'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حجب')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await _patch(context,
        {'is_blocked': true, 'owner_note': c.text.trim()});
  }

  Future<void> _delete(BuildContext context) async {
    // يُلتقط قبل أي await: الشاشة قد تُغلق أثناء الحوار فيصير
    // المرجع معلَّقًا. ScaffoldMessengerState لا يعتمد على بقاء
    // الشجرة فيبقى صالحًا بعدها.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف نهائي'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('سيُحذف الفيديو وتعليقاته نهائيًا ولا يمكن التراجع.'),
            const SizedBox(height: 10),
            TextField(
                controller: c,
                decoration: const InputDecoration(labelText: 'السبب')),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _db.rpc('owner_delete_reel', params: {
        'p_reel_id': reel['id'].toString(),
        'p_reason': c.text.trim(),
      });
      onChanged();
      messenger?.showSnackBar(const SnackBar(
          content: Text('حُذف الفيديو'),
          backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(
          content: Text('فشل الحذف: $e'),
          backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<void> _edit(BuildContext context) async {
    final title = TextEditingController(text: reel['title']?.toString() ?? '');
    final desc =
        TextEditingController(text: reel['description']?.toString() ?? '');
    final price = TextEditingController(
        text: '${(reel['price_minor_units'] as num?)?.toInt() ?? 0}');
    final days = TextEditingController();
    var featured = reel['is_featured'] == true;
    var download = reel['allow_download'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text('تعديل الفيديو'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'التسمية')),
                const SizedBox(height: 9),
                TextField(
                    controller: desc,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'التفاصيل')),
                const SizedBox(height: 9),
                TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'السعر (بالسنت)')),
                const SizedBox(height: 9),
                TextField(
                    controller: days,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'مدة الظهور (أيام)',
                        hintText: 'اتركه فارغًا لبلا حد، أو 0 لإلغاء المدة')),
                SwitchListTile(
                  value: featured,
                  title: const Text('مميّز', style: TextStyle(fontSize: 13)),
                  onChanged: (v) => setD(() => featured = v),
                ),
                SwitchListTile(
                  value: download,
                  title: const Text('السماح بالتحميل',
                      style: TextStyle(fontSize: 13)),
                  onChanged: (v) => setD(() => download = v),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    final patch = <String, dynamic>{
      'title': title.text.trim(),
      'description': desc.text.trim(),
      'price_minor_units': int.tryParse(price.text.trim()) ?? 0,
      'is_featured': featured,
      'allow_download': download,
    };
    final d = int.tryParse(days.text.trim());
    if (d != null) patch['visible_days'] = d;
    await _patch(context, patch);
  }
}
