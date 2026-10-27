import 'dart:async';

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
      if (!mounted) return;
      setState(() {
        _data = raw is Map ? Map<String, dynamic>.from(raw) : const {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
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
              : 'تعذّر الحفظ: $e');
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
      _toast('تعذّر التعطيل: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // ── إيقاف إعلان ──────────────────────────────────────────────────
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
      _toast('تعذّر التنفيذ: $e');
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
      _toast('تعذّر الحفظ: $e');
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
                  trailing: _busy == '${ad['id']}'
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}
