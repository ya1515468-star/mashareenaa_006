import 'package:equatable/equatable.dart';

class BroadcastEntity extends Equatable {
  final String id;
  final String message;
  final String sentByUid;
  final DateTime createdAt;
  final List<String> targetUserIds;

  const BroadcastEntity({
    required this.id,
    required this.message,
    required this.sentByUid,
    required this.createdAt,
    this.targetUserIds = const <String>[],
  });

  bool isVisibleTo({
    required String? currentUserUid,
    required bool currentUserIsPlatformOwner,
  }) {
    if (currentUserUid == null) {
      return false;
    }

    if (currentUserIsPlatformOwner) {
      return true;
    }

    if (targetUserIds.contains(currentUserUid)) {
      return true;
    }

    return false;
  }

  @override
  List<Object?> get props => [
        id,
        message,
        sentByUid,
        createdAt,
        targetUserIds,
      ];
}
