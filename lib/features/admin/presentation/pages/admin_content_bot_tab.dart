import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/monitoring/error_monitor.dart';

/// تحكّم المالك ببوت المحتوى في الغرف: تشغيل/إيقاف، الفاصل بالدقائق،
/// وإضافة/تعديل/تعطيل المنشورات. النشر نفسه خادمي بالكامل (pg_cron يستدعي
/// private.content_bot_tick كل دقيقة) فيعمل في كل غرفة نشطة حتى مع إغلاق
/// كل الأجهزة.
class AdminContentBotTab extends StatefulWidget {
  const AdminContentBotTab({super.key});

  @override
  State<AdminContentBotTab> createState() => _AdminContentBotTabState();
}

const _categories = <String, String>{
  'sewing': '✂️ خياطة',
  'adhkar': '📿 أذكار',
  'secrets': '🧵 أسرار المهنة',
  'life': '🌿 الحياة',
  'experience': '💡 تجارب',
  'trade': '💼 تجارة',
};

class _AdminContentBotTabState extends State<AdminContentBotTab> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  bool _busy = false;
  bool _enabled = true;
  final _interval = TextEditingController();
  List<Map<String, dynamic>> _posts = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _db.rpc('admin_get_content_bot');
      final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final s = map['settings'] is Map ? Map<String, dynamic>.from(map['settings'] as Map) : <String, dynamic>{};
      final posts = (map['posts'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _enabled = s['enabled'] != false;
        _interval.text = '${s['interval_minutes'] ?? 3}';
        _posts = posts;
        _loading = false;
      });
    } catch (e, st) {
      unawaited(ErrorMonitor.report(e, stack: st, screen: 'admin_content_bot', source: 'load'));
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _snack(String m, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700));
  }

  Future<void> _saveSettings() async {
    final mins = int.tryParse(_interval.text.trim());
    if (mins == null || mins < 1 || mins > 1440) {
      _snack('الفاصل بين 1 و1440 دقيقة', ok: false);
      return;
    }
    setState(() => _busy = true);
    try {
      await _db.rpc('admin_set_content_bot_settings',
          params: {'p_enabled': _enabled, 'p_interval_minutes': mins});
      _snack('تم الحفظ على الخادم ✓');
    } catch (e, st) {
      unawaited(ErrorMonitor.report(e, stack: st, screen: 'admin_content_bot', source: 'settings'));
      _snack('فشل الحفظ: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? post]) async {
    final body = TextEditingController(text: post?['body']?.toString() ?? '');
    var category = post?['category']?.toString() ?? 'sewing';
    var active = post?['is_active'] != false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(post == null ? 'منشور جديد' : 'تعديل المنشور'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                items: [
                  for (final e in _categories.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setD(() => category = v ?? category),
                decoration: const InputDecoration(labelText: 'التصنيف'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: body,
                maxLines: 6,
                maxLength: 600,
                decoration: const InputDecoration(
                    labelText: 'النص', border: OutlineInputBorder()),
              ),
              SwitchListTile(
                value: active,
                onChanged: (v) => setD(() => active = v),
                title: const Text('مفعّل'),
                contentPadding: EdgeInsets.zero,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    final text = body.text.trim();
    body.dispose();
    if (ok != true || !mounted) return;
    if (text.length < 5) {
      _snack('النص قصير جدًا', ok: false);
      return;
    }
    setState(() => _busy = true);
    try {
      await _db.rpc('admin_upsert_content_bot_post', params: {
        'p_id': post?['id'],
        'p_category': category,
        'p_body': text,
        'p_active': active,
      });
      _snack('تم الحفظ ✓');
      await _load();
    } catch (e, st) {
      unawaited(ErrorMonitor.report(e, stack: st, screen: 'admin_content_bot', source: 'upsert'));
      _snack('فشل الحفظ: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> post) async {
    setState(() => _busy = true);
    try {
      await _db.rpc('admin_upsert_content_bot_post', params: {
        'p_id': post['id'],
        'p_category': post['category'],
        'p_body': post['body'],
        'p_active': post['is_active'] != true,
      });
      await _load();
    } catch (e, st) {
      unawaited(ErrorMonitor.report(e, stack: st, screen: 'admin_content_bot', source: 'toggle'));
      _snack('فشل: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('تعذر التحميل: $_error', textAlign: TextAlign.center));
    }
    final active = _posts.where((p) => p['is_active'] == true).length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('🤖 بوت المحتوى في الغرف',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text(
                    'ينشر تلقائيًا في كل غرفة نشطة (وأي غرفة جديدة) معلومة من القائمة بالتناوب. '
                    'لا ينشر مرتين متتاليتين في غرفة خاملة حتى يكتب أحد الأعضاء.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  SwitchListTile(
                    value: _enabled,
                    onChanged: _busy ? null : (v) => setState(() => _enabled = v),
                    title: const Text('مفعّل'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  Row(children: [
                    const Text('النشر كل'),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: _interval,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('دقيقة'),
                    const Spacer(),
                    FilledButton(onPressed: _busy ? null : _saveSettings, child: const Text('حفظ')),
                  ]),
                ]),
              ),
            ),
            Row(children: [
              Text('المنشورات: ${_posts.length} (المفعّل $active)',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton.icon(
                onPressed: _busy ? null : () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة'),
              ),
            ]),
            for (final p in _posts)
              Card(
                child: ListTile(
                  onTap: _busy ? null : () => _edit(p),
                  title: Text('${p['body']}', maxLines: 3, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${_categories[p['category']] ?? p['category']} • نُشر ${p['posted_count'] ?? 0} مرة'),
                  trailing: Switch(
                    value: p['is_active'] == true,
                    onChanged: _busy ? null : (_) => _toggle(p),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
