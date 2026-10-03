import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPlatformRequestsTab extends StatefulWidget {
  const AdminPlatformRequestsTab({super.key});
  @override
  State<AdminPlatformRequestsTab> createState() =>
      _AdminPlatformRequestsTabState();
}

class _AdminPlatformRequestsTabState extends State<AdminPlatformRequestsTab> {
  Future<List<Map<String, dynamic>>> _load() async {
    final data = await Supabase.instance.client.rpc(
        'get_platform_broadcast_requests',
        params: {'p_status': 'pending'});
    return data is List
        ? List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map)))
        : const [];
  }

  Future<void> _review(String id, String status) async {
    await Supabase.instance.client
        .rpc('review_platform_broadcast_request', params: {
      'p_request_id': id,
      'p_status': status,
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('تعذر تحميل طلبات البث: ${snapshot.error}'));
        }
        if (rows.isEmpty) {
          return const Center(
              child: Text('لا توجد طلبات بث أو أفكار قيد المراجعة.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = rows[i];
            final type = r['request_type'] == 'live' ? 'بث مباشر' : 'فكرة';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Chip(label: Text(type)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('الطالب: ${r['requester_uid']}'))
                      ]),
                      const SizedBox(height: 8),
                      Text(r['body']?.toString() ?? '',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      if (r['room_id'] != null) ...[
                        const SizedBox(height: 6),
                        Text('الغرفة: ${r['room_id']}',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      Row(children: [
                        FilledButton.icon(
                            onPressed: () =>
                                _review(r['id'].toString(), 'approved'),
                            icon: const Icon(Icons.check),
                            label: const Text('اعتماد')),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                            onPressed: () =>
                                _review(r['id'].toString(), 'rejected'),
                            icon: const Icon(Icons.close),
                            label: const Text('رفض')),
                      ]),
                    ]),
              ),
            );
          },
        );
      },
    );
  }
}
