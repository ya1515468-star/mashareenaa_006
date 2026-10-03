import 'package:equatable/equatable.dart';

/// أنواع الرسائل المدعومة — مطابقة لمواصفة نظام الدردشة الكامل.
/// الأنواع media (gif/image/video/audio/file) وbusiness
/// (product/project/quote/invoice/order) تُنشأ من طبقات أعلى (مرفقات
/// Supabase Storage، بطاقات المنتج/المشروع) وتُخزَّن هنا كنوع + محتوى JSON
/// خفيف في [ChatMessageEntity.metadata].
enum MessageType {
  text,
  emoji,
  gif,
  image,
  video,
  audio,
  file,
  product,
  project,
  quote,
  invoice,
  order,
  call,
  gift,
  system,
}

extension MessageTypeX on MessageType {
  String get wire => name;

  static MessageType fromWire(String? s) => MessageType.values
      .firstWhere((e) => e.wire == s, orElse: () => MessageType.text);

  bool get isMedia => [
        MessageType.gif,
        MessageType.image,
        MessageType.video,
        MessageType.audio,
        MessageType.file,
      ].contains(this);

  bool get isBusinessCard => [
        MessageType.product,
        MessageType.project,
        MessageType.quote,
        MessageType.invoice,
        MessageType.order,
      ].contains(this);
}

/// حالة تسليم الرسالة.
enum MessageStatus { sending, sent, delivered, seen, failed, edited, deleted }

extension MessageStatusX on MessageStatus {
  String get wire => name;

  static MessageStatus fromWire(String? s) => MessageStatus.values
      .firstWhere((e) => e.wire == s, orElse: () => MessageStatus.sent);
}

class ChatMessageEntity extends Equatable {
  final String id;
  final String threadId;
  final String senderUid;
  final MessageType type;
  final String text;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? mediaDurationSeconds;
  final bool isRead;
  final MessageStatus status;
  final DateTime createdAt;

  final String? replyToId;
  final String? replyToPreview;
  final String? replyToSenderUid;

  final Map<String, List<String>> reactions;
  final bool isPinned;
  final List<String> deletedForUids;
  final DateTime? editedAt;
  final Map<String, dynamic>? metadata;

  const ChatMessageEntity({
    required this.id,
    required this.threadId,
    required this.senderUid,
    required this.type,
    required this.text,
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaDurationSeconds,
    required this.isRead,
    this.status = MessageStatus.sent,
    required this.createdAt,
    this.replyToId,
    this.replyToPreview,
    this.replyToSenderUid,
    this.reactions = const {},
    this.isPinned = false,
    this.deletedForUids = const [],
    this.editedAt,
    this.metadata,
  });

  bool isDeletedFor(String uid) =>
      status == MessageStatus.deleted || deletedForUids.contains(uid);

  bool get isEdited => editedAt != null;

  int reactionCountFor(String emoji) => reactions[emoji]?.length ?? 0;

  bool hasUserReacted(String emoji, String uid) =>
      reactions[emoji]?.contains(uid) ?? false;

  @override
  List<Object?> get props => [
        id,
        threadId,
        senderUid,
        type,
        text,
        mediaUrl,
        thumbnailUrl,
        mediaDurationSeconds,
        isRead,
        status,
        createdAt,
        replyToId,
        replyToPreview,
        replyToSenderUid,
        reactions,
        isPinned,
        deletedForUids,
        editedAt,
        metadata,
      ];
}
