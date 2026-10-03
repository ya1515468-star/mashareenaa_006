import 'package:equatable/equatable.dart';

class AuditLogEntity extends Equatable {
  final String id;
  final String type;
  final String? targetUid;
  final String performedBy;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  const AuditLogEntity({
    required this.id,
    required this.type,
    this.targetUid,
    required this.performedBy,
    this.details = const {},
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, type, targetUid, performedBy, details, createdAt];
}
