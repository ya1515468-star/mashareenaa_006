import '../../domain/entities/chat_message_entity.dart';

class ChatMessageModel extends ChatMessageEntity {
  const ChatMessageModel({
    required super.id,
    required super.threadId,
    required super.senderUid,
    required super.type,
    required super.text,
    super.mediaUrl,
    super.thumbnailUrl,
    super.mediaDurationSeconds,
    required super.isRead,
    super.status,
    required super.createdAt,
    super.replyToId,
    super.replyToPreview,
    super.replyToSenderUid,
    super.reactions,
    super.isPinned,
    super.deletedForUids,
    super.editedAt,
    super.metadata,
  });

  factory ChatMessageModel.fromMap(
      String id, String threadId, Map<String, dynamic> map) {
    final rawReactions = map['reactions'] as Map? ?? const {};
    final rawDeleted = map['deleted_for_uids'] ?? map['deletedForUids'];

    return ChatMessageModel(
      id: id,
      threadId: threadId,
      senderUid: (map['sender_uid'] ??
                  map['senderUid'] ??
                  map['user_id'] ??
                  map['userId'])
              ?.toString() ??
          '',
      type: MessageTypeX.fromWire(
        (map['type'] ?? map['kind'])?.toString(),
      ),
      text: (map['text'] ?? map['message'] ?? map['body'])?.toString() ?? '',
      mediaUrl: (map['media_url'] ??
              map['mediaUrl'] ??
              map['attachment_url'] ??
              map['attachmentUrl'])
          ?.toString(),
      thumbnailUrl: (map['thumbnail_url'] ?? map['thumbnailUrl'])?.toString(),
      mediaDurationSeconds:
          (map['media_duration_seconds'] ?? map['mediaDurationSeconds']) is num
              ? ((map['media_duration_seconds'] ?? map['mediaDurationSeconds'])
                      as num)
                  .toInt()
              : null,
      isRead: map['is_read'] == true || map['isRead'] == true,
      status: MessageStatusX.fromWire((map['status'])?.toString()),
      createdAt: _parseDate(
            map['created_at'] ?? map['createdAt'],
          ) ??
          DateTime.now(),
      replyToId: (map['reply_to_id'] ?? map['replyToId'])?.toString(),
      replyToPreview:
          (map['reply_to_preview'] ?? map['replyToPreview'])?.toString(),
      replyToSenderUid:
          (map['reply_to_sender_uid'] ?? map['replyToSenderUid'])?.toString(),
      reactions: rawReactions.map(
        (k, v) => MapEntry(
          k.toString(),
          (v is Iterable)
              ? v.map((e) => e.toString()).toList(growable: false)
              : const <String>[],
        ),
      ),
      isPinned: map['is_pinned'] == true || map['isPinned'] == true,
      deletedForUids: rawDeleted is Iterable
          ? rawDeleted.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      editedAt: _parseDate(
        map['edited_at'] ?? map['editedAt'],
      ),
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }

  static DateTime? _parseDate(dynamic value) => value is DateTime
      ? value
      : value is String
          ? DateTime.tryParse(value)
          : null;
}
