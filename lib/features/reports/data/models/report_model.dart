import '../../../../core/data/supabase_document_compat.dart';
import '../../domain/entities/report_entity.dart';

class ReportModel extends ReportEntity {
  const ReportModel({
    required super.id,
    required super.reporterUid,
    required super.targetType,
    required super.targetId,
    required super.reason,
    super.status,
    super.resolvedBy,
    required super.createdAt,
    super.evidenceUrl,
  });

  factory ReportModel.fromMap(String id, Map<String, dynamic> map) {
    return ReportModel(
      id: id,
      reporterUid: map['reporterUid'] as String? ?? '',
      targetType: ReportTargetTypeX.fromWire(map['targetType'] as String?),
      targetId: map['targetId'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      status: ReportStatusX.fromWire(map['status'] as String?),
      resolvedBy: map['resolvedBy'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      evidenceUrl: map['evidenceUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reporterUid': reporterUid,
      'targetType': targetType.wire,
      'targetId': targetId,
      'reason': reason,
      'status': status.wire,
      'resolvedBy': resolvedBy,
      'createdAt': FieldValue.serverTimestamp(),
      'evidenceUrl': evidenceUrl,
    };
  }
}
