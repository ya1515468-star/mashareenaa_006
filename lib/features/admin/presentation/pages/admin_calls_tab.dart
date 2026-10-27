import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تحكّم المالك بالمكالمات: الدقائق المرفقة بكل عضوية، والسعر بعد نفادها.
///
/// لماذا الشاشتان واحدة: الدقائق المرفقة والسعر بعد نفادها قراران
/// متلازمان — دقائق سخيّة بسعر مرتفع شيء، ودقائق شحيحة بسعر زهيد شيء
/// آخر. فصلهما في شاشتين يجعل أحدهما يُنسى.
///
/// وكل مستوى في الكتالوج يظهر هنا ولو لم يُضبط بعد، وإلّا بقي غائبًا فلا
/// يُلاحَظ أنّه بلا دقائق — وهو ما حدث فعلًا: المستوى الأسطوري كان على
/// صفر وUltimate بلا صفّ إطلاقًا، أي أنّ أغلى عضويتين كانتا تعطيان أقلّ
/// من البرونزية.
class AdminCallsTab extends StatefulWidget {
  const AdminCallsTab({super.key});

  @override
  State<AdminCallsTab> createState() => _AdminCallsTabState();
}

class _AdminCallsTabState extends State<AdminCallsTab> {
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
      final raw = await _db.rpc('owner_get_call_settings');
      setState(() {
        _data = raw is Map ? Map<String, dynamic>.from(raw) : const {};
        _loading = false;
      });
    } catch (e) {
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

  Future<void> _editMinutes(Map<String, dynamic> t) async {
    final voice = TextEditingController(text: '${t['voice_minutes'] ?? 0}');
    final video = TextEditingController(text: '${t['video_minutes'] ?? 0}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('دقائق ${t['name'] ?? t['tier_id']}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: voice,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'دقائق صوتية شهريًّا',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: video,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'دقائق مرئية شهريًّا',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            const Text(
              'ما يستهلكه العضو ضمن هذه الدقائق لا يُخصم من رصيده. وبعد '
              'نفادها يُحاسَب بسعر الدقيقة أدناه. صفر = بلا دقائق مرفقة.',
              style: TextStyle(fontSize: 11, color: Colors.white60),
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
    setState(() => _busy = '${t['tier_id']}');
    try {
      await _db.rpc('owner_set_call_minutes', params: {
        'p_tier_id': t['tier_id'],
        'p_voice_minutes': int.tryParse(voice.text.trim()) ?? 0,
        'p_video_minutes': int.tryParse(video.text.trim()) ?? 0,
        'p_enabled': true,
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('حُفظ على الخادم ✓'),
          backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذّر الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _editPricing(Map<String, dynamic> p) async {
    final pts = TextEditingController(text: '${p['points_per_minute'] ?? 0}');
    final free = TextEditingController(text: '${p['free_seconds'] ?? 0}');
    var enabled = p['enabled'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (c, setD) => AlertDialog(
            title: Text(p['call_type'] == 'video'
                ? 'سعر المكالمة المرئية'
                : 'سعر المكالمة الصوتية'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: pts,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'نقاط لكل دقيقة',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: free,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'ثوانٍ مجانية في كل مكالمة',
                    border: OutlineInputBorder()),
              ),
              SwitchListTile(
                value: enabled,
                onChanged: (v) => setD(() => enabled = v),
                title: const Text('المحاسبة مفعَّلة'),
                contentPadding: EdgeInsets.zero,
              ),
              const Text(
                'إطفاء المحاسبة يجعل المكالمات مجانية للجميع بلا حدّ.',
                style: TextStyle(fontSize: 11, color: Colors.white60),
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
      ),
    );
    if (ok != true) return;
    setState(() => _busy = '${p['call_type']}');
    try {
      await _db.rpc('admin_set_call_pricing', params: {
        'p_call_type': p['call_type'],
        'p_points_per_minute': int.tryParse(pts.text.trim()) ?? 0,
        'p_gems_per_minute': p['gems_per_minute'] ?? 0,
        'p_free_seconds': int.tryParse(free.text.trim()) ?? 0,
        'p_enabled': enabled,
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذّر الحفظ: $e')));
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

    final usage = _data['usage_30d'] is Map
        ? Map<String, dynamic>.from(_data['usage_30d'] as Map)
        : const <String, dynamic>{};
    final free = _data['free_tier'] is Map
        ? Map<String, dynamic>.from(_data['free_tier'] as Map)
        : const <String, dynamic>{};

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
                child: Text(
                  'آخر 30 يومًا: ${usage['calls'] ?? 0} مكالمة · '
                  '${usage['billed_minutes'] ?? 0} دقيقة محاسَبة · '
                  '${usage['charged_points'] ?? 0} نقطة',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text('سعر الدقيقة بعد نفاد دقائق العضوية',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            for (final p in _list('pricing'))
              Card(
                child: ListTile(
                  title: Text(p['call_type'] == 'video'
                      ? '📹 مكالمة مرئية'
                      : '🎙️ مكالمة صوتية'),
                  subtitle: Text(
                    '${p['points_per_minute']} نقطة/دقيقة  ·  '
                    '${p['free_seconds']} ثانية مجانية  ·  '
                    '${p['enabled'] == true ? 'المحاسبة مفعَّلة' : 'مجاني بلا حدّ'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: _busy == '${p['call_type']}'
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.edit_rounded, size: 18),
                  onTap: _busy != null ? null : () => _editPricing(p),
                ),
              ),
            const SizedBox(height: 14),
            const Text('الدقائق المرفقة بكل عضوية — شهريًّا',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Card(
              child: ListTile(
                dense: true,
                title: const Text('بلا عضوية'),
                subtitle: Text(
                  'صوتي ${free['voice_minutes'] ?? 0} د  ·  '
                  'مرئي ${free['video_minutes'] ?? 0} د',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.edit_rounded, size: 18),
                onTap: _busy != null
                    ? null
                    : () => _editMinutes({
                          'tier_id': 'free',
                          'name': 'بلا عضوية',
                          'voice_minutes': free['voice_minutes'] ?? 0,
                          'video_minutes': free['video_minutes'] ?? 0,
                        }),
              ),
            ),
            for (final t in _list('tiers'))
              Card(
                color: t['configured'] == true
                    ? null
                    : const Color(0xFF3A1E1E), // غير مضبوط = يُرى فورًا
                child: ListTile(
                  title: Row(children: [
                    Expanded(child: Text('${t['name'] ?? t['tier_id']}')),
                    if (t['configured'] != true)
                      const Text('غير مضبوط',
                          style: TextStyle(
                              fontSize: 10, color: Colors.orangeAccent)),
                  ]),
                  subtitle: Text(
                    'صوتي ${t['voice_minutes']} د  ·  مرئي ${t['video_minutes']} د'
                    '${t['enabled'] == true ? '' : '  ·  معطَّل'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: _busy == '${t['tier_id']}'
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.edit_rounded, size: 18),
                  onTap: _busy != null ? null : () => _editMinutes(t),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
