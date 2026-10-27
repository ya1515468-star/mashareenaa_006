import 'dart:async';
import '../../../../core/error/failure_text.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تحكّم المالك بالإعلانات: المُدد وأسعارها، وفارق كل فئة، وإيقاف أي
/// إعلان جارٍ، وتقرير الإيراد والظهور.
///
/// لماذا المُدد هنا لا في مكان آخر: المدّة هي المنتج الذي يشتريه العضو،
/// فسعرها وسقف ظهورها قرار واحد. وفصل «أوقف هذا الإعلان» عن اللوحة
/// يعني أنّ إعلانًا مخالفًا يبقى يعمل حتى تُفتَح شاشة أخرى.
class AdminAdsTab extends StatefulWidget {
  const AdminAdsTab({super.key});

  @override
  State<AdminAdsTab> createState() => _AdminAdsTabState();
}

class _AdminAdsTabState extends State<AdminAdsTab> {
  final _db = Supabase.instance.client;
  Map<String, dynamic> _data = const {};
  List<Map<String, dynamic>> _placements = const [];
  bool _loading = true;
  String? _busy;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _db.rpc('owner_get_ads_dashboard', params: {'p_limit': 80});
      final pl = await _db.rpc('owner_get_ad_placements');
      if (!mounted) return;
      setState(() {
        _data = raw is Map ? Map<String, dynamic>.from(raw) : const {};
        _placements = pl is List
            ? pl.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : const [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FailureText.of(e);
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _list(String key) {
    final v = _data[key];
    return v is List
        ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const [];
  }

  int _n(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? const Color(0xFF16A34A) : null,
    ));
  }

  // ── المُدد ────────────────────────────────────────────────────────
  Future<void> _editPlan([Map<String, dynamic>? p]) async {
    final days = TextEditingController(text: '${p?['days'] ?? 10}');
    final label = TextEditingController(text: '${p?['label'] ?? ''}');
    final points = TextEditingController(text: '${p?['points'] ?? 0}');
    final gems = TextEditingController(text: '${p?['gems'] ?? 0}');
    final cap = TextEditingController(text: '${p?['cap'] ?? 0}');
    var active = p?['active'] != false;
    String? category = p?['category'] as String?;
    final cats = _list('categories');

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (c, setD) => AlertDialog(
            title: Text(p == null ? 'مدّة جديدة' : 'تعديل المدّة'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: days,
                  keyboardType: TextInputType.number,
                  enabled: p == null,
                  decoration: const InputDecoration(
                      labelText: 'عدد الأيام', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: label,
                  decoration: const InputDecoration(
                      labelText: 'الاسم الظاهر (مثل: شهر)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: points,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'نقاط ⭐', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: gems,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'جواهر 💎', border: OutlineInputBorder()),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                const Text(
                  'إن ضبطت السعرين فالعضو يختار عملة الدفع. صفر في عملة '
                  'يعني أنّها غير متاحة لهذه المدّة.',
                  style: TextStyle(fontSize: 11, color: Colors.white60),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cap,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'سقف الظهور (0 = بلا سقف)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: category,
                  decoration: const InputDecoration(
                      labelText: 'الفئة', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('كل الفئات')),
                    for (final c in cats)
                      DropdownMenuItem(
                        value: c['key'] as String?,
                        child: Text('${c['emoji'] ?? ''} ${c['label'] ?? c['key']}'),
                      ),
                  ],
                  onChanged: p == null ? (v) => setD(() => category = v) : null,
                ),
                SwitchListTile(
                  value: active,
                  onChanged: (v) => setD(() => active = v),
                  title: const Text('متاحة للشراء'),
                  contentPadding: EdgeInsets.zero,
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
      ),
    );
    if (ok != true) return;

    setState(() => _busy = 'plan');
    try {
      await _db.rpc('owner_upsert_ad_duration_plan', params: {
        'p_days': int.tryParse(days.text.trim()) ?? 0,
        'p_label_ar': label.text.trim(),
        'p_points_cost': int.tryParse(points.text.trim()) ?? 0,
        'p_gems_cost': int.tryParse(gems.text.trim()) ?? 0,
        'p_impression_cap': int.tryParse(cap.text.trim()) ?? 0,
        'p_category_key': category,
        'p_is_active': active,
        'p_sort_order': int.tryParse(days.text.trim()) ?? 0,
      });
      await _load();
      _toast('حُفظ على الخادم ✓', ok: true);
    } catch (e) {
      _toast(e.toString().contains('PLAN_MUST_BE_PRICED')
          ? 'لا يمكن أن تكون المدّة بلا سعر — اضبط نقاطًا أو جواهر.'
          : e.toString().contains('INVALID_DAYS')
              ? 'عدد الأيام يجب أن يكون بين 1 و 3650.'
              : FailureText.action(e, action: 'الحفظ'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _disablePlan(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعطيل المدّة'),
          content: Text(
            'ستُخفى «${p['label']}» من خيارات الشراء. الإعلانات المشتراة '
            'بها تكمل مدّتها كما هي — لا تتأثّر.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('تعطيل')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _busy = 'plan');
    try {
      await _db.rpc('owner_delete_ad_duration_plan', params: {'p_id': p['id']});
      await _load();
      _toast('عُطِّلت ✓', ok: true);
    } catch (e) {
      _toast(FailureText.of(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // ── إيقاف إعلان ──────────────────────────────────────────────────
  /// تحكّم المالك الكامل بإعلان أي عضو: النصّ، المدّة، الظهور، الحذف.
  ///
  /// كل إجراء يمرّ بدالة الخادم التي تتحقّق من الملكية بنفسها وتكتب
  /// في سجلّ التدقيق، فلا يكفي إخفاء القائمة لمنعه ولا يضيع أثره.
  Future<void> _ownerAdAction(Map<String, dynamic> ad, String what) async {
    final id = ad['id'];
    Map<String, dynamic>? patch;
    String okMsg = 'تمّ ✓';

    if (what == 'text') {
      final c = TextEditingController(text: ad['text']?.toString() ?? '');
      final v = await showDialog<String>(
        context: context,
        builder: (d) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تعديل نصّ الإعلان'),
            content: TextField(
                controller: c,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(border: OutlineInputBorder())),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(d),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(d, c.text.trim()),
                  child: const Text('حفظ')),
            ],
          ),
        ),
      );
      c.dispose();
      if (v == null || v.isEmpty) return;
      patch = {'text': v};
      okMsg = 'حُدِّث النصّ ✓';
    } else if (what == 'days') {
      final days = await showDialog<int>(
        context: context,
        builder: (d) => Directionality(
          textDirection: TextDirection.rtl,
          child: SimpleDialog(
            title: const Text('مدّة ظهور الإعلان'),
            children: [
              for (final n in const [0, 3, 7, 15, 30, 90, 365])
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(d, n),
                  child: Text(n == 0
                      ? 'بلا نهاية (ظهور دائم)'
                      : '$n يومًا من الآن'),
                ),
            ],
          ),
        ),
      );
      if (days == null) return;
      patch = {'extend_days': days};
      okMsg = days == 0 ? 'صار الظهور دائمًا ✓' : 'صارت المدّة $days يومًا ✓';
    } else if (what == 'visible') {
      final show = ad['active'] != true;
      patch = {'is_active': show};
      okMsg = show ? 'أُظهر الإعلان ✓' : 'أُخفي الإعلان ✓';
    }

    setState(() => _busy = '${ad['id']}');
    try {
      if (what == 'delete') {
        final go = await showDialog<bool>(
          context: context,
          builder: (d) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('حذف الإعلان نهائيًّا'),
              content: const Text(
                  'سيُحذف الإعلان وتفاعلاته وتعليقاته من الخادم. لا رجوع.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(d, false),
                    child: const Text('إلغاء')),
                FilledButton(
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('حذف')),
              ],
            ),
          ),
        );
        if (go != true) {
          if (mounted) setState(() => _busy = null);
          return;
        }
        await _db.rpc('owner_delete_ad',
            params: {'p_ad_id': id, 'p_reason': 'حذف من لوحة المالك'});
        okMsg = 'حُذف الإعلان ✓';
      } else {
        await _db.rpc('owner_update_ad',
            params: {'p_ad_id': id, 'p_patch': patch});
      }
      await _load();
      _toast(okMsg, ok: true);
    } catch (e) {
      _toast(FailureText.action(e, action: 'التنفيذ'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _togglePause(Map<String, dynamic> ad) async {
    final paused = ad['paused'] == true;
    String reason = '';
    if (!paused) {
      final ctrl = TextEditingController();
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إيقاف الإعلان'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                'يتوقّف عرضه فورًا على كل الأجهزة. مدّته المدفوعة تستمر '
                'بالعدّ، فإعادته لاحقًا تعيده لما بقي منها.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                    labelText: 'السبب (يُسجَّل في التدقيق)',
                    border: OutlineInputBorder()),
              ),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('إيقاف')),
            ],
          ),
        ),
      );
      if (go != true) return;
      reason = ctrl.text.trim();
    }

    setState(() => _busy = '${ad['id']}');
    try {
      await _db.rpc('owner_set_ad_paused', params: {
        'p_ad_id': ad['id'],
        'p_paused': !paused,
        'p_reason': reason.isEmpty ? null : reason,
      });
      await _load();
      _toast(paused ? 'أُعيد العرض ✓' : 'أُوقف العرض ✓', ok: true);
    } catch (e) {
      _toast(FailureText.action(e, action: 'التنفيذ'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // ── فارق الفئة ───────────────────────────────────────────────────
  Future<void> _editCategorySurcharge(Map<String, dynamic> c) async {
    final points = TextEditingController(text: '${c['points'] ?? 0}');
    final gems = TextEditingController(text: '${c['gems'] ?? 0}');
    var active = c['active'] != false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (d, setD) => AlertDialog(
            title: Text('${c['emoji'] ?? ''} ${c['label'] ?? c['key']}'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                'فارق يُضاف فوق سعر المدّة لمن ينشر في هذه الفئة. صفر = '
                'سعر المدّة وحده.',
                style: TextStyle(fontSize: 11, color: Colors.white60),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: points,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'فارق نقاط ⭐',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: gems,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'فارق جواهر 💎',
                        border: OutlineInputBorder()),
                  ),
                ),
              ]),
              SwitchListTile(
                value: active,
                onChanged: (v) => setD(() => active = v),
                title: const Text('الفئة مفعَّلة'),
                contentPadding: EdgeInsets.zero,
              ),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _busy = '${c['key']}');
    try {
      await _db.rpc('owner_upsert_sponsored_ad_category', params: {
        'p_category_key': c['key'],
        'p_emoji': c['emoji'] ?? '🧵',
        'p_label_ar': c['label'] ?? c['key'],
        'p_points_cost': int.tryParse(points.text.trim()) ?? 0,
        'p_gems_cost': int.tryParse(gems.text.trim()) ?? 0,
        'p_is_active': active,
      });
      await _load();
      _toast('حُفظ على الخادم ✓', ok: true);
    } catch (e) {
      _toast(FailureText.action(e, action: 'الحفظ'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Widget _placementCard(Map<String, dynamic> p) {
    final on = p['enabled'] == true;
    final key = '${p['key']}';
    return Card(
      color: on ? null : const Color(0xFF26262B),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('${p['emoji'] ?? '📣'}', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p['label'] ?? key}',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  if ((p['description']?.toString() ?? '').isNotEmpty)
                    Text('${p['description']}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white54)),
                ],
              ),
            ),
            if (_busy == key)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Switch(
                value: on,
                activeThumbColor: const Color(0xFFFFD700),
                onChanged: _busy != null
                    ? null
                    : (v) => _savePlacement(key, enabled: v),
              ),
          ]),
          if (on) ...[
            const SizedBox(height: 2),
            Row(children: [
              Expanded(
                child: Text(
                  key == 'home' || key == 'game_result'
                      ? 'خانة واحدة في الشاشة'
                      : 'إعلان بعد كل ${_n(p['every_n'])} عنصرًا',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ),
              Text(
                _n(p['max_per_day']) == 0
                    ? 'بلا حدّ يومي'
                    : 'حتى ${_n(p['max_per_day'])} يوميًّا',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.tune_rounded, size: 17),
                onPressed:
                    _busy != null ? null : () => _editPlacement(p),
              ),
            ]),
            Text(
              '📊 ${_n(p['impressions_30d'])} ظهورًا · '
              '${_n(p['clicks_30d'])} نقرة — آخر 30 يومًا',
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _editPlacement(Map<String, dynamic> p) async {
    final key = '${p['key']}';
    final every = TextEditingController(text: '${_n(p['every_n'])}');
    final cap = TextEditingController(text: '${_n(p['max_per_day'])}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('${p['emoji'] ?? ''} ${p['label'] ?? key}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: every,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'عنصر بين إعلان وإعلان',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: cap,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'حدّ يومي لكل عضو (0 = بلا حدّ)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            const Text(
              'الحدّ اليومي مفروض على الخادم: لا يستطيع أي جهاز تجاوزه. '
              'ورقم أصغر للتردّد يعني إعلانات أكثر — وقائمة مليئة '
              'بالإعلانات تُهجَر، فيذهب جمهور المعلن نفسه.',
              style: TextStyle(fontSize: 10.5, color: Colors.white60, height: 1.6),
            ),
          ]),
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
    if (ok != true) return;
    await _savePlacement(key,
        everyN: int.tryParse(every.text.trim()),
        maxPerDay: int.tryParse(cap.text.trim()));
  }

  Future<void> _savePlacement(String key,
      {bool? enabled, int? everyN, int? maxPerDay}) async {
    setState(() => _busy = key);
    try {
      await _db.rpc('owner_set_ad_placement', params: {
        'p_placement_key': key,
        'p_is_enabled': enabled,
        'p_every_n_items': everyN,
        'p_max_per_day': maxPerDay,
      });
      await _load();
      _toast('حُفظ على الخادم ✓', ok: true);
    } catch (e) {
      _toast(e.toString().contains('INVALID_FREQUENCY')
          ? 'التردّد يجب أن يكون بين 1 و 100.'
          : e.toString().contains('INVALID_DAILY_CAP')
              ? 'الحدّ اليومي بين 0 و 100.'
              : FailureText.action(e, action: 'الحفظ'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('تعذّر الجلب:\n$_error', textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton(onPressed: _load, child: const Text('إعادة')),
        ]),
      );
    }

    final rev = _data['revenue_30d'] is Map
        ? Map<String, dynamic>.from(_data['revenue_30d'] as Map)
        : const <String, dynamic>{};
    final srv = _data['serving_30d'] is Map
        ? Map<String, dynamic>.from(_data['serving_30d'] as Map)
        : const <String, dynamic>{};
    final ads = _list('ads');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              color: const Color(0xFF14233A),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('آخر 30 يومًا',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      '${_n(rev['ads'])} إعلانًا  ·  '
                      '⭐ ${_n(rev['points'])}  ·  💎 ${_n(rev['gems'])}\n'
                      '${_n(srv['impressions'])} ظهورًا  ·  '
                      '${_n(srv['clicks'])} نقرة',
                      style: const TextStyle(fontSize: 12, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // المواضع: أين تظهر الإعلانات، وهل تظهر أصلًا. القرار كلّه
            // خادمي — إغلاق موضع هنا يسري فورًا على كل الأجهزة، ولو
            // طلبته نسخة قديمة لم تُعطَ شيئًا.
            const Text('أماكن ظهور الإعلانات',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            const Text(
              'افتح أو أغلق كل مكان على حدة، واضبط كم عنصرًا بين إعلان '
              'وإعلان، وحدًّا يوميًّا لما يراه العضو من ذلك المكان.',
              style: TextStyle(fontSize: 10.5, color: Colors.white54, height: 1.6),
            ),
            const SizedBox(height: 6),
            for (final p in _placements) _placementCard(p),

            const SizedBox(height: 14),

            Row(children: [
              const Expanded(
                child: Text('المُدد وأسعارها',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: 'مدّة جديدة',
                onPressed: _busy != null ? null : () => _editPlan(),
                icon: const Icon(Icons.add_circle, color: Color(0xFFFFD700)),
              ),
            ]),
            for (final p in _list('plans'))
              Card(
                color: p['active'] == false ? const Color(0xFF2A2A2A) : null,
                child: ListTile(
                  dense: true,
                  title: Text(
                    '${p['label']} — ${p['days']} يومًا'
                    '${p['active'] == false ? '  (معطَّلة)' : ''}',
                  ),
                  subtitle: Text(
                    [
                      if (_n(p['points']) > 0) '⭐ ${_n(p['points'])}',
                      if (_n(p['gems']) > 0) '💎 ${_n(p['gems'])}',
                      if (_n(p['cap']) > 0) 'سقف ${_n(p['cap'])} ظهور',
                      if (_n(p['cap']) == 0) 'بلا سقف ظهور',
                      p['category'] == null ? 'كل الفئات' : '${p['category']}',
                    ].join('  ·  '),
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      onPressed: _busy != null ? null : () => _editPlan(p),
                    ),
                    if (p['active'] != false)
                      IconButton(
                        icon: const Icon(Icons.block_rounded,
                            size: 18, color: Colors.orangeAccent),
                        onPressed: _busy != null ? null : () => _disablePlan(p),
                      ),
                  ]),
                ),
              ),

            const SizedBox(height: 14),
            const Text('فارق السعر لكل فئة',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            for (final c in _list('categories'))
              Card(
                child: ListTile(
                  dense: true,
                  leading: Text('${c['emoji'] ?? '🧵'}',
                      style: const TextStyle(fontSize: 20)),
                  title: Text('${c['label'] ?? c['key']}'),
                  subtitle: Text(
                    (_n(c['points']) == 0 && _n(c['gems']) == 0)
                        ? 'بلا فارق — سعر المدّة وحده'
                        : '+⭐ ${_n(c['points'])}  ·  +💎 ${_n(c['gems'])}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: _busy == '${c['key']}'
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.edit_rounded, size: 18),
                  onTap: _busy != null
                      ? null
                      : () => _editCategorySurcharge(c),
                ),
              ),

            const SizedBox(height: 14),
            Text('الإعلانات (${ads.length})',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            if (ads.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا إعلانات بعد.',
                    style: TextStyle(color: Colors.white54)),
              ),
            for (final ad in ads)
              Card(
                color: ad['paused'] == true
                    ? const Color(0xFF3A1E1E)
                    : (ad['expired'] == true || ad['active'] != true)
                        ? const Color(0xFF26262B)
                        : null,
                child: ListTile(
                  title: Text('${ad['text'] ?? ''}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      '${ad['author_name'] ?? 'عضو'}',
                      '${ad['category'] ?? '—'}',
                      '${ad['days'] ?? '?'} يومًا',
                      '${_n(ad['impressions'])}'
                          '${_n(ad['cap']) > 0 ? '/${_n(ad['cap'])}' : ''} ظهور',
                      '${_n(ad['clicks'])} نقرة',
                      if (ad['paid'] != null)
                        '${_n(ad['paid'])} ${ad['currency'] == 'gems' ? '💎' : '⭐'}',
                      if (ad['paused'] == true) 'موقوف',
                      if (ad['expired'] == true) 'انتهت مدّته',
                      if (ad['active'] != true && ad['expired'] != true)
                        'غير نشط',
                    ].join('  ·  '),
                    style: const TextStyle(fontSize: 11),
                  ),
                  // كان الإيقاف هو الإجراء الوحيد المتاح على إعلان
                  // عضو: لا تعديل نصٍّ مخالف، ولا تمديد لمن دفع
                  // وانقطع ظهوره، ولا حذف. الثلاثة موجودة خادميًّا
                  // (owner_update_ad / owner_delete_ad) ولم يكن لها
                  // زرّ واحد في التطبيق.
                  trailing: _busy == '${ad['id']}'
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: ad['paused'] == true
                                ? 'إعادة العرض'
                                : 'إيقاف العرض',
                            icon: Icon(
                              ad['paused'] == true
                                  ? Icons.play_circle_outline
                                  : Icons.pause_circle_outline,
                              color: ad['paused'] == true
                                  ? const Color(0xFF16A34A)
                                  : Colors.orangeAccent,
                            ),
                            onPressed:
                                _busy != null ? null : () => _togglePause(ad),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'تحكّم المالك',
                            enabled: _busy == null,
                            onSelected: (v) => _ownerAdAction(ad, v),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'text',
                                  child: Text('تعديل النصّ')),
                              const PopupMenuItem(
                                  value: 'days', child: Text('تعديل المدّة')),
                              PopupMenuItem(
                                  value: 'visible',
                                  child: Text(ad['active'] == true
                                      ? 'إخفاء الإعلان'
                                      : 'إظهار الإعلان')),
                              const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('حذف نهائي',
                                      style: TextStyle(
                                          color: Colors.redAccent))),
                            ],
                          ),
                        ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
