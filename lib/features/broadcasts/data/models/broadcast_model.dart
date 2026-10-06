import '../../../../core/data/supabase_document_compat.dart';
import '../../domain/entities/broadcast_entity.dart';

DateTime _parseBroadcastCreatedAt(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw.toLocal();
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.toLocal();
  }
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      raw.toInt(),
      isUtc: true,
    ).toLocal();
  }
  return DateTime.now();
}

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
      createdAt: _parseBroadcastCreatedAt(map['createdAt']),
      targetUserIds: List<String>.unmodifiable(targetIds),
    );
  }
}
