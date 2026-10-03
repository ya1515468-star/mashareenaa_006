import '../../../../core/data/supabase_document_compat.dart';
import '../../domain/entities/currency.dart';
import '../../domain/entities/wallet_entity.dart';

class WalletModel extends WalletEntity {
  const WalletModel({
    required super.uid,
    required super.shamCashBalance,
    required super.usdBalance,
    required super.updatedAt,
  });

  factory WalletModel.fromMap(String uid, Map<String, dynamic> map) {
    final wallet = (map['wallet'] as Map?) ?? {};
    return WalletModel(
      uid: uid,
      shamCashBalance: Money(
        minorUnits: wallet['shamCashMinorUnits'] as int? ?? 0,
        currency: Currency.shamCash,
      ),
      usdBalance: Money(
        minorUnits: wallet['usdMinorUnits'] as int? ?? 0,
        currency: Currency.usd,
      ),
      updatedAt:
          (wallet['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toWalletFieldMap() {
    return {
      'shamCashMinorUnits': shamCashBalance.minorUnits,
      'usdMinorUnits': usdBalance.minorUnits,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
