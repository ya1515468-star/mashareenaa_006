import 'package:equatable/equatable.dart';
import '../../../wallet/domain/entities/currency.dart';

enum MannequinType { boys, girls, men, women }

extension MannequinTypeX on MannequinType {
  String get wire => name;

  static MannequinType fromWire(String? s) => MannequinType.values
      .firstWhere((e) => e.wire == s, orElse: () => MannequinType.men);

  String get label {
    switch (this) {
      case MannequinType.boys:
        return 'أولاد';
      case MannequinType.girls:
        return 'بنات';
      case MannequinType.men:
        return 'رجال';
      case MannequinType.women:
        return 'نساء';
    }
  }
}

enum PatternRequestStatus {
  pendingPayment,
  queued,
  inReview,
  completed,
  rejected
}

extension PatternRequestStatusX on PatternRequestStatus {
  String get wire => name;

  static PatternRequestStatus fromWire(String? s) =>
      PatternRequestStatus.values.firstWhere(
        (e) => e.wire == s,
        orElse: () => PatternRequestStatus.queued,
      );

  String get label {
    switch (this) {
      case PatternRequestStatus.pendingPayment:
        return 'بانتظار الدفع';
      case PatternRequestStatus.queued:
        return 'في طابور المراجعة';
      case PatternRequestStatus.inReview:
        return 'قيد المعالجة من المصمم';
      case PatternRequestStatus.completed:
        return 'مكتمل';
      case PatternRequestStatus.rejected:
        return 'مرفوض';
    }
  }
}

/// إعدادات الميزة — يتحكم بها مالك المنصة بالكامل (السعر والتفعيل)
/// من لوحة الإدارة، وتُخزَّن في مستند تهيئة عام واحد بدل أن تكون
/// أرقامًا ثابتة في الكود.
class PatternStudioConfigEntity extends Equatable {
  final bool enabled;
  final Money price;

  const PatternStudioConfigEntity({required this.enabled, required this.price});

  static PatternStudioConfigEntity fallback() =>
      const PatternStudioConfigEntity(
        enabled: true,
        price: Money(minorUnits: 100000, currency: Currency.shamCash),
      );

  @override
  List<Object?> get props => [enabled, price];
}
