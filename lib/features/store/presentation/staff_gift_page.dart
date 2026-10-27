import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure_text.dart';
import '../../../core/services/snack_sfx.dart';

/// لوحة الإهداء المشتركة: المالك والسوبر أدمن جهةٌ واحدة (البند ١٣).
///
/// ثبت بجلسة حقيقية أنّ السوبر أدمن لم يكن يقدر على إهداء أي شيء —
/// لا عضوية ولا نقاطًا ولا جواهر ولا مادةً من المتجر — وكانت لوحة
/// الإدارة نفسها محجوبة عنه (لا يملك view_admin_dashboard). فبقيت
/// صفحةً مستقلّة تُفتح لمن يملك الصلاحية خادميًّا (is_sales_staff)،
/// لا تبويبًا داخل لوحةٍ لا يراها.
///
/// كل إهداء هنا يُسجَّل في staff_gift_log ويُشعِر الطرف الآخر من
/// الإدارة والعضو المستفيد، فلا تُكرَّر شحنةٌ ولا تُنسى.
final salesStaffProvider = FutureProvider<bool>((ref) async {
  try {
    return await Supabase.instance.client.rpc('is_sales_staff') == true;
  } catch (_) {
    return false;
  }
});

final _cashRequestsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, status) async {
  final r = await Supabase.instance.client
      .rpc('staff_list_cash_requests', params: {'p_status': status});
  return r is List
      ? r.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : <Map<String, dynamic>>[];
});

final _recentGiftsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final r = await Supabase.instance.client
      .rpc('staff_recent_gifts', params: {'p_limit': 40});
  return r is List
      ? r.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : <Map<String, dynamic>>[];
});

final _tiersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client
      .from('app_documents')
      .select('doc_id,data')
      .eq('collection_path', 'subscription_tiers');
  return (rows as List).map((e) {
    final m = Map<String, dynamic>.from(e as Map);
    final d = m['data'] is Map
        ? Map<String, dynamic>.from(m['data'] as Map)
        : <String, dynamic>{};
    return {
      'id': m['doc_id'],
      'name': d['nameAr'] ?? d['name'] ?? m['doc_id'],
    };
  }).toList();
});

class StaffGiftPage extends ConsumerStatefulWidget {
  const StaffGiftPage({super.key});

  @override
  ConsumerState<StaffGiftPage> createState() => _StaffGiftPageState();
}

