import 'package:equatable/equatable.dart';

enum ReportTargetType { post, comment, user, chatMessage }

extension ReportTargetTypeX on ReportTargetType {
  String get wire => name;
  static ReportTargetType fromWire(String? s) => ReportTargetType.values
      .firstWhere((e) => e.wire == s, orElse: () => ReportTargetType.post);
}

enum ReportStatus { pending, resolved, dismissed }

extension ReportStatusX on ReportStatus {
  String get wire => name;
  static ReportStatus fromWire(String? s) => ReportStatus.values
      .firstWhere((e) => e.wire == s, orElse: () => ReportStatus.pending);
}

class ReportEntity extends Equatable {
  final String id;
  final String reporterUid;
  final ReportTargetType targetType;
  final String targetId;
  final String reason;
  final ReportStatus status;
  final String? resolvedBy;
  final DateTime createdAt;

  /// رابط صورة التوثيق المرفَقة مع البلاغ (اختيارية) — "زر الإبلاغ
  /// ... مع طلب صورة للتوثيق والابلاغ" من مواصفة التعديلات.
  final String? evidenceUrl;

  const ReportEntity({
    required this.id,
    required this.reporterUid,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.status = ReportStatus.pending,
    this.resolvedBy,
    required this.createdAt,
    this.evidenceUrl,
  });

  @override
  List<Object?> get props => [
        id,
        reporterUid,
        targetType,
        targetId,
        reason,
        status,
        resolvedBy,
        createdAt,
        evidenceUrl,
      ];
}
