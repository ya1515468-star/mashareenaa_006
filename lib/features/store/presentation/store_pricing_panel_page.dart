import 'dart:async';
import '../../../core/error/failure_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/monitoring/error_monitor.dart';

/// لوحة الأسعار الموحّدة — المكان الوحيد لتسعير كل أقسام متجر الشات.
/// تُفتح من زر المالك في شريط متجر الشات (لا من صفحة إدارة المالك).
/// كل قسم له 3 فئات (عادي / مميز / نادر)؛ حفظ سعر الفئة يُطبَّق فورًا على
/// الخادم على كل عناصرها. المرساة: 500 نقطة = 0.99$ و5 جواهر = 0.99$،
/// أي الجوهرة ≈ 100 نقطة.
class StorePricingPanelPage extends StatefulWidget {
  const StorePricingPanelPage({super.key});

  @override
  State<StorePricingPanelPage> createState() => _StorePricingPanelPageState();
}

const _sectionLabels = <String, String>{
  'frame': 'الإطارات',
  'simple_frame': 'إطارات ملونة',
  'background': 'خلفية إطار الاسم',
  'name_effect': 'تأثيرات اسم المستخدم',
  'message_color': 'ألوان الرسائل',
  'role_color': 'تلوين الرتبة',
  'name_template': 'قالب الاسم',
  'name_animation': 'حيوانات فوق الاسم',
  'profile_service': 'خدمات VIP',
};

const _tierLabels = <String, String>{
  'normal': 'عادي',
  'premium': 'مميز',
  'rare': 'نادر',
};

const _tierColors = <String, Color>{
  'normal': Color(0xFF8FA3B8),
  'premium': Color(0xFF4FC3F7),
  'rare': Color(0xFFE9C46A),
};

