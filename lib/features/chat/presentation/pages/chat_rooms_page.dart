import 'package:flutter/material.dart';
import '../../../../core/error/failure_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_lobby_page.dart';
import '../../../../core/widgets/served_ad_slot.dart';

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
            return Center(child: Text(FailureText.of(snapshot.error, subject: 'الغرف')));
          }
          final rows = (snapshot.data ?? const [])
              .where((r) => r['is_active'] == true && r['is_public'] != false)
              .toList();
          if (rows.isEmpty) {
            return const Center(child: Text('لا توجد غرف نشطة'));
          }
          // موضع «بهو الشات وقائمة الغرف» — أكثر شاشة تُدخَل يوميًّا.
          // تردّده وفتحه وإغلاقه كلّها بيد المالك.
          final placements =
              ref.watch(adPlacementsProvider).valueOrNull ?? const {};
          final slots =
              AdInterleave(adEveryN(placements, 'chat_lobby'), rows.length);
          return ListView.separated(
            itemCount: slots.rowCount,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              if (slots.isAd(i)) {
                return const ServedAdSlot(placement: 'chat_lobby');
              }
              final r = rows[slots.itemIndex(i)];
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
