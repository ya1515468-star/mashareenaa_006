import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/presentation/widgets/mini_profile_popup.dart';
import '../../rbac/presentation/widgets/server_username_display.dart';
import '../../rbac/presentation/widgets/server_user_identity_badges.dart';
import '../../../core/widgets/dynamic_avatar_frame.dart';

final onlineNowProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final controller = StreamController<List<Map<String, dynamic>>>();
  var disposed = false;

  Future<void> load() async {
    try {
      // Real members only. The synthetic "virtual members" list was removed —
      // this is a production app, so the presence list must never mix
      // fabricated accounts with real ones.
      final result =
          await Supabase.instance.client.rpc('get_visible_online_users');

      if (disposed) return;

      final rows = <Map<String, dynamic>>[];
      if (result is List) {
        rows.addAll(
          result.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)),
        );
      }

      if (!disposed) {
        controller.add(rows);
      }
    } catch (error, stackTrace) {
      if (!disposed) {
        controller.addError(error, stackTrace);
      }
    }
  }

  unawaited(load());

  // Instant updates: subscribe to presence changes and refresh the moment
  // anyone joins/leaves, instead of waiting for a poll tick. The authoritative
  // filtered list still comes from the RPC (server-side visibility rules), so
  // the realtime event is only used as a "something changed" trigger — the
  // raw payload is never trusted to decide who is shown.
  final channel = Supabase.instance.client.channel('public:user_presence_live')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_presence',
      callback: (_) {
        if (!disposed) unawaited(load());
      },
    )
    ..subscribe();

  // Slow safety net only (covers a dropped socket); the realtime channel is
  // what makes it feel instant.
  final timer = Timer.periodic(const Duration(seconds: 20), (_) {
    unawaited(load());
  });

  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    unawaited(Supabase.instance.client.removeChannel(channel));
    unawaited(controller.close());
  });

  return controller.stream;
});

/// Live count of who is actually visible to THIS viewer. Derived from the same
/// server filter as the list, so the number can never disagree with the names
/// (a count that included hidden users would itself expose them).
final onlineNowCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(onlineNowProvider).valueOrNull?.length ?? 0;
});

class OnlineNowPage extends ConsumerWidget {
  /// الغرفة التي فُتحت منها القائمة. بلا roomId كانت نافذة العضو تُخفي
  /// قسم الإدارة كليًا (حظر/كتم/طرد وعكسها) حتى عن المالك والمشرفين،
  /// لأن صلاحيات الإشراف تُحسب لكل غرفة على الخادم.
  final String? roomId;
  const OnlineNowPage({super.key, this.roomId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(onlineNowProvider);
    final liveCount = async.valueOrNull?.length ?? 0;
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Text('المتواجدون الآن 🟢  ($liveCount)'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
              child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('تعذّر التحميل: $e')),
            data: (rows) {
              if (rows.isEmpty) {
                return Center(
                    child: Text('لا يوجد أعضاء متصلون حاليًا',
                        style: TextStyle(color: p.textSecondary)));
              }
              return ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final row = rows[i];
                  final uid = row['user_id']?.toString() ?? '';
                  final hidden = row['is_hidden'] == true;
                  // Name/avatar/rank come inline from the RPC, so the list
                  // renders in one round-trip instead of one profile fetch per
                  // row (the old per-row lookup is what made this feel slow).
                  final avatarUrl = row['avatar_url']?.toString() ?? '';
                  final title =
                      row['display_name']?.toString().trim().isNotEmpty == true
                          ? row['display_name'].toString()
                          : (row['username']?.toString() ?? 'عضو');
                  return ListTile(
                    leading: Stack(children: [
                      // البند ٦: الإطار نفسه الذي يظهر على صورة العضو داخل الغرفة
                      // يظهر هنا أيضًا (هوية الغرفة ذاتها)، لا دائرة عادية.
                      uid.isEmpty
                          ? CircleAvatar(
                              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl.isEmpty ? const Icon(Icons.person) : null)
                          : _OnlineFramedAvatar(uid: uid, roomId: roomId, avatarUrl: avatarUrl),
                      Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: p.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: p.background, width: 2)))),
                    ]),
                    // كان نصًا خامًا من display_name/username فقط — يتجاهل
                    // اللون والشارة واللقب والتأثيرات التي قد يملكها العضو
                    // داخل هذه الغرفة تحديدًا. نفس المكوّن المستعمل في كل
                    // مكان آخر بالتطبيق يقرأ الهوية عبر get_user_chat_identity
                    // بمعرّف الغرفة، فتطابق تمامًا ما يظهر داخلها.
                    title: uid.isEmpty
                        ? Text(title)
                        : ServerUsernameDisplay(
                            uid: uid,
                            roomId: roomId,
                            fallbackName: title,
                            showBadges: true,
                            compactBadges: true,
                          ),
                    subtitle: Text(
                        hidden
                            ? 'متصل الآن • مخفي'
                            : 'متصل الآن',
                        style: TextStyle(color: p.textSecondary)),
                    onTap: uid.isEmpty
                        ? null
                        // Opens the exact same mini-profile popup the room
                        // uses (with its full admin actions), instead of
                        // pushing a separate full-page profile.
                        : () => MiniProfilePopup.show(context, uid, roomId: roomId),
                  );
                },
              );
            },
          )),
        ],
      ),
    );
  }
}


/// صورة عضو متصل بإطاره كما تُقرأ هويته داخل الغرفة نفسها.
class _OnlineFramedAvatar extends ConsumerWidget {
  final String uid;
  final String? roomId;
  final String avatarUrl;
  const _OnlineFramedAvatar({required this.uid, required this.roomId, required this.avatarUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = (roomId == null
                ? ref.watch(serverUserIdentityProvider(uid))
                : ref.watch(serverUserIdentityInRoomProvider((uid: uid, roomId: roomId))))
            .valueOrNull ??
        const <String, dynamic>{};
    final frameKey = identity['avatar_frame_key']?.toString();
    final avatar = CircleAvatar(
      radius: 20,
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child: avatarUrl.isEmpty ? const Icon(Icons.person) : null,
    );
    if (frameKey == null || frameKey.isEmpty) return avatar;
    return DynamicAvatarFrame(frameKey: frameKey, userId: uid, radius: 20, child: avatar);
  }
}
