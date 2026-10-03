import '../../domain/entities/friend_request_entity.dart';

class FriendRequestModel extends FriendRequestEntity {
  const FriendRequestModel(
      {required super.id,
      required super.fromUid,
      required super.toUid,
      required super.status,
      required super.createdAt});

  factory FriendRequestModel.fromMap(String id, Map<String, dynamic> map) =>
      FriendRequestModel(
        id: id,
        fromUid:
            map['from_uid']?.toString() ?? map['fromUid']?.toString() ?? '',
        toUid: map['to_uid']?.toString() ?? map['toUid']?.toString() ?? '',
        status: FriendRequestStatusX.fromWire(map['status']?.toString()),
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}
