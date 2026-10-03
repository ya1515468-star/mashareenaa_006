import 'package:equatable/equatable.dart';
import 'pattern_enums.dart';

/// طلب باترون. [resultImageUrl]/[resultVideoUrl] يبقيان فارغين حتى
/// يرفع مصمم بشري (عبر لوحة الإدارة) النتيجة الفعلية يدويًا — لا
/// توجد معالجة تلقائية لأي صورة في هذا الإصدار.
class PatternRequestEntity extends Equatable {
  final String id;
  final String uid;
  final String sourceImageUrl;
  final MannequinType mannequinType;
  final String? notes;
  final PatternRequestStatus status;
  final String? resultImageUrl;
  final String? resultVideoUrl;
  final String? reviewerNote;
  final DateTime createdAt;

  const PatternRequestEntity({
    required this.id,
    required this.uid,
    required this.sourceImageUrl,
    required this.mannequinType,
    this.notes,
    this.status = PatternRequestStatus.queued,
    this.resultImageUrl,
    this.resultVideoUrl,
    this.reviewerNote,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        uid,
        sourceImageUrl,
        mannequinType,
        notes,
        status,
        resultImageUrl,
        resultVideoUrl,
        reviewerNote,
        createdAt,
      ];
}
