import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// شراء باقات النقاط والجواهر.
///
/// كل الحساب خادمي عبر `purchase_currency_package`: الخادم يخصم رصيد
/// شام كاش، يضيف للمحفظة، ويكتب قيدَي wallet_transactions والتدقيق —
/// كلها في معاملة واحدة. التطبيق لا يحسب مالًا أبدًا.
///
/// `p_request_id` مفتاح منع التكرار: لو انقطعت الشبكة بعد نجاح العملية
/// وأعاد المستخدم المحاولة بنفس المعرّف، يعيد الخادم نتيجة العملية
/// الأولى بدل خصم المبلغ مرتين.
class CurrencyPurchaseService {
  CurrencyPurchaseService._();

  static const _uuid = Uuid();

  static Future<CurrencyPurchaseResult> purchase({
    required String packageId,
    String? requestId,
  }) async {
    try {
      final raw = await Supabase.instance.client.rpc(
        'purchase_currency_package',
        params: {
          'p_package_id': packageId,
          'p_request_id': requestId ?? _uuid.v4(),
        },
      );

      final map = raw is Map ? Map<String, dynamic>.from(raw) : null;
      if (map == null || map['ok'] != true) {
        return const CurrencyPurchaseResult.failure(
            'تعذّر إتمام الشراء. حاول مجددًا.');
      }

      return CurrencyPurchaseResult.success(
        granted: (map['granted'] as num?)?.toInt() ?? 0,
        currencyType: map['package_type']?.toString() ?? 'points',
        walletBalance: (map['wallet_balance'] as num?)?.toInt() ?? 0,
        cashBalance: (map['cash_balance'] as num?)?.toInt() ?? 0,
      );
    } on PostgrestException catch (e) {
      return CurrencyPurchaseResult.failure(_arabicError(e.message));
    } catch (e) {
      return CurrencyPurchaseResult.failure(_arabicError(e.toString()));
    }
  }

  static String _arabicError(String raw) {
    if (raw.contains('INSUFFICIENT_BALANCE')) {
      return 'رصيد شام كاش غير كافٍ لإتمام الشراء.';
    }
    if (raw.contains('PACKAGE_NOT_FOUND')) {
      return 'هذه الباقة لم تعد متاحة.';
    }
    if (raw.contains('INVALID_PACKAGE_AMOUNT') ||
        raw.contains('INVALID_PACKAGE_PRICE')) {
      return 'إعداد الباقة غير صحيح — راجع المالك.';
    }
    if (raw.contains('AUTH_REQUIRED')) {
      return 'سجّل الدخول أولًا.';
    }
    return 'تعذّر إتمام الشراء: $raw';
  }
}

class CurrencyPurchaseResult {
  final bool ok;
  final String? error;
  final int granted;
  final String currencyType;
  final int walletBalance;
  final int cashBalance;

  const CurrencyPurchaseResult.success({
    required this.granted,
    required this.currencyType,
    required this.walletBalance,
    required this.cashBalance,
  })  : ok = true,
        error = null;

  const CurrencyPurchaseResult.failure(this.error)
      : ok = false,
        granted = 0,
        currencyType = '',
        walletBalance = 0,
        cashBalance = 0;

  String get successMessage => currencyType == 'points'
      ? 'أُضيفت $granted نقطة إلى رصيدك ⭐'
      : 'أُضيف $granted جوهرة إلى رصيدك 💎';
}
