import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_lobby_page.dart';

class ChatRoomsPage extends ConsumerWidget {
  const ChatRoomsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = Supabase.instance.client
        .from('chat_rooms')
        .stream(primaryKey: ['id']).order('created_at');
    return Scaffold(
      appBar: AppBar(title: const Text('الغرف')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('تعذر تحميل الغرف: ${snapshot.error}'));
          }
          final rows = (snapshot.data ?? const [])
              .where((r) => r['is_active'] == true && r['is_public'] != false)
              .toList();
          if (rows.isEmpty) {
            return const Center(child: Text('لا توجد غرف نشطة'));
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = rows[i];
              final roomId = r['id']?.toString();
              if (roomId == null || roomId.isEmpty) {
                return const SizedBox.shrink();
              }
              return ListTile(
                leading: const CircleAvatar(
                    child: Icon(Icons.meeting_room_outlined)),
                title: Text((r['name'] ?? 'غرفة').toString()),
                subtitle: Text((r['description'] ?? '').toString(),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Icon(
                    r['is_public'] == true ? Icons.public : Icons.lock_outline),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatLobbyPage(roomId: roomId))),
              );
            },
          );
        },
      ),
    );
  }
}
