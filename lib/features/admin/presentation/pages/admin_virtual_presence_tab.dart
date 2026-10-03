import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminVirtualPresenceTab extends StatefulWidget {
  const AdminVirtualPresenceTab({super.key});
  @override
  State<AdminVirtualPresenceTab> createState() =>
      _AdminVirtualPresenceTabState();
}

class _AdminVirtualPresenceTabState extends State<AdminVirtualPresenceTab> {
  final _count = TextEditingController(text: '50');
  double _femaleRatio = 70;
  bool _busy = false;

  Future<List<Map<String, dynamic>>> _load() async {
    final data = await Supabase.instance.client
        .from('platform_virtual_members')
        .select(
            'id,display_name,gender,avatar_url,is_enabled,is_online,city,profession')
        .order('id');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _regenerate() async {
    final count = int.tryParse(_count.text.trim()) ?? 50;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc('configure_virtual_members', params: {
        'p_count': count,
        'p_female_ratio': _femaleRatio.round(),
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تحديث الحضور الافتراضي: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> row, bool value) async {
    try {
      await Supabase.instance.client.rpc('set_virtual_member_state', params: {
        'p_member_id': row['id'],
        'p_enabled': value,
        'p_online': value,
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر تغيير الحالة: $e')));
      }
    }
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('الحضور الافتراضي المعلن',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _count,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'عدد الحسابات (0-100)'))),
              const SizedBox(width: 12),
              FilledButton.icon(
                  onPressed: _busy ? null : _regenerate,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(_busy ? 'جارٍ...' : 'توليد')),
            ]),
            const SizedBox(height: 10),
            Text('نسبة الإناث: ${_femaleRatio.round()}%'),
            Slider(
                value: _femaleRatio,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (v) => setState(() => _femaleRatio = v)),
            const Divider(height: 28),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator()),
            ...rows.map((row) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundImage:
                            NetworkImage(row['avatar_url'].toString())),
                    title: Text(row['display_name'].toString()),
                    subtitle: Text(
                        '${row['gender'] == 'female' ? 'أنثى' : 'ذكر'} • ${row['profession']} • ${row['city']} • افتراضي'),
                    trailing: Switch(
                        value: row['is_enabled'] == true &&
                            row['is_online'] == true,
                        onChanged: (v) => _toggle(row, v)),
                  ),
                )),
          ],
        );
      },
    );
  }
}
