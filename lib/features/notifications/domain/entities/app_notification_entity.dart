import 'package:equatable/equatable.dart';

enum AppNotificationType {
  message,
  like,
  comment,
  follow,
  friendRequest,
  friendAccepted,
  system,
  mention,
  chatReply,
  friendRejected,
  callIncoming,
  callEnded,
  report
}

extension AppNotificationTypeX on AppNotificationType {
  String get wire => name;

  static AppNotificationType fromWire(String? s) {
    switch (s) {
      case 'chat_reply':
        return AppNotificationType.chatReply;
      case 'mention':
        return AppNotificationType.mention;
      case 'friend_rejected':
        return AppNotificationType.friendRejected;
      case 'friend_request':
        return AppNotificationType.friendRequest;
      case 'friend_accepted':
        return AppNotificationType.friendAccepted;
      case 'call_incoming':
        return AppNotificationType.callIncoming;
      case 'call_ended':
        return AppNotificationType.callEnded;
      case 'report':
        return AppNotificationType.report;
      case 'gift':
        return AppNotificationType.message;
      default:
        return AppNotificationType.values.firstWhere((e) => e.wire == s,
            orElse: () => AppNotificationType.system);
    }
  }
}

/// إشعار داخل التطبيق. [relatedId] يشير حسب النوع إلى: معرّف
/// المحادثة (message)، معرّف المنشور (like/comment)، أو uid
/// المتابِع (follow).
class AppNotificationEntity extends Equatable {
  final String id;
  final String uid;
  final AppNotificationType type;
  final String title;
  final String body;
  final String? relatedId;
  final String? actorUid;
  final bool isRead;
  final DateTime createdAt;

  const AppNotificationEntity({
    required this.id,
    required this.uid,
    required this.type,
    required this.title,
    required this.body,
    this.relatedId,
    this.actorUid,
    required this.isRead,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, uid, type, title, body, relatedId, actorUid, isRead, createdAt];
}
