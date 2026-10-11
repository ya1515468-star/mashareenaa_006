import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── قراءة الباقات ──────────────────────────────────────────────────
//
// كان هذا StreamProvider يعتمد على Realtime مع مُرشِّحَين متتاليين
// (currency_type + is_active). مجرى Supabase لا يحمل إلا مُرشِّحًا واحدًا،
// ولا يُصدِر أي قيمة إطلاقًا ما لم تنجح قناة Realtime — ومراقب الأخطاء
// يسجّل RealtimeSubscribeException (channelError/timedOut) فعليًا على هذا
// المشروع. النتيجة: قائمة باقات فارغة دائمًا للمستخدم وللمالك معًا رغم
// وجود الصفوف على الخادم. قراءة عادية (select) تعمل دائمًا، والتحديث
// الفوري يتم بإبطال المزوّد بعد كل تعديل من المالك.
final currencyPackagesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, type) async {
  final rows = await Supabase.instance.client
      .from('currency_packages')
      .select()
      .eq('currency_type', type)
      .eq('is_active', true)
      .order('sort_order');
  return List<Map<String, dynamic>>.from(rows as List);
});

/// للمالك: كل الباقات بما فيها المعطّلة.
final allCurrencyPackagesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client
      .from('currency_packages')
      .select()
      .order('currency_type')
      .order('sort_order');
  return List<Map<String, dynamic>>.from(rows as List);
});

/// تُستدعى بعد أي إضافة/تعديل/حذف من المالك حتى تظهر النتيجة فورًا.
void refreshCurrencyPackages(WidgetRef ref) {
  ref.invalidate(currencyPackagesProvider);
  ref.invalidate(allCurrencyPackagesProvider);
}

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
