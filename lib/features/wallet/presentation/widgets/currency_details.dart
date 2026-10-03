import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تفاصيل النقاط والجواهر داخل المحفظة.
///
/// كانت المحفظة تعرض شام كاش والدولار فقط، بينما النقاط والجواهر —
/// وهما عملتا التداول الفعليتين في المنصة (الهدايا، نشر الريلز،
/// رسوم المنشآت) — لا تظهران فيها إطلاقًا.
///
/// كل الأرقام من الخادم: الرصيد الحالي، وإجمالي المكتسب والمنفَق،
/// وآخر الحركات من wallet_transactions.

final _db = Supabase.instance.client;

class CurrencyDetail {
  final int balance;
  final int lifetimeEarned;
  final int lifetimeSpent;
  const CurrencyDetail({
    required this.balance,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
  });

  factory CurrencyDetail.fromRow(Map<String, dynamic>? r) => CurrencyDetail(
        balance: (r?['balance'] as num?)?.toInt() ?? 0,
        lifetimeEarned: (r?['lifetime_earned'] as num?)?.toInt() ?? 0,
        lifetimeSpent: (r?['lifetime_spent'] as num?)?.toInt() ?? 0,
      );

  static const empty =
      CurrencyDetail(balance: 0, lifetimeEarned: 0, lifetimeSpent: 0);
}

class WalletCurrencies {
  final CurrencyDetail points;
  final CurrencyDetail gems;
  const WalletCurrencies({required this.points, required this.gems});
}

final walletCurrenciesProvider =
    FutureProvider.autoDispose<WalletCurrencies>((ref) async {
  final uid = _db.auth.currentUser?.id;
  if (uid == null) {
    return const WalletCurrencies(
        points: CurrencyDetail.empty, gems: CurrencyDetail.empty);
  }

  Future<Map<String, dynamic>?> read(String table) async {
    try {
      final r = await _db.from(table).select().eq('user_id', uid).maybeSingle();
      return r == null ? null : Map<String, dynamic>.from(r);
    } catch (_) {
      // المحفظة قد لا تكون أُنشئت بعد لعضو جديد — صفر لا خطأ
      return null;
    }
  }

  final results = await Future.wait([read('points_wallets'), read('gems_wallets')]);
  return WalletCurrencies(
    points: CurrencyDetail.fromRow(results[0]),
    gems: CurrencyDetail.fromRow(results[1]),
  );
});

/// آخر حركات النقاط والجواهر
final currencyMovementsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = _db.auth.currentUser?.id;
  if (uid == null) return const [];
  try {
    final rows = await _db
        .from('wallet_transactions')
        .select()
        .eq('user_id', uid)
        .inFilter('currency', ['points', 'gems'])
        .order('created_at', ascending: false)
        .limit(40);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (_) {
    return const [];
  }
});

// ═══ الودجات ═══════════════════════════════════════════════════════
class CurrencyBalanceCard extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final CurrencyDetail detail;
  const CurrencyBalanceCard({
    super.key,
    required this.label,
    required this.emoji,
    required this.color,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: .22),
              color.withValues(alpha: .06),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 7),
            Text(_fmt(detail.balance),
                style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 7),
            _row('اكتُسب', detail.lifetimeEarned, const Color(0xFF34D399)),
            _row('أُنفق', detail.lifetimeSpent, const Color(0xFFF87171)),
          ],
        ),
      );

  Widget _row(String k, int v, Color c) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: const TextStyle(fontSize: 10.5, color: Colors.white38)),
            Text(_fmt(v),
                style: TextStyle(
                    fontSize: 11, color: c, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  static String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

class CurrencyMovementTile extends StatelessWidget {
  final Map<String, dynamic> row;
  const CurrencyMovementTile({super.key, required this.row});

  @override
  Widget build(BuildContext context) {
    final amount = (row['amount'] as num?)?.toInt() ?? 0;
    final isPoints = row['currency']?.toString() == 'points';
    final incoming = amount >= 0;
    final when = DateTime.tryParse(row['created_at']?.toString() ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (incoming
                      ? const Color(0xFF34D399)
                      : const Color(0xFFF87171))
                  .withValues(alpha: .15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(isPoints ? '⭐' : '💎',
                style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label(row['transaction_type']?.toString() ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                if (when != null)
                  Text(
                      '${when.toLocal().year}/${when.toLocal().month.toString().padLeft(2, '0')}/'
                      '${when.toLocal().day.toString().padLeft(2, '0')}'
                      '  ${when.toLocal().hour.toString().padLeft(2, '0')}:'
                      '${when.toLocal().minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.white38)),
              ],
            ),
          ),
          Text('${incoming ? '+' : ''}$amount',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: incoming
                      ? const Color(0xFF34D399)
                      : const Color(0xFFF87171))),
        ],
      ),
    );
  }

  static String _label(String t) => switch (t) {
        'gift_sent' => 'هدية أرسلتها',
        'gift_received' => 'هدية وصلتك',
        'transfer_sent' => 'تحويل صادر',
        'transfer_received' => 'تحويل وارد',
        'currency_package_reward' => 'شراء باقة',
        'currency_package_purchase' => 'دفع ثمن باقة',
        'reel_publish' => 'نشر فيديو',
        'business_publish' => 'نشر منشأة',
        'daily_reward' => 'مكافأة يومية',
        'membership_grant' => 'منحة عضوية',
        'store_purchase' => 'شراء من المتجر',
        _ => t.isEmpty ? 'حركة' : t,
      };
}
