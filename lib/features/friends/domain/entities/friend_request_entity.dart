import 'package:equatable/equatable.dart';

enum FriendRequestStatus { pending, accepted, rejected }

extension FriendRequestStatusX on FriendRequestStatus {
  String get wire => name;
  static FriendRequestStatus fromWire(String? s) =>
      FriendRequestStatus.values.firstWhere(
        (e) => e.wire == s,
        orElse: () => FriendRequestStatus.pending,
      );
}

/// طلب صداقة بين مستخدمين. المعرّف [id] يُبنى من دمج الـ uid الأصغر
/// والأكبر أبجديًا (مطابقًا لنمط ChatThreadEntity) بحيث لا يمكن
/// وجود أكثر من طلب واحد نشط بين نفس الطرفين مهما بدأه أيّهما.
class FriendRequestEntity extends Equatable {
  final String id;
  final String fromUid;
  final String toUid;
  final FriendRequestStatus status;
  final DateTime createdAt;

  const FriendRequestEntity({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    required this.createdAt,
  });

  static String buildId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  String otherParticipant(String myUid) => fromUid == myUid ? toUid : fromUid;

  @override
  List<Object?> get props => [id, fromUid, toUid, status, createdAt];
}