class _StorePricingPanelPageState extends State<StorePricingPanelPage> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _tiers = const [];
  List<Map<String, dynamic>> _memberships = const [];
  final Map<String, TextEditingController> _ctrls = {};
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String key, Object? value) {
    final c = _ctrls.putIfAbsent(key, () => TextEditingController());
    c.text = '${value ?? 0}';
    return c;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _db.rpc('admin_get_store_pricing');
      final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final tiers = (map['tiers'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final mems = (map['memberships'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (final t in tiers) {
        final k = '${t['section']}|${t['tier']}';
        _ctrl('$k|p', t['price_points']);
        _ctrl('$k|g', t['price_gems']);
      }
      for (final m in mems) {
        _ctrl('mem|${m['id']}|p', m['price_points']);
        _ctrl('mem|${m['id']}|g', m['price_gems']);
      }
      if (!mounted) return;
      setState(() {
        _tiers = tiers;
        _memberships = mems;
        _loading = false;
      });
    } catch (e, st) {
      unawaited(ErrorMonitor.report(e,
          stack: st, screen: 'store_pricing_panel', source: 'load'));
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = FailureText.of(e);
      });
    }
  }

  void _snack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
    ));
  }

  int? _read(String key) => int.tryParse(_ctrls[key]?.text.trim() ?? '');

  Future<void> _saveTier(String section, String tier) async {
    final k = '$section|$tier';
    final p = _read('$k|p');
    final g = _read('$k|g');
    if (p == null || g == null || p < 0 || g < 0) {
      _snack('أدخل أرقامًا صحيحة غير سالبة', ok: false);
      return;
    }
    setState(() => _busy = true);
    try {
      final n = await _db.rpc('admin_set_store_price_tier', params: {
        'p_section': section,
        'p_tier': tier,
        'p_price_points': p,
        'p_price_gems': g,
      });
      _changed = true;
      _snack('تم الحفظ ✓ (طُبّق على $n عنصر)');
      await _load();
    } catch (e, st) {
      unawaited(ErrorMonitor.report(e,
          stack: st, screen: 'store_pricing_panel', source: 'save_tier'));
      _snack(FailureText.action(e, action: 'الحفظ'), ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveMembership(String id) async {
    final p = _read('mem|$id|p');
    final g = _read('mem|$id|g');
    if (p == null || g == null || p < 0 || g < 0) {
      _snack('أدخل أرقامًا صحيحة غير سالبة', ok: false);
      return;
    }
    setState(() => _busy = true);
    try {
      await _db.rpc('admin_set_membership_price', params: {
        'p_tier_id': id,
        'p_price_points': p,
        'p_price_gems': g,
      });
      _changed = true;
      _snack('تم حفظ سعر العضوية ✓');
      await _load();
    } catch (e, st) {
      unawaited(ErrorMonitor.report(e,
          stack: st, screen: 'store_pricing_panel', source: 'save_membership'));
      _snack(FailureText.action(e, action: 'الحفظ'), ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyDefaults() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تطبيق التسعير المقترح'),
        content: const SingleChildScrollView(
          child: Text(
            'سيُعاد تسعير كل عناصر المتجر بثلاث فئات منخفضة '
            'مناسبة لمرحلة جذب المستخدمين (الجوهرة ≈ 100 نقطة):\n\n'
            '• الإطارات: 400 / 900 / 1800 نقطة\n'
            '• الإطارات الملونة: 150 / 300 / 600\n'
            '• خلفية إطار الاسم: 200 / 400 / 800\n'
            '• تأثيرات الاسم: 300 / 600 / 1200\n'
            '• ألوان الرسائل وتلوين الرتبة: 100 / 250 / 500\n'
            '• قالب الاسم وحيوانات فوق الاسم: 500 / 1000 / 2000\n'
            '• خدمات VIP: 1000 / 2500 / 5000\n'
            '• العضويات الشهرية: من 1500 (البرونزية) حتى 16000 (Ultimate)، '
            'ومنحة الشراء 25% من السعر بالنقاط (كانت المنحة تساوي السعر أو تفوقه).\n\n'
            'الهدايا لا تتغير. يمكنك بعدها تعديل سعر أي فئة من هذه اللوحة.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تطبيق')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final raw = await _db.rpc('admin_apply_default_store_pricing');
      final n = raw is Map ? raw['items_priced'] : null;
      _changed = true;
      _snack('تم تطبيق التسعير ✓ (${n ?? '?'} عنصر)');
      await _load();
    } catch (e, st) {
      unawaited(ErrorMonitor.report(e,
          stack: st, screen: 'store_pricing_panel', source: 'apply_defaults'));
      _snack(FailureText.of(e), ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _numField(String key, String label) => SizedBox(
        width: 84,
        child: TextField(
          controller: _ctrls[key],
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Future<void> _openAssign(String section) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1628),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _AssignTierSheet(
        section: section,
        sectionLabel: _sectionLabels[section] ?? section,
      ),
    );
    if (changed == true) {
      _changed = true;
      await _load(); // عدّاد "كم عنصرًا في الشريحة" يتغيّر بعد الإسناد
    }
  }

  Widget _sectionCard(String section) {
    final rows = _tiers.where((t) => t['section'] == section).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text(_sectionLabels[section] ?? section,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900)),
              ),
              // بلا هذا الزرّ تبقى اللوحة بلا أثر: تعديل سعر شريحة لا
              // يمسّ شيئًا ما دام لا عنصر مُسنَدًا إليها.
              TextButton.icon(
                onPressed: _busy ? null : () => _openAssign(section),
                icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                label: const Text('إسناد العناصر'),
              ),
            ]),
            const SizedBox(height: 8),
            for (final t in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: (_tierColors[t['tier']] ?? Colors.grey).withValues(alpha: .18),
                        border: Border.all(color: _tierColors[t['tier']] ?? Colors.grey),
                      ),
                      child: Column(children: [
                        Text(_tierLabels[t['tier']] ?? '${t['tier']}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _tierColors[t['tier']])),
                        Text('${t['items'] ?? 0} عنصر',
                            style: const TextStyle(fontSize: 10, color: Colors.white60)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    _numField('$section|${t['tier']}|p', 'نقاط'),
                    const SizedBox(width: 6),
                    _numField('$section|${t['tier']}|g', 'جواهر'),
                    const Spacer(),
                    IconButton(
                      tooltip: 'حفظ',
                      onPressed: _busy ? null : () => _saveTier(section, '${t['tier']}'),
                      icon: const Icon(Icons.save_rounded, color: Colors.greenAccent),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('لوحة الأسعار'),
            actions: [
              IconButton(
                tooltip: 'تحديث',
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('تعذر تحميل الأسعار: $_error', textAlign: TextAlign.center),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: Text(
                            'المرساة: 500 نقطة = 0.99\$ • 5 جواهر = 0.99\$ (الجوهرة ≈ 100 نقطة). '
                            'حفظ سعر فئة يطبَّق فورًا على كل عناصرها.',
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _applyDefaults,
                            icon: const Icon(Icons.auto_fix_high),
                            label: const Text('تطبيق التسعير المقترح على كل المتجر'),
                          ),
                        ),
                        for (final s in _sectionLabels.keys) _sectionCard(s),
                        if (_memberships.isNotEmpty)
                          Card(
                            margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('العضويات الشهرية',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 8),
                                  for (final m in _memberships)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 5),
                                      child: Row(children: [
                                        SizedBox(
                                          width: 70,
                                          child: Text('${m['name']}',
                                              style: const TextStyle(fontWeight: FontWeight.w700)),
                                        ),
                                        _numField('mem|${m['id']}|p', 'نقاط'),
                                        const SizedBox(width: 6),
                                        _numField('mem|${m['id']}|g', 'جواهر'),
                                        const Spacer(),
                                        IconButton(
                                          tooltip: 'حفظ',
                                          onPressed: _busy ? null : () => _saveMembership('${m['id']}'),
                                          icon: const Icon(Icons.save_rounded, color: Colors.greenAccent),
                                        ),
                                      ]),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(
                            'لتعديل سعر عنصر منفرد: استعمل قائمة المالك (⋮) على العنصر داخل قسمه في المتجر.',
                            style: TextStyle(fontSize: 11.5, color: Colors.white54),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

/// ورقة إسناد عناصر قسم إلى شريحة سعر.
///
/// لماذا هي ضرورية: لوحة الشرائح بلا إسناد بلا أثر — تعدّل سعر شريحة فلا
/// يتغيّر شيء، لأنّ كل عناصر المتجر (456 عنصرًا) بلا شريحة. وبقيت كذلك
/// لأنّ دالّة الإسناد كانت موجودة في الخادم ولا واجهة تناديها.
///
/// الإسناد **لا يُفرَض** على كل العناصر: ما تختاره أنت وحده يُسنَد، فتسعيرك
/// الحالي المتنوّع لا يُطمَس.
class _AssignTierSheet extends StatefulWidget {
  const _AssignTierSheet({required this.section, required this.sectionLabel});

  final String section;
  final String sectionLabel;

  @override
  State<_AssignTierSheet> createState() => _AssignTierSheetState();
}

class _AssignTierSheetState extends State<_AssignTierSheet> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _items = const [];
  final Set<String> _picked = <String>{};
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await _db.rpc('admin_list_section_items',
          params: {'p_section': widget.section});
      final list = raw is List ? raw : const <dynamic>[];
      setState(() {
        _items = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(FailureText.of(e))));
    }
  }

  Future<void> _apply(String? tier) async {
    if (_picked.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await _db.rpc('admin_set_items_price_tier', params: {
        'p_section': widget.section,
        'p_item_keys': _picked.toList(),
        'p_tier': tier,
      });
      _changed = true;
      final n = (res is Map ? res['updated'] : null) ?? _picked.length;
      _picked.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(tier == null
              ? 'فُكّ إسناد $n عنصرًا'
              : 'أُسند $n عنصرًا إلى ${_tierLabels[tier] ?? tier}'),
          backgroundColor: const Color(0xFF16A34A)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(FailureText.of(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final shown = q.isEmpty
        ? _items
        : _items
            .where((i) => '${i['name'] ?? ''}${i['key'] ?? ''}'.contains(q))
            .toList(growable: false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Column(children: [
          const SizedBox(height: 10),
          Text('إسناد شريحة — ${widget.sectionLabel}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                hintText: 'بحث بالاسم',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Row(children: [
            const SizedBox(width: 12),
            Text('محدَّد: ${_picked.length}',
                style: const TextStyle(color: Colors.white70)),
            const Spacer(),
            TextButton(
              onPressed: shown.isEmpty
                  ? null
                  : () => setState(() {
                        for (final i in shown) {
                          _picked.add('${i['key']}');
                        }
                      }),
              child: const Text('تحديد الظاهر'),
            ),
            TextButton(
              onPressed:
                  _picked.isEmpty ? null : () => setState(_picked.clear),
              child: const Text('إلغاء التحديد'),
            ),
            const SizedBox(width: 6),
          ]),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: controller,
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final it = shown[i];
                      final key = '${it['key']}';
                      final tier = it['tier']?.toString();
                      return CheckboxListTile(
                        dense: true,
                        value: _picked.contains(key),
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                  if (v == true) {
                                    _picked.add(key);
                                  } else {
                                    _picked.remove(key);
                                  }
                                }),
                        title: Text('${it['name'] ?? key}',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          it['points'] == null
                              ? (tier == null ? 'بلا شريحة' : '')
                              : '${it['points']} نقطة · ${it['gems']} جوهرة',
                          style: const TextStyle(fontSize: 11),
                        ),
                        secondary: tier == null
                            ? const Text('—',
                                style: TextStyle(color: Colors.white38))
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: (_tierColors[tier] ?? Colors.grey)
                                      .withValues(alpha: .18),
                                  border: Border.all(
                                      color: _tierColors[tier] ?? Colors.grey),
                                ),
                                child: Text(_tierLabels[tier] ?? tier,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: _tierColors[tier])),
                              ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(children: [
                for (final t in const ['normal', 'premium', 'rare'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: _tierColors[t]),
                        onPressed:
                            _busy || _picked.isEmpty ? null : () => _apply(t),
                        child: Text(_tierLabels[t] ?? t,
                            style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: _busy || _picked.isEmpty ? null : () => _apply(null),
                  child: const Text('فكّ'),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.pop(context, _changed),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
