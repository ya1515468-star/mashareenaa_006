import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure_text.dart';
import '../../../../core/services/snack_sfx.dart';

/// قسم «مزايا VIP المفعّلة» داخل البروفايل (البند ٩).
///
/// الخدمات الـ٣٩ كانت تُشترى ثم تختفي: لا مكان في البروفايل يقول ما
/// يملكه العضو، ولا مفتاح يُشغِّلها أو يُطفئها، فيدفع ولا يرى شيئًا.
///
/// الظهور محصور خادميًّا في get_user_vip_services: العضو نفسه،
/// والمالك، والسوبر أدمن — ومن سواهم يُرفض بـFORBIDDEN، فلا يكفي
/// إخفاء القسم في الواجهة. والتحكّم بيد العضو وحده
/// (set_my_vip_service_enabled تعمل على auth.uid() لا على معرّف
/// مُرسَل، فلا يُطفئ أحدٌ خدمة غيره).
final vipServicesProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, userId) async {
  try {
    final r = await Supabase.instance.client
        .rpc('get_user_vip_services', params: {'p_user_id': userId});
    return r is Map ? Map<String, dynamic>.from(r) : null;
  } catch (e) {
    // FORBIDDEN يعني «لا يُعرَض لك»، وهو حالة طبيعية لا خطأ يُصرَخ به.
    if (e is PostgrestException && e.message.contains('FORBIDDEN')) return null;
    rethrow;
  }
});

class VipActiveBenefitsSection extends ConsumerWidget {
  const VipActiveBenefitsSection({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vipServicesProvider(userId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      // لا رسالة خطأ في بروفايل عضو آخر: إن لم يُسمح بالعرض فالقسم
      // غائب تمامًا كأنّه غير موجود.
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final services = (data['services'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const <Map<String, dynamic>>[];
        if (services.isEmpty) return const SizedBox.shrink();
        final isSelf = data['is_self'] == true;
        final onCount = services.where((s) => s['enabled'] == true).length;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: isSelf,
              leading: const Text('👑', style: TextStyle(fontSize: 22)),
              title: const Text('مزايا VIP المفعّلة',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(
                '$onCount مفعّلة من ${services.length}'
                '${isSelf ? '' : ' — يراه صاحبه والإدارة فقط'}',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
              children: [
                for (final s in services)
                  _ServiceRow(service: s, canToggle: isSelf, userId: userId),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ServiceRow extends ConsumerStatefulWidget {
  const _ServiceRow({
    required this.service,
    required this.canToggle,
    required this.userId,
  });

  final Map<String, dynamic> service;
  final bool canToggle;
  final String userId;

  @override
  ConsumerState<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends ConsumerState<_ServiceRow> {
  bool _busy = false;

  Future<void> _toggle(bool v) async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc('set_my_vip_service_enabled', params: {
        'p_feature_key': widget.service['feature_key'],
        'p_enabled': v,
      });
      ref.invalidate(vipServicesProvider(widget.userId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
          SnackBar(content: Text(v ? 'فُعِّلت الخدمة ✓' : 'أُطفئت الخدمة')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBarSfx(
          SnackBar(content: Text(FailureText.action(e, action: 'التغيير'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    final enabled = s['enabled'] == true;
    final orphan = s['orphan'] == true;
    final hint = s['hint']?.toString() ?? '';
    final uses = (s['use_count'] as num?)?.toInt() ?? 0;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      title: Row(children: [
        Expanded(
          child: Text(s['name']?.toString() ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: enabled ? null : Colors.white38,
              )),
        ),
        if (orphan)
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 6),
            child: Text('أُزيلت من المتجر',
                style: TextStyle(fontSize: 9, color: Colors.orangeAccent)),
          ),
      ]),
      subtitle: Text(
        [
          if (hint.isNotEmpty) hint,
          if (uses > 0) 'استُعملت $uses مرّة',
        ].join('  ·  '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10.5, color: Colors.white54),
      ),
      trailing: _busy
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : widget.canToggle
              // التحكّم للعضو نفسه. المالك والسوبر أدمن يَريان ولا
              // يُبدّلان من هنا: الإطفاء قرار صاحب الخدمة، والحذف
              // الإداري له بابه في لوحة المالك.
              ? Switch(value: enabled, onChanged: orphan ? null : _toggle)
              : Icon(
                  enabled ? Icons.check_circle_rounded : Icons.remove_circle_outline,
                  size: 18,
                  color: enabled ? const Color(0xFF34D399) : Colors.white24,
                ),
    );
  }
}
