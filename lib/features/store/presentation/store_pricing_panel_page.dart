import 'dart:async';

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
        _error = '$e';
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
      _snack('تم الحفظ على الخادم ✓ (طُبّق على $n عنصر)');
      await _load();
    } catch (e, st) {
      unawaited(ErrorMonitor.report(e,
          stack: st, screen: 'store_pricing_panel', source: 'save_tier'));
      _snack('فشل الحفظ: $e', ok: false);
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
      _snack('فشل الحفظ: $e', ok: false);
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
            'سيُعاد تسعير كل عناصر المتجر على الخادم بثلاث فئات منخفضة '
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
      _snack('تم تطبيق التسعير على الخادم ✓ (${n ?? '?'} عنصر)');
      await _load();
    } catch (e, st) {
      unawaited(ErrorMonitor.report(e,
          stack: st, screen: 'store_pricing_panel', source: 'apply_defaults'));
      _snack('فشل التطبيق: $e', ok: false);
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
            Text(_sectionLabels[section] ?? section,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
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
                            'حفظ سعر فئة يطبَّق فورًا على كل عناصرها في الخادم.',
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
