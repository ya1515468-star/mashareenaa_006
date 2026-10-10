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
      createdAt: _parseCreatedAt(map['createdAt']),
      targetUserIds: List<String>.unmodifiable(targetIds),
    );
  }

  /// سوبابيس (Postgres) يُعيد createdAt كنص ISO8601 دائمًا، لا كجسم
  /// Timestamp (ذاك شكل Firestore القديم فقط). كان الكود السابق يفترض
  /// النوع الثاني بـ"as Timestamp?" فيرمي استثناء "String is not a
  /// subtype of Timestamp?" في كل مرة يصل فيها بثّ حقيقي — وهذا كان
  /// الخطأ الأكثر تكرارًا في المراقبة (١٠٢ مرة، ٣٥ مستخدمًا). هذا
  /// المُحلِّل يقبل كل الأشكال المحتملة فعليًا: نص ISO8601 (الحالة
  /// الحقيقية من الخادم)، أو جسم Timestamp القديم إن وُجد من مصدر آخر،
  /// أو عدد ملي-ثانية، مع رجوع آمن للوقت الحالي عند الفشل.
  static DateTime _parseCreatedAt(dynamic raw) {
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    if (raw is Timestamp) return raw.toDate();
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return DateTime.now();
  }
}
