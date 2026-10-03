import 'package:equatable/equatable.dart';

/// العملتان المدعومتان بحسب المخطط الرسمي (البند 8: Wallet System).
enum Currency { shamCash, usd }

extension CurrencyX on Currency {
  String get wire => name;

  static Currency fromWire(String? s) => Currency.values
      .firstWhere((e) => e.wire == s, orElse: () => Currency.shamCash);

  String get symbol {
    switch (this) {
      case Currency.shamCash:
        return 'ش.ك';
      case Currency.usd:
        return r'$';
    }
  }

  String get displayName {
    switch (this) {
      case Currency.shamCash:
        return 'شام كاش';
      case Currency.usd:
        return 'دولار أمريكي';
    }
  }
}

/// قيمة نقدية بعملة محددة. تُخزَّن كأصغر وحدة (سنت/فلس) لتفادي أخطاء
/// الفاصلة العشرية عند الجمع والطرح المتكرر في المعاملات المالية.
class Money extends Equatable {
  final int minorUnits;
  final Currency currency;

  const Money({required this.minorUnits, required this.currency});

  factory Money.zero(Currency currency) =>
      Money(minorUnits: 0, currency: currency);

  double get value => minorUnits / 100;

  bool get isNegative => minorUnits < 0;

  Money operator +(Money other) {
    assert(currency == other.currency, 'لا يمكن جمع عملتين مختلفتين مباشرة');
    return Money(minorUnits: minorUnits + other.minorUnits, currency: currency);
  }

  Money operator -(Money other) {
    assert(currency == other.currency, 'لا يمكن طرح عملتين مختلفتين مباشرة');
    return Money(minorUnits: minorUnits - other.minorUnits, currency: currency);
  }

  bool operator >=(Money other) {
    assert(currency == other.currency);
    return minorUnits >= other.minorUnits;
  }

  String get formatted => '${value.toStringAsFixed(2)} ${currency.symbol}';

  @override
  List<Object?> get props => [minorUnits, currency];
}
