import '../../domain/entities/chat_thread_entity.dart';

class ChatThreadModel extends ChatThreadEntity {
  const ChatThreadModel({
    required super.id,
    super.type,
    required super.participantUids,
    super.title,
    super.avatarUrl,
    super.lastMessageText,
    super.lastMessageSenderUid,
    super.lastMessageAt,
    super.unreadCounts,
    super.pinnedMessageIds,
    super.linkedEntityId,
    super.linkedEntityType,
    super.typingUids,
  });

  factory ChatThreadModel.fromMap(String id, Map<String, dynamic> map,
      {List<String> typingUids = const []}) {
    final rawUnread = map['unread_counts'] ?? map['unreadCounts'];
    final rawParticipants = map['participant_uids'] ?? map['participantUids'];
    final rawPinned = map['pinned_message_ids'] ?? map['pinnedMessageIds'];
    return ChatThreadModel(
      id: id,
      type: ChatThreadTypeX.fromWire((map['type'])?.toString()),
      participantUids: (rawParticipants is Iterable)
          ? rawParticipants.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      title: (map['title'])?.toString(),
      avatarUrl: (map['avatar_url'] ?? map['avatarUrl'])?.toString(),
      lastMessageText:
          (map['last_message_text'] ?? map['lastMessageText'])?.toString(),
      lastMessageSenderUid:
          (map['last_message_sender_uid'] ?? map['lastMessageSenderUid'])
              ?.toString(),
      lastMessageAt: _parseDate(map['last_message_at'] ?? map['lastMessageAt']),
      unreadCounts: rawUnread is Map
          ? rawUnread
              .map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0))
          : const {},
      pinnedMessageIds: (rawPinned is Iterable)
          ? rawPinned.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      linkedEntityId:
          (map['linked_entity_id'] ?? map['linkedEntityId'])?.toString(),
      linkedEntityType:
          (map['linked_entity_type'] ?? map['linkedEntityType'])?.toString(),
      typingUids: typingUids,
    );
  }

  static DateTime? _parseDate(dynamic value) => value is DateTime
      ? value
      : value is String
          ? DateTime.tryParse(value)
          : null;
}
