import 'package:equatable/equatable.dart';
import 'currency.dart';

/// أنواع المعاملات المدعومة — يتسع مع كل وحدة تتكامل مع المحفظة
/// لاحقًا (Marketplace للشراء/البيع، Subscriptions للاشتراكات...).
enum LedgerEntryType {
  topUp,
  transferSent,
  transferReceived,
  purchase,
  sale,
  dailyReward,
  refund,
  adjustment,
  pointsPurchase,
}

extension LedgerEntryTypeX on LedgerEntryType {
  String get wire => name;

  static LedgerEntryType fromWire(String? s) =>
      LedgerEntryType.values.firstWhere(
        (e) => e.wire == s,
        orElse: () => LedgerEntryType.adjustment,
      );
}

/// قيد واحد في سجل معاملات المستخدم — غير قابل للتعديل بعد إنشائه
/// (Append-only)، وهو مصدر الحقيقة الوحيد لأي تدقيق مالي لاحق.
class LedgerEntryEntity extends Equatable {
  final String id;
  final String uid;
  final LedgerEntryType type;
  final Money amount;
  final String? counterpartyUid;
  final String? note;
  final DateTime createdAt;

  const LedgerEntryEntity({
    required this.id,
    required this.uid,
    required this.type,
    required this.amount,
    this.counterpartyUid,
    this.note,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, uid, type, amount, counterpartyUid, note, createdAt];
}
