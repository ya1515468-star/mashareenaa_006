import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ContentEngagementRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>> get(String contentId) async {
    final raw = await _client.rpc('get_content_engagement', params: {'p_content_id': contentId});
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> record({
    required String contentId,
    required String eventType,
    String? ownerUserId,
  }) async {
    final raw = await _client.rpc('record_content_engagement', params: {
      'p_content_id': contentId,
      'p_event_type': eventType,
      'p_owner_user_id': ownerUserId,
      'p_request_id': const Uuid().v4(),
    });
    return Map<String, dynamic>.from(raw as Map);
  }
}
