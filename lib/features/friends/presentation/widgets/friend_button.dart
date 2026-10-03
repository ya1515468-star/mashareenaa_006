import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/friend_request_entity.dart';
import '../providers/friend_provider.dart';

/// يعرض حالة الصداقة الفعلية ويتصرف وفقها: "إضافة صديق" إن لم يوجد
/// طلب، "معلّق" إن أرسلتُ أنا الطلب، "قبول/رفض" إن أُرسل لي، أو
/// "أصدقاء ✓" مع خيار إزالة إن كانت العلاقة مقبولة بالفعل.
class FriendButton extends ConsumerWidget {
  final String myUid;
  final String targetUid;

  const FriendButton({super.key, required this.myUid, required this.targetUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relationshipAsync =
        ref.watch(friendRelationshipProvider((uidA: myUid, uidB: targetUid)));
    final relationship = relationshipAsync.valueOrNull;

    if (relationship == null) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('إضافة صديق'),
        onPressed: () => ref
            .read(friendControllerProvider.notifier)
            .sendRequest(fromUid: myUid, toUid: targetUid),
      );
    }

    switch (relationship.status) {
      case FriendRequestStatus.accepted:
        return OutlinedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('أصدقاء'),
          onPressed: () => ref
              .read(friendControllerProvider.notifier)
              .removeFriend(uidA: myUid, uidB: targetUid),
        );
      case FriendRequestStatus.pending:
        if (relationship.fromUid == myUid) {
          return const OutlinedButton(
              onPressed: null, child: Text('طلب معلّق'));
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => ref
                  .read(friendControllerProvider.notifier)
                  .respond(relationship, accept: true),
              child: const Text('قبول'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => ref
                  .read(friendControllerProvider.notifier)
                  .respond(relationship, accept: false),
              child: const Text('رفض'),
            ),
          ],
        );
      case FriendRequestStatus.rejected:
        return OutlinedButton.icon(
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('إضافة صديق'),
          onPressed: () => ref
              .read(friendControllerProvider.notifier)
              .sendRequest(fromUid: myUid, toUid: targetUid),
        );
    }
  }
}
