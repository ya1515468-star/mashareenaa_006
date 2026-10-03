import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final externalRequestsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, status) {
  return Supabase.instance.client
      .from('external_requests')
      .stream(primaryKey: ['id'])
      .eq('status', status)
      .order('created_at', ascending: false)
      .map((rows) => rows.cast<Map<String, dynamic>>());
});

final myExternalBidsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
  return Supabase.instance.client
      .from('external_request_bids')
      .stream(primaryKey: ['id'])
      .eq('uid', uid)
      .order('created_at', ascending: false)
      .map((rows) => rows.cast<Map<String, dynamic>>());
});

final allExternalBidsAdminProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('external_request_bids')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.cast<Map<String, dynamic>>());
});

class ExternalRequestsController extends StateNotifier<AsyncValue<void>> {
  ExternalRequestsController() : super(const AsyncValue.data(null));

  final _db = Supabase.instance.client;

  Future<void> postExternalRequest({
    required String title,
    required String description,
    required String targetCountry,
    String? deliveryPort,
    String? quantity,
    String? unit,
    String incoterms = 'FOB',
    String? paymentTerms,
    String? certification,
    bool sampleRequired = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.rpc('post_external_request', params: {
        'p_title': title,
        'p_description': description,
        'p_target_country': targetCountry,
        'p_delivery_port': deliveryPort,
        'p_quantity': quantity,
        'p_unit': unit,
        'p_incoterms': incoterms,
        'p_payment_terms': paymentTerms,
        'p_certification': certification,
        'p_sample_required': sampleRequired,
      });
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> respondToRequest({
    required String requestId,
    required double price,
    String? note,
    int? deliveryDays,
    String? attachmentUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.rpc('respond_to_external_request', params: {
        'p_request_id': requestId,
        'p_price': price,
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
      await _db.rpc('owner_moderate_external_bid', params: {
        'p_bid_id': bidId,
        'p_accept': accept,
      });
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

final externalRequestsControllerProvider =
    StateNotifierProvider<ExternalRequestsController, AsyncValue<void>>(
        (ref) => ExternalRequestsController());
