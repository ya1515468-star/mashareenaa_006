import 'package:equatable/equatable.dart';

/// نوع المحادثة: ثنائية، مجموعة، أو مرتبطة بمشروع/طلب/منتج (Project
/// Chat) — والتي تحمل معرّف الكيان المرتبط في [linkedEntityId].
enum ChatThreadType { direct, group, project }

extension ChatThreadTypeX on ChatThreadType {
  String get wire => name;
  static ChatThreadType fromWire(String? s) => ChatThreadType.values
      .firstWhere((e) => e.wire == s, orElse: () => ChatThreadType.direct);
}

/// محادثة (ثنائية أو مجموعة أو مرتبطة بمشروع). المعرّف [id] للمحادثات
/// الثنائية يُبنى من دمج الـ uid الأصغر والأكبر أبجديًا (uidA_uidB)
/// بحيث تكون هناك محادثة واحدة فقط بين أي مستخدمين — لا تكرار ممكن.
/// محادثات المجموعات/المشاريع تحصل على معرّف طبقة بيانات Supabase تلقائي.
class ChatThreadEntity extends Equatable {
  final String id;
  final ChatThreadType type;
  final List<String> participantUids;
  final String? title;
  final String? avatarUrl;
  final String? lastMessageText;
  final String? lastMessageSenderUid;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCounts;
  final List<String> pinnedMessageIds;

  /// معرّف الكيان المرتبط (Project ID / Order ID / Product ID) عندما
  /// يكون [type] = project.
  final String? linkedEntityId;
  final String? linkedEntityType;

  /// uids الأعضاء الذين يكتبون حاليًا (Typing Indicator) — يُقرأ من
  /// حقل منفصل خفيف الوزن يُحدَّث بكثرة، وليس من مستند المحادثة
  /// الرئيسي، لتفادي إعادة رسم قائمة المحادثات كاملة عند كل ضغطة
  /// زر (راجع typing_status في chat_remote_data_source).
  final List<String> typingUids;

  const ChatThreadEntity({
    required this.id,
    this.type = ChatThreadType.direct,
    required this.participantUids,
    this.title,
    this.avatarUrl,
    this.lastMessageText,
    this.lastMessageSenderUid,
    this.lastMessageAt,
    this.unreadCounts = const {},
    this.pinnedMessageIds = const [],
    this.linkedEntityId,
    this.linkedEntityType,
    this.typingUids = const [],
  });

  static String buildId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  String otherParticipant(String myUid) =>
      participantUids.firstWhere((u) => u != myUid, orElse: () => myUid);

  int unreadFor(String uid) => unreadCounts[uid] ?? 0;

  bool isTyping(String uid) => typingUids.contains(uid);

  @override
  List<Object?> get props => [
        id,
        type,
        participantUids,
        title,
        avatarUrl,
        lastMessageText,
        lastMessageSenderUid,
        lastMessageAt,
        unreadCounts,
        pinnedMessageIds,
        linkedEntityId,
        linkedEntityType,
        typingUids,
      ];
}
