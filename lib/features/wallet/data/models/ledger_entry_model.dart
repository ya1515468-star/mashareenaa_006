import '../../../../core/data/supabase_document_compat.dart';
import '../../domain/entities/currency.dart';
import '../../domain/entities/ledger_entry_entity.dart';

class LedgerEntryModel extends LedgerEntryEntity {
  const LedgerEntryModel({
    required super.id,
    required super.uid,
    required super.type,
    required super.amount,
    super.counterpartyUid,
    super.note,
    required super.createdAt,
  });

  factory LedgerEntryModel.fromMap(String id, Map<String, dynamic> map) {
    return LedgerEntryModel(
      id: id,
      uid: map['uid'] as String? ?? '',
      type: LedgerEntryTypeX.fromWire(map['type'] as String?),
      amount: Money(
        minorUnits: map['amountMinorUnits'] as int? ?? 0,
        currency: CurrencyX.fromWire(map['currency'] as String?),
      ),
      counterpartyUid: map['counterpartyUid'] as String?,
      note: map['note'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'type': type.wire,
      'amountMinorUnits': amount.minorUnits,
      'currency': amount.currency.wire,
      'counterpartyUid': counterpartyUid,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
