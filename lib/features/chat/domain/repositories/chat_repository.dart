import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/chat_message_entity.dart';
import '../entities/chat_thread_entity.dart';

abstract class ChatRepository {
  Stream<List<ChatThreadEntity>> watchThreads(String uid);

  Stream<List<ChatMessageEntity>> watchMessages(String threadId);

  Future<Either<Failure, void>> sendMessage({
    required String fromUid,
    required String toUid,
    required String text,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? thumbnailUrl,
    int? mediaDurationSeconds,
    String? replyToId,
    String? replyToPreview,
    String? replyToSenderUid,
    Map<String, dynamic>? metadata,
  });

  Future<Either<Failure, void>> markThreadRead(
      {required String threadId, required String uid});

  /// يعدّل نص رسالة (Edit) — يضبط editedAt، ولا يمكن تعديل رسالة
  /// لغير مرسِلها (يُتحقَّق من ذلك في الطبقة الأعلى/قواعد الأمان).
  Future<Either<Failure, void>> editMessage({
    required String threadId,
    required String messageId,
    required String newText,
  });

  /// حذف للجميع (status=deleted) أو حذف لي فقط (إضافة uid إلى
  /// deletedForUids) حسب [forEveryone].
  Future<Either<Failure, void>> deleteMessage({
    required String threadId,
    required String messageId,
    required String requesterUid,
    required bool forEveryone,
  });

  /// يبدّل تفاعل إيموجي: يضيف uid إن لم يكن قد تفاعل به من قبل،
  /// ويزيله إن كان قد تفاعل (Toggle Reaction).
  Future<Either<Failure, void>> toggleReaction({
    required String threadId,
    required String messageId,
    required String uid,
    required String emoji,
  });

  Future<Either<Failure, void>> setPinned({
    required String threadId,
    required String messageId,
    required bool pinned,
  });

  /// يُستدعى عندما يستقبل جهاز المستلم رسائل جديدة (حتى دون فتح
  /// المحادثة) لتحويل حالتها من sent إلى delivered (✓✓ رمادي).
  Future<void> markDelivered(
      {required String threadId, required List<String> messageIds});

  /// يُحدَّث بكثرة أثناء الكتابة — تُنفَّذ محليًا بـ throttle قبل
  /// الاستدعاء (راجع ChatController.onTextChanged).
  Future<void> setTyping(
      {required String threadId, required String uid, required bool isTyping});

  Stream<List<String>> watchTyping(String threadId);

  /// حضور مستخدم: متصل الآن / آخر ظهور. تُحدَّث عبر
  /// PresenceService عند دخول/خروج التطبيق، وليس من شاشة الدردشة
  /// مباشرة.
  Stream<UserPresence> watchPresence(String uid);

  Future<void> setPresence({required String uid, required bool isOnline});
}

class UserPresence {
  final bool isOnline;
  final DateTime? lastSeen;
  const UserPresence({required this.isOnline, this.lastSeen});
}
