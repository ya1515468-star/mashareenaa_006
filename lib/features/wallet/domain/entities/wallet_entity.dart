import 'package:equatable/equatable.dart';
import 'currency.dart';

/// المحفظة — رصيد بعملتين منفصلتين لكل مستخدم، بحسب المخطط الرسمي.
class WalletEntity extends Equatable {
  final String uid;
  final Money shamCashBalance;
  final Money usdBalance;
  final DateTime updatedAt;

  const WalletEntity({
    required this.uid,
    required this.shamCashBalance,
    required this.usdBalance,
    required this.updatedAt,
  });

  Money balanceOf(Currency currency) {
    switch (currency) {
      case Currency.shamCash:
        return shamCashBalance;
      case Currency.usd:
        return usdBalance;
    }
  }

  static WalletEntity empty(String uid) => WalletEntity(
        uid: uid,
        shamCashBalance: Money.zero(Currency.shamCash),
        usdBalance: Money.zero(Currency.usd),
        updatedAt: DateTime.now(),
      );

  @override
  List<Object?> get props => [uid, shamCashBalance, usdBalance, updatedAt];
}
