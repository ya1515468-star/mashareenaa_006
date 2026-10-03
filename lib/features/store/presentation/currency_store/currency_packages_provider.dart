import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Stream الباقات ─────────────────────────────────────────────────
final currencyPackagesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, type) {
  return Supabase.instance.client
      .from('currency_packages')
      .stream(primaryKey: ['id'])
      .eq('currency_type', type)
      .eq('is_active', true)
      .order('sort_order');
});

final allCurrencyPackagesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('currency_packages')
      .stream(primaryKey: ['id'])
      .order('currency_type')
      .order('sort_order');
});

// ─── Controller ─────────────────────────────────────────────────────
class CurrencyStoreController {
  final _db = Supabase.instance.client;

  Future<void> upsertPackage({
    String? id,
    required String currencyType,
    required String name,
    String description = '',
    required int amount,
    required double priceUsd,
    String priceDisplay = '',
    String? iconUrl,
    String? badgeLabel,
    bool isFeatured = false,
    int sortOrder = 0,
    bool isActive = true,
    String displayStyle = 'card',
    int bonusAmount = 0,
  }) async {
    await _db.rpc('owner_upsert_currency_package', params: {
      'p_id': id,
      'p_currency_type': currencyType,
      'p_name': name,
      'p_description': description,
      'p_amount': amount,
      'p_price_usd': priceUsd,
      'p_price_display': priceDisplay,
      'p_icon_url': iconUrl,
      'p_badge_label': badgeLabel,
      'p_is_featured': isFeatured,
      'p_sort_order': sortOrder,
      'p_is_active': isActive,
      'p_display_style': displayStyle,
      'p_bonus_amount': bonusAmount,
    });
  }

  Future<void> deletePackage(String id) async {
    await _db.rpc('owner_delete_currency_package', params: {'p_id': id});
  }
}

final currencyStoreControllerProvider =
    Provider<CurrencyStoreController>((_) => CurrencyStoreController());
