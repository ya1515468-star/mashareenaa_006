import 'dart:async';
import '../../../../core/error/failure_text.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تحكّم المالك بتسليم الإشعارات.
///
/// لماذا وُجدت هذه الشاشة: ستّ ميزات مبنيّة في التطبيق (المنشن، الرد،
/// الإعجاب، التعليق، المتابعة، طلب الصداقة) كانت معطَّلة بالكامل —
/// قناة في القاعدة كانت تُسقط إشعاراتها كلّها بلا شرط، فلم يُخزَّن منها
/// صفّ واحد قطّ بينما العميل يرندرها جميعًا.
///
/// استُبدل الحجب الأعمى بسياسة من ثلاث طبقات، وهذه الشاشة هي الطبقة
/// الأولى: المفتاح العامّ بيد المالك. والطبقتان الأخريان خادميّتان —
/// تفضيل العضو لنفسه، ودمج المكرّر مع سقف بالساعة.
class AdminNotificationsTab extends StatefulWidget {
  const AdminNotificationsTab({super.key});

  @override
  State<AdminNotificationsTab> createState() => _AdminNotificationsTabState();
}

class _AdminNotificationsTabState extends State<AdminNotificationsTab> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _rows = const [];
  Map<String, dynamic> _grant = const {};
  bool _loading = true;
  String? _busyType;
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
      final raw = await _db.rpc('owner_get_notification_settings');
      final list = raw is List ? raw : const <dynamic>[];
      try {
        final g = await _db.rpc('owner_get_signup_grant');
        if (g is Map) _grant = Map<String, dynamic>.from(g);
      } catch (_) {}
      setState(() {
        _rows = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = FailureText.of(e);
        _loading = false;
      });
    }
  }

  Future<void> _save(String type,
      {bool? enabled, int? maxPerHour, int? dedupeMinutes}) async {
    setState(() => _busyType = type);
    try {
      await _db.rpc('owner_set_notification_setting', params: {
        'p_type': type,
        'p_enabled': enabled,
        'p_max_per_hour': maxPerHour,
        'p_dedupe_minutes': dedupeMinutes,
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم الحفظ ✓'),
          backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(FailureText.action(e, action: 'الحفظ'))));
    } finally {
      if (mounted) setState(() => _busyType = null);
    }
  }

  Future<void> _editNumber(Map<String, dynamic> r, String field) async {
    final isCap = field == 'max_per_hour';
    final c = TextEditingController(text: '${r[field] ?? 0}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(isCap ? 'سقف الساعة' : 'نافذة الدمج (دقائق)'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: c,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Text(
              isCap
                  ? 'أقصى عدد إشعارات من هذا النوع يصل العضو الواحد في الساعة. '
                      'صفر = بلا سقف — استعمله لما لا يجوز إسقاطه مثل طلب '
                      'الصداقة، فإسقاطه يعني ألّا يعلم المستلم بالطلب أصلًا.'
                  : 'إشعارٌ ثانٍ لنفس العضو ونفس المرجع داخل هذه المدّة '
                      'يُدمَج ولا يُرسَل. صفر = بلا دمج.',
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(c.text.trim()) ?? 0),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (v == null) return;
    await _save('${r['type']}',
        maxPerHour: isCap ? v : null, dedupeMinutes: isCap ? null : v);
  }

  Future<void> _editGrant(String field, String title, String hint) async {
    final c = TextEditingController(text: '${_grant[field] ?? 0}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: c,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Text(hint,
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, int.tryParse(c.text.trim()) ?? 0),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (v == null) return;
    try {
      await _db.rpc('owner_set_signup_grant', params: {
        'p_points': field == 'points' ? v : null,
        'p_gems': field == 'gems' ? v : null,
        'p_xp': field == 'xp' ? v : null,
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(FailureText.action(e, action: 'الحفظ'))));
    }
  }

  Widget _signupGrantCard() {
    return Card(
      color: const Color(0xFF14233A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
              child: Text('🎁 منحة التسجيل',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ),
            Switch(
              value: _grant['enabled'] == true,
              onChanged: (v) async {
                try {
                  await _db.rpc('owner_set_signup_grant',
                      params: {'p_enabled': v});
                  await _load();
                } catch (_) {}
              },
            ),
          ]),
          const Text(
            'ما يأخذه العضو فور تسجيله. تُمنح مرّة واحدة لكل حساب ولا تتكرّر '
            'مهما أُعيد إنشاء الصفّ.',
            style: TextStyle(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _editGrant('points', 'نقاط التسجيل',
                    'رصيد النقاط الذي يبدأ به العضو الجديد.'),
                child: Text('${_grant['points'] ?? 0} نقطة',
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _editGrant('gems', 'جواهر التسجيل',
                    'الجواهر عملة الشراء الأغلى — ابدأ بعدد صغير.'),
                child: Text('${_grant['gems'] ?? 0} جوهرة',
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _editGrant('xp', 'خبرة التسجيل',
                    'نقاط الخبرة تحدّد رتبة العضو وتقدّمه.'),
                child: Text('${_grant['xp'] ?? 0} خبرة',
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'مُنحت لـ${_grant['issued_total'] ?? 0} عضوًا '
            '(${_grant['issued_7d'] ?? 0} في آخر 7 أيام)',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ]),
      ),
    );
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              color: const Color(0xFF1B1230),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'المفتاح هنا عامّ لكل المنصّة. ويبقى للعضو أن يُطفئ نوعًا '
                  'لنفسه، وتفضيله يغلب — فإطفاؤك يُسكت الجميع، وتشغيلك لا '
                  'يُجبر من أطفأه.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _signupGrantCard(),
            const SizedBox(height: 6),
            for (final r in _rows)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${r['label'] ?? r['type']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)),
                              Text(
                                '${r['type']}  ·  أُرسل في 24 ساعة: ${r['sent_24h'] ?? 0}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        if (_busyType == r['type'])
                          const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                        else
                          Switch(
                            value: r['enabled'] == true,
                            onChanged: (v) =>
                                _save('${r['type']}', enabled: v),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busyType != null
                                ? null
                                : () => _editNumber(r, 'max_per_hour'),
                            child: Text(
                              (r['max_per_hour'] as num?)?.toInt() == 0
                                  ? 'سقف الساعة: بلا حدّ'
                                  : 'سقف الساعة: ${r['max_per_hour']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busyType != null
                                ? null
                                : () => _editNumber(r, 'dedupe_minutes'),
                            child: Text(
                              (r['dedupe_minutes'] as num?)?.toInt() == 0
                                  ? 'الدمج: معطّل'
                                  : 'الدمج: ${r['dedupe_minutes']} د',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
