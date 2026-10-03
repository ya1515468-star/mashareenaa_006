import '../../../../core/data/supabase_document_compat.dart';
import '../../domain/entities/broadcast_entity.dart';

class BroadcastModel extends BroadcastEntity {
  const BroadcastModel({
    required super.id,
    required super.message,
    required super.sentByUid,
    required super.createdAt,
    required super.targetUserIds,
  });

  factory BroadcastModel.fromMap(String id, Map<String, dynamic> map) {
    final rawTargetIds = map['targetUserIds'];

    final targetIds = <String>[
      if (rawTargetIds is List)
        ...rawTargetIds
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty),
    ];

    return BroadcastModel(
      id: id,
      message: map['message'] as String? ?? '',
      sentByUid: map['sentByUid'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      targetUserIds: List<String>.unmodifiable(targetIds),
    );
  }
}
