import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── قائمة المناقصات حسب الحالة ─────────────────────────────────────────────
final tendersProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, status) {
  return Supabase.instance.client
      .from('tenders')
      .stream(primaryKey: ['id'])
      .eq('status', status)
      .order('created_at', ascending: false)
      .map((rows) => rows.cast<Map<String, dynamic>>());
});

// ─── عروض مناقصة محددة ───────────────────────────────────────────────────────
final tenderSubmissionsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, tenderId) {
  return Supabase.instance.client
      .from('tender_bids')
      .stream(primaryKey: ['id'])
      .eq('tender_id', tenderId)
      .order('created_at', ascending: false)
      .map((rows) => rows.cast<Map<String, dynamic>>());
});

// ─── عروضي أنا ───────────────────────────────────────────────────────────────
final myBidsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
  return Supabase.instance.client
      .from('tender_bids')
      .stream(primaryKey: ['id'])
      .eq('uid', uid)
      .order('created_at', ascending: false)
      .map((rows) => rows.cast<Map<String, dynamic>>());
});

// ─── كل العروض (للمالك) ──────────────────────────────────────────────────────
final allSubmissionsAdminProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('tender_bids')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.cast<Map<String, dynamic>>());
});

// ─── Controller ──────────────────────────────────────────────────────────────
class TendersController extends StateNotifier<AsyncValue<void>> {
  TendersController() : super(const AsyncValue.data(null));

  final _db = Supabase.instance.client;

  Future<void> postTender({
    required String title,
    required String description,
    String? requirements,
    double? budgetMin,
    double? budgetMax,
    String? location,
    String? quantity,
    String category = 'garment',
    DateTime? deadline,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.rpc('post_tender', params: {
        'p_title': title,
        'p_description': description,
        'p_requirements': requirements,
        'p_budget_min': budgetMin,
        'p_budget_max': budgetMax,
        'p_currency': 'USD',
        'p_location': location,
        'p_quantity': quantity,
        'p_quantity_unit': 'قطعة',
        'p_category': category,
        'p_deadline': deadline?.toIso8601String(),
        'p_min_membership': 'free',
      });
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> submitBid({
    required String tenderId,
    required double price,
    String? note,
    int? deliveryDays,
    String? attachmentUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.rpc('submit_tender_bid', params: {
        'p_tender_id': tenderId,
        'p_price': price,
        'p_currency': 'USD',
        'p_note': note,
        'p_delivery_days': deliveryDays,
        'p_attachment_url': attachmentUrl,
      });
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> moderateBid(
      {required String bidId, required bool accept}) async {
    try {
      await _db.rpc('owner_moderate_tender_bid', params: {
        'p_bid_id': bidId,
        'p_action': accept ? 'accept' : 'reject',
      });
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> closeTender(String tenderId) async {
    try {
      await _db.rpc('owner_moderate_tender', params: {
        'p_tender_id': tenderId,
        'p_action': 'close',
      });
    } catch (_) {}
  }

  Future<void> deleteTender(String tenderId) async {
    try {
      await _db.rpc('owner_moderate_tender', params: {
        'p_tender_id': tenderId,
        'p_action': 'delete',
      });
    } catch (_) {}
  }
}

final tendersControllerProvider =
    StateNotifierProvider<TendersController, AsyncValue<void>>(
        (ref) => TendersController());
