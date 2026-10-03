import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/chat_visual_size_service.dart';

class ChatFeatureSettingsPage extends StatefulWidget {
  const ChatFeatureSettingsPage({super.key});
  @override
  State<ChatFeatureSettingsPage> createState() =>
      _ChatFeatureSettingsPageState();
}

class _ChatFeatureSettingsPageState extends State<ChatFeatureSettingsPage> {
  final db = Supabase.instance.client;
  final reply = TextEditingController();
  final quote = TextEditingController();
  final targetUid = TextEditingController();
  bool enabled = true;
  String timezone = 'UTC';
  bool loading = true;
  bool saving = false;
  bool sizeLoading = true;
  bool isOwner = false;
  bool canManageSelf = false;
  int globalFrameLevel = 5;
  int globalSmileyLevel = 5;
  int globalAvatarLevel = 5;
  int globalAnimalLevel = 5;
  int targetAvatarLevel = 5;
  int targetAnimalLevel = 5;
  int selfFrameLevel = 5;
  int selfSmileyLevel = 5;
  int targetFrameLevel = 5;
  int targetSmileyLevel = 5;
  List<Map<String, dynamic>> authorities = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadVisualSize();
  }

  @override
  void dispose() {
    reply.dispose();
    quote.dispose();
    targetUid.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await db
          .from('chat_feature_settings')
          .select()
          .eq('id', true)
          .single();
      if (mounted) {
        setState(() {
          enabled = r['enabled'] == true;
          reply.text = '';
          quote.text = '';
          timezone = r['timezone_reset']?.toString() ?? 'UTC';
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadVisualSize() async {
    try {
      final uid = db.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) setState(() => sizeLoading = false);
        return;
      }
      final raw = await db.rpc('get_chat_visual_size_config', params: {'p_user_id': uid});
      if (raw is Map && mounted) {
        final size = ChatVisualSize.fromMap(Map<String, dynamic>.from(raw));
        setState(() {
          globalFrameLevel = size.globalFrameLevel;
          globalSmileyLevel = size.globalSmileyLevel;
          globalAvatarLevel = size.globalAvatarLevel;
          globalAnimalLevel = size.globalAnimalLevel;
          selfFrameLevel = size.frameLevel;
          selfSmileyLevel = size.smileyLevel;
          isOwner = size.isPlatformOwner;
          canManageSelf = size.canManageSelf;
          targetFrameLevel = size.frameLevel;
          targetAvatarLevel = size.avatarLevel;
          targetAnimalLevel = size.animalLevel;
          targetSmileyLevel = size.smileyLevel;
          sizeLoading = false;
        });
        if (size.isPlatformOwner) {
          final rows = await ChatVisualSizeService.authorities();
          if (mounted) setState(() => authorities = rows);
        }
      } else if (mounted) {
        setState(() => sizeLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => sizeLoading = false);
    }
  }

  Future<void> _save() async {
    final a = int.tryParse(reply.text.trim());
    final b = int.tryParse(quote.text.trim());
    if (a == null || b == null || a < 0 || b < 0) return;
    setState(() => saving = true);
    try {
      await db.rpc('dragon_update_chat_feature_settings', params: {
        'p_enabled': enabled,
        'p_limit_d3_reply_daily': a,
        'p_limit_d3_quote_daily': b,
        'p_timezone_reset': timezone,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ إعدادات الرد 3D خادميًا ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _levelButtons({
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var level = 1; level <= 10; level++)
          SizedBox(
            width: 42,
            height: 38,
            child: FilledButton(
              onPressed: saving ? null : () => onChanged(level),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor:
                    value == level ? const Color(0xFF8E44AD) : const Color(0xFF2A1935),
              ),
              child: Text('$level'),
            ),
          ),
      ],
    );
  }

  Widget _visualCard({
    required String title,
    required String subtitle,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Card(
      color: const Color(0xFF17101F),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text('الحجم الحالي: $value / 10', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 9),
            _levelButtons(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Future<void> _saveGlobal() async {
    setState(() => saving = true);
    try {
      await ChatVisualSizeService.setGlobal(
        frameLevel: globalFrameLevel,
        smileyLevel: globalSmileyLevel,
        avatarLevel: globalAvatarLevel,
        animalLevel: globalAnimalLevel,
      );
      await _loadVisualSize();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تطبيق الحجم العام على الجميع ✓')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الحجم العام: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _saveMine() async {
    setState(() => saving = true);
    try {
      await ChatVisualSizeService.setMine(frameLevel: selfFrameLevel, smileyLevel: selfSmileyLevel);
      await _loadVisualSize();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ حجمك الخاص ✓')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ حجمك: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _grant(bool enabled) async {
    final uid = targetUid.text.trim();
    if (uid.isEmpty) return;
    setState(() => saving = true);
    try {
      await ChatVisualSizeService.setAuthority(userId: uid, enabled: enabled);
      await _loadVisualSize();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(enabled ? 'تم منح صلاحية التحكم العليا ✓' : 'تم سحب الصلاحية ✓')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تغيير الصلاحية: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _saveTarget() async {
    final uid = targetUid.text.trim();
    if (uid.isEmpty) return;
    setState(() => saving = true);
    try {
      await ChatVisualSizeService.setUser(
        userId: uid,
        frameLevel: targetFrameLevel,
        smileyLevel: targetSmileyLevel,
        avatarLevel: targetAvatarLevel,
        animalLevel: targetAnimalLevel,
      );
      await _loadVisualSize();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تطبيق الحجم على العضو المحدد ✓')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تطبيق الحجم: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات Chat / D3 — التحكم البصري')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('حجم الإطار والسمايل المتحرك', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),

        const SizedBox(height: 12),
        if (sizeLoading) const Center(child: CircularProgressIndicator()),
        if (!sizeLoading && isOwner) ...[
          _visualCard(title: 'حجم الإطار العام', subtitle: 'يطبّق على جميع الأعضاء ما لم يوجد استثناء شخصي.', value: globalFrameLevel, onChanged: (v) => setState(() => globalFrameLevel = v)),
          _visualCard(title: 'حجم السمايل المتحرك العام', subtitle: 'حجم GIF/السمايل داخل رسائل الغرفة.', value: globalSmileyLevel, onChanged: (v) => setState(() => globalSmileyLevel = v)),
          _visualCard(title: 'حجم الصورة الشخصية العام', subtitle: 'حجم صورة العضو داخل رسائل الغرفة.', value: globalAvatarLevel, onChanged: (v) => setState(() => globalAvatarLevel = v)),
          _visualCard(title: 'حجم شارة الحيوان العام', subtitle: 'حجم الحيوان المتحرك فوق قالب الاسم.', value: globalAnimalLevel, onChanged: (v) => setState(() => globalAnimalLevel = v)),
          FilledButton.icon(onPressed: saving ? null : _saveGlobal, icon: const Icon(Icons.public), label: const Text('تطبيق الحجم العام على الجميع')),
          const SizedBox(height: 18),
          const Divider(),
          const Text('التحكم بعضو محدد', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('استخدم UUID العضو. المالك وحده يستطيع تعيين استثناء لشخص آخر.', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 10),
          TextField(controller: targetUid, decoration: const InputDecoration(labelText: 'UUID العضو')),
          const SizedBox(height: 10),
          _visualCard(title: 'إطار العضو المحدد', subtitle: 'استثناء شخصي لهذا العضو.', value: targetFrameLevel, onChanged: (v) => setState(() => targetFrameLevel = v)),
          _visualCard(title: 'سمايل العضو المحدد', subtitle: 'استثناء شخصي لهذا العضو.', value: targetSmileyLevel, onChanged: (v) => setState(() => targetSmileyLevel = v)),
          _visualCard(title: 'صورة العضو المحدد', subtitle: 'حجم الصورة الشخصية لهذا العضو وحده.', value: targetAvatarLevel, onChanged: (v) => setState(() => targetAvatarLevel = v)),
          _visualCard(title: 'حيوان العضو المحدد', subtitle: 'حجم شارة الحيوان لهذا العضو وحده.', value: targetAnimalLevel, onChanged: (v) => setState(() => targetAnimalLevel = v)),
          FilledButton.icon(onPressed: saving ? null : _saveTarget, icon: const Icon(Icons.person), label: const Text('تطبيق للعضو المحدد')),
          const SizedBox(height: 18),
          const Text('منح الصلاحية العليا', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('العضو الممنوح يستطيع التحكم بحجمه لنفسه فقط.', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: saving ? null : () => _grant(true), icon: const Icon(Icons.admin_panel_settings), label: const Text('منح'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: saving ? null : () => _grant(false), icon: const Icon(Icons.remove_moderator), label: const Text('سحب'))),
          ]),
          const SizedBox(height: 10),
          for (final a in authorities)
            ListTile(title: Text('${a['display_name'] ?? a['username'] ?? 'عضو'}'), subtitle: Text('${a['user_id']}')),
        ],
        if (!sizeLoading && !isOwner && canManageSelf) ...[
          const SizedBox(height: 4),
          _visualCard(title: 'حجم إطارك', subtitle: 'صلاحية عليا: التعديل هنا يخص حسابك فقط.', value: selfFrameLevel, onChanged: (v) => setState(() => selfFrameLevel = v)),
          _visualCard(title: 'حجم سمايلك المتحرك', subtitle: 'صلاحية عليا: التعديل هنا يخص حسابك فقط.', value: selfSmileyLevel, onChanged: (v) => setState(() => selfSmileyLevel = v)),
          FilledButton.icon(onPressed: saving ? null : _saveMine, icon: const Icon(Icons.save), label: const Text('حفظ حجمي')),
        ],
        if (!sizeLoading && !isOwner && !canManageSelf)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد لديك صلاحية للتحكم بحجم الإطار أو السمايل.', style: TextStyle(color: Colors.white70)))),
        const Divider(height: 36),
        const Text('إعدادات الرد والاقتباس 3D', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        SwitchListTile(value: enabled, onChanged: saving ? null : (v) => setState(() => enabled = v), title: const Text('تفعيل الرد والاقتباس 3D')),
        TextField(controller: reply, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حد Reply 3D اليومي')),
        const SizedBox(height: 12),
        TextField(controller: quote, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حد Quote 3D اليومي')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: timezone,
          items: const [
            DropdownMenuItem(value: 'UTC', child: Text('UTC')),
            DropdownMenuItem(value: 'Asia/Damascus', child: Text('Asia/Damascus')),
            DropdownMenuItem(value: 'America/Chicago', child: Text('America/Chicago')),
          ],
          onChanged: saving ? null : (v) => setState(() => timezone = v ?? timezone),
          decoration: const InputDecoration(labelText: 'منطقة إعادة ضبط اليوم'),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'جارٍ الحفظ...' : 'حفظ خادمي')),
      ]),
    );
  }
}
