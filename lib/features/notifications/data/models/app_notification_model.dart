import '../../domain/entities/app_notification_entity.dart';

class AppNotificationModel extends AppNotificationEntity {
  const AppNotificationModel(
      {required super.id,
      required super.uid,
      required super.type,
      required super.title,
      required super.body,
      super.relatedId,
      super.actorUid,
      required super.isRead,
      required super.createdAt});
  factory AppNotificationModel.fromMap(String id, Map<String, dynamic> m) =>
      AppNotificationModel(
          id: id,
          uid: m['uid']?.toString() ?? '',
          type: AppNotificationTypeX.fromWire(m['type']?.toString()),
          title: m['title']?.toString() ?? '',
          body: m['body']?.toString() ?? '',
          relatedId: m['related_id']?.toString(),
          actorUid: m['actor_uid']?.toString(),
          isRead: m['is_read'] == true,
          createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
              DateTime.now());
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'type': type.wire,
        'title': title,
        'body': body,
        'related_id': relatedId,
        'actor_uid': actorUid,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String()
      };
}
