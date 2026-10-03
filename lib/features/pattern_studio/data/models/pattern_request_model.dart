import '../../../../core/data/supabase_document_compat.dart';
import '../../domain/entities/pattern_enums.dart';
import '../../domain/entities/pattern_request_entity.dart';

class PatternRequestModel extends PatternRequestEntity {
  const PatternRequestModel({
    required super.id,
    required super.uid,
    required super.sourceImageUrl,
    required super.mannequinType,
    super.notes,
    super.status,
    super.resultImageUrl,
    super.resultVideoUrl,
    super.reviewerNote,
    required super.createdAt,
  });

  factory PatternRequestModel.fromMap(String id, Map<String, dynamic> map) {
    return PatternRequestModel(
      id: id,
      uid: map['uid'] as String? ?? '',
      sourceImageUrl: map['sourceImageUrl'] as String? ?? '',
      mannequinType: MannequinTypeX.fromWire(map['mannequinType'] as String?),
      notes: map['notes'] as String?,
      status: PatternRequestStatusX.fromWire(map['status'] as String?),
      resultImageUrl: map['resultImageUrl'] as String?,
      resultVideoUrl: map['resultVideoUrl'] as String?,
      reviewerNote: map['reviewerNote'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'sourceImageUrl': sourceImageUrl,
      'mannequinType': mannequinType.wire,
      'notes': notes,
      'status': status.wire,
      'resultImageUrl': resultImageUrl,
      'resultVideoUrl': resultVideoUrl,
      'reviewerNote': reviewerNote,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
