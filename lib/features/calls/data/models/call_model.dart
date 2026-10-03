import '../../../../core/data/supabase_document_compat.dart';
import '../../domain/entities/call_entity.dart';

class CallModel extends CallEntity {
  const CallModel({
    required super.id,
    required super.callerUid,
    required super.calleeUid,
    required super.type,
    required super.status,
    required super.createdAt,
  });

  factory CallModel.fromMap(String id, Map<String, dynamic> map) {
    return CallModel(
      id: id,
      callerUid: map['callerUid'] as String? ?? '',
      calleeUid: map['calleeUid'] as String? ?? '',
      type: CallTypeX.fromWire(map['type'] as String?),
      status: CallStatusX.fromWire(map['status'] as String?),
      createdAt: _readTimestamp(map['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _readTimestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is Map && raw['__timestamp'] is String) {
      return DateTime.tryParse(raw['__timestamp'] as String);
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'callerUid': callerUid,
      'calleeUid': calleeUid,
      'participants': [callerUid, calleeUid],
      'type': type.wire,
      'status': status.wire,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
