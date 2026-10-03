import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PlatformSafetyWarningsPage extends StatelessWidget {
  const PlatformSafetyWarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = Supabase.instance.client
        .from('platform_safety_warnings')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('published_at', ascending: false);
    return Scaffold(
      appBar: AppBar(title: const Text('تحذيرات الأمان المنشورة')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('تعذر تحميل التحذيرات: ${snapshot.error}'));
          }
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) {
            return const Center(child: Text('لا توجد تحذيرات منشورة حاليًا'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final row = rows[i];
              final evidence = row['evidence_url']?.toString() ?? '';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(row['title']?.toString() ?? 'تحذير',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900))),
                        ]),
                        const SizedBox(height: 8),
                        Text(row['details']?.toString() ?? ''),
                        if (evidence.isNotEmpty)
                          TextButton.icon(
                            onPressed: () async {
                              final u = Uri.tryParse(evidence);
                              if (u != null) {
                                await launchUrl(u,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.attachment_outlined),
                            label: const Text('عرض الدليل المرفق'),
                          ),
                        const SizedBox(height: 6),
                        Text('هوية الحساب: ${row['target_user_id']}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54)),
                      ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