class _StaffGiftPageState extends ConsumerState<StaffGiftPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  final _query = TextEditingController();
  final _amount = TextEditingController();
  Map<String, dynamic>? _target;
  String _kind = 'points';
  String? _tierId;
  bool _busy = false;

  @override
  void dispose() {
    _tabs.dispose();
    _query.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(m)));

  Future<void> _lookup() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() => _busy = true);
    try {
      // p_identifier_kind لازم: افتراضه 'UID' فالبحث بالاسم بلا هذا
      // الوسيط لا يُرجع شيئًا أبدًا — يُطابق المعرّفات وحدها.
      final isUid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
              r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(q);
      final rows = await Supabase.instance.client
          .rpc('admin_lookup_user_by_identifier', params: {
        'p_identifier': q,
        'p_identifier_kind': isUid ? 'UID' : 'NAME',
      });
      final list = rows is List
          ? rows.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      if (list.isEmpty) {
        setState(() => _target = null);
        _toast('لا عضو بهذا الاسم أو المعرّف.');
        return;
      }
      if (list.length == 1) {
        setState(() => _target = list.first);
        return;
      }
      final picked = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (d) => SimpleDialog(
          title: const Text('اختر العضو'),
          children: [
            for (final u in list)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(d, u),
                child: Text(
                    '${u['display_name'] ?? u['username'] ?? '؟'}  —  ${u['username'] ?? ''}'),
              ),
          ],
        ),
      );
      if (picked != null && mounted) setState(() => _target = picked);
    } catch (e) {
      if (mounted) _toast(FailureText.of(e, subject: 'بيانات العضو'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final t = _target;
    if (t == null) {
      _toast('ابحث عن العضو أولًا.');
      return;
    }
    final needsAmount =
        _kind == 'points' || _kind == 'gems' || _kind == 'ai_credits';
    final amount = int.tryParse(_amount.text.trim());
    if (needsAmount && (amount == null || amount <= 0)) {
      _toast('اكتب كمية صحيحة.');
      return;
    }
    if (_kind == 'membership' && (_tierId == null || _tierId!.isEmpty)) {
      _toast('اختر العضوية.');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Supabase.instance.client
          .rpc('staff_gift_from_store', params: {
        'p_target_uid': t['id'] ?? t['user_id'] ?? t['uid'],
        'p_kind': _kind,
        'p_ref': _kind == 'membership' ? _tierId : null,
        'p_amount': needsAmount ? amount : null,
      });
      if (!mounted) return;
      final what = r is Map ? r['gift']?.toString() : null;
      _toast(what == null ? 'تمّ الإهداء ✓' : '$what ✓');
      _amount.clear();
      ref.invalidate(_recentGiftsProvider);
    } catch (e) {
      if (mounted) _toast(FailureText.action(e, action: 'الإهداء'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(salesStaffProvider).valueOrNull;
    if (staff == false) {
      return const Scaffold(
        body: Center(
          child: Text('هذه الصفحة للمالك والسوبر أدمن فقط.',
              style: TextStyle(color: Colors.white60)),
        ),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإهداء من المتجر'),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'إهداء'),
              Tab(text: 'طلبات الكاش'),
              Tab(text: 'آخر الهدايا'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [_giftTab(), _cashTab(), _logTab()],
        ),
      ),
    );
  }

  Widget _giftTab() {
    final tiers = ref.watch(_tiersProvider).valueOrNull ?? const [];
    final needsAmount =
        _kind == 'points' || _kind == 'gems' || _kind == 'ai_credits';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _query,
              onSubmitted: (_) => _lookup(),
              decoration: const InputDecoration(
                labelText: 'اسم العضو أو معرّفه',
                prefixIcon: Icon(Icons.person_search_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
              onPressed: _busy ? null : _lookup, child: const Text('بحث')),
        ]),
        if (_target != null)
          Card(
            margin: const EdgeInsets.only(top: 10),
            child: ListTile(
              leading: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF34D399)),
              title: Text(_target!['display_name']?.toString() ??
                  _target!['username']?.toString() ??
                  'عضو'),
              subtitle: Text(_target!['username']?.toString() ?? '',
                  style: const TextStyle(fontSize: 11)),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _target = null),
              ),
            ),
          ),
        const SizedBox(height: 18),
        const Text('ما تريد إهداءه',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in const [
            ('points', '⭐ نقاط'),
            ('gems', '💎 جواهر'),
            ('membership', '👑 عضوية'),
            ('store_item', '🛍️ مادة من المتجر'),
            ('points_package', '📦 حزمة نقاط'),
            ('ai_credits', '🤖 رصيد ذكاء'),
          ])
            ChoiceChip(
              label: Text(k.$2),
              selected: _kind == k.$1,
              onSelected: (_) => setState(() => _kind = k.$1),
            ),
        ]),
        const SizedBox(height: 16),
        if (_kind == 'membership')
          DropdownButtonFormField<String>(
            initialValue: _tierId,
            decoration: const InputDecoration(
                labelText: 'العضوية', border: OutlineInputBorder()),
            items: [
              for (final t in tiers)
                DropdownMenuItem(
                  value: t['id'].toString(),
                  child: Text(t['name'].toString()),
                ),
            ],
            onChanged: (v) => setState(() => _tierId = v),
          ),
        if (_kind == 'store_item' || _kind == 'points_package')
          TextField(
            controller: _amount,
            keyboardType: _kind == 'store_item'
                ? TextInputType.number
                : TextInputType.text,
            decoration: InputDecoration(
              labelText: _kind == 'store_item'
                  ? 'رقم المادة في المتجر'
                  : 'معرّف حزمة النقاط',
              border: const OutlineInputBorder(),
            ),
          ),
        if (needsAmount)
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'الكمية', border: OutlineInputBorder()),
          ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : _sendDispatch,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.card_giftcard_rounded),
          label: Text(_busy ? 'جارٍ التنفيذ' : 'إهداء'),
        ),
        const SizedBox(height: 10),
        const Text(
          'كل إهداء يُسجَّل باسم من نفّذه، ويصل إشعاره إلى الطرف الآخر من '
          'الإدارة وإلى العضو نفسه.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }

  /// حزمة النقاط والمادة يختلف حقلهما: الأولى معرّف نصّي والثانية رقم،
  /// وكلاهما يُقرأ من نفس الحقل، فيُرسَل كلٌّ في موضعه الصحيح.
  Future<void> _sendDispatch() async {
    if (_kind == 'points_package') {
      final t = _target;
      if (t == null) {
        _toast('ابحث عن العضو أولًا.');
        return;
      }
      final pkg = _amount.text.trim();
      if (pkg.isEmpty) {
        _toast('اكتب معرّف حزمة النقاط.');
        return;
      }
      setState(() => _busy = true);
      try {
        final r = await Supabase.instance.client
            .rpc('staff_gift_from_store', params: {
          'p_target_uid': t['id'] ?? t['user_id'] ?? t['uid'],
          'p_kind': 'points_package',
          'p_ref': pkg,
        });
        if (!mounted) return;
        _toast('${r is Map ? r['gift'] ?? 'تمّ' : 'تمّ'} ✓');
        ref.invalidate(_recentGiftsProvider);
      } catch (e) {
        if (mounted) _toast(FailureText.action(e, action: 'الإهداء'));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    await _send();
  }

  Widget _cashTab() {
    return ref.watch(_cashRequestsProvider('all')).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(FailureText.of(e, subject: 'طلبات الكاش')))),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                  child: Text('لا طلبات كاش.',
                      style: TextStyle(color: Colors.white54)));
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_cashRequestsProvider('all')),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = items[i];
                  return ListTile(
                    title: Text(
                        '${r['name'] ?? 'عضو'} — ${r['tier_name'] ?? r['tier_id']}'),
                    subtitle: Text(
                      [
                        'الحالة: ${_statusAr(r['status']?.toString())}',
                        if ((r['note']?.toString() ?? '').isNotEmpty)
                          r['note'].toString(),
                        if ((r['handled_by_name']?.toString() ?? '').isNotEmpty)
                          'بيد ${r['handled_by_name']}',
                      ].join('  ·  '),
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'تحديث الحالة',
                      onSelected: (v) async {
                        try {
                          if (v == 'grant') {
                            await Supabase.instance.client
                                .rpc('staff_gift_from_store', params: {
                              'p_target_uid': r['user_id'],
                              'p_kind': 'membership',
                              'p_ref': r['tier_id'],
                            });
                          }
                          await Supabase.instance.client.rpc(
                              'staff_set_cash_request_status',
                              params: {
                                'p_id': r['id'],
                                'p_status': v == 'grant' ? 'granted' : v,
                              });
                          if (!mounted) return;
                          _toast('حُدِّث الطلب ✓');
                          ref.invalidate(_cashRequestsProvider('all'));
                          ref.invalidate(_recentGiftsProvider);
                        } catch (e) {
                          if (mounted) {
                            _toast(FailureText.action(e, action: 'التحديث'));
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'contacted', child: Text('تواصلتُ معه')),
                        PopupMenuItem(value: 'paid', child: Text('دفع')),
                        PopupMenuItem(
                            value: 'grant',
                            child: Text('منح العضوية الآن وإغلاق الطلب')),
                        PopupMenuItem(
                            value: 'cancelled', child: Text('إلغاء الطلب')),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
  }

  String _statusAr(String? s) => switch (s) {
        'pending' => 'معلّق',
        'contacted' => 'تمّ التواصل',
        'paid' => 'دفع',
        'granted' => 'مُنحت',
        'cancelled' => 'ملغى',
        _ => s ?? '—',
      };

  Widget _logTab() {
    return ref.watch(_recentGiftsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(FailureText.of(e, subject: 'سجلّ الهدايا')))),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                  child: Text('لا هدايا بعد.',
                      style: TextStyle(color: Colors.white54)));
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_recentGiftsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final g = items[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.card_giftcard_rounded, size: 18),
                    title: Text('${g['actor']} → ${g['target']}'),
                    subtitle: Text(
                      '${_kindAr(g['kind']?.toString())}'
                      '${g['amount'] != null ? ' × ${g['amount']}' : ''}'
                      '${(g['ref']?.toString() ?? '').isNotEmpty ? ' (${g['ref']})' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            );
          },
        );
  }

  String _kindAr(String? k) => switch (k) {
        'points' => 'نقاط',
        'gems' => 'جواهر',
        'membership' => 'عضوية',
        'store_item' => 'مادة من المتجر',
        'points_package' => 'حزمة نقاط',
        'ai_credits' => 'رصيد ذكاء',
        _ => k ?? '—',
      };
}
