import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/member_badge.dart';

class MemberBadgeRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<MemberBadge>> listActive() async {
    final raw = await _client.rpc('list_member_badges');
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    ).map(MemberBadge.fromMap).toList(growable: false);
  }

  Future<List<MemberBadge>> listForAdmin() async {
    final raw = await _client.rpc('list_member_badges_for_admin');
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    ).map(MemberBadge.fromMap).toList(growable: false);
  }

  Future<Map<String, dynamic>?> getForUser(String userId) async {
    final raw = await _client.rpc('get_user_member_badge', params: {'p_user_id': userId});
    if (raw is! Map || raw.isEmpty) return null;
    final map = Map<String, dynamic>.from(raw);
    if ((map['asset_url'] ?? '').toString().trim().isEmpty) return null;
    return map;
  }

  Future<void> create({
    required String badgeKey,
    required String nameAr,
    required String category,
    String? description,
    required String assetPath,
    required String assetUrl,
    required int fileSizeBytes,
    int? width,
    int? height,
    int sortOrder = 0,
  }) async {
    await _client.rpc('create_member_badge', params: {
      'p_badge_key': badgeKey,
      'p_name_ar': nameAr,
      'p_category': category,
      'p_description': description,
      'p_asset_path': assetPath,
      'p_asset_url': assetUrl,
      'p_file_size_bytes': fileSizeBytes,
      'p_width': width,
      'p_height': height,
      'p_metadata': const {'transparent': true, 'placement': 'above_name_template'},
      'p_sort_order': sortOrder,
      'p_request_id': const Uuid().v4(),
    });
  }

  Future<void> update({
    required String badgeId,
    required String badgeKey,
    required String nameAr,
    required String category,
    String? description,
    required String assetPath,
    required String assetUrl,
    required int fileSizeBytes,
    int? width,
    int? height,
    int sortOrder = 0,
  }) async {
    await _client.rpc('update_member_badge_catalog', params: {
      'p_badge_id': badgeId,
      'p_badge_key': badgeKey,
      'p_name_ar': nameAr,
      'p_category': category,
      'p_description': description,
      'p_asset_path': assetPath,
      'p_asset_url': assetUrl,
      'p_file_size_bytes': fileSizeBytes,
      'p_width': width,
      'p_height': height,
      'p_metadata': const {'transparent': true, 'placement': 'above_name_template'},
      'p_sort_order': sortOrder,
      'p_request_id': const Uuid().v4(),
    });
  }

  Future<void> setActive(String badgeId, bool active) async {
    await _client.rpc('set_member_badge_active', params: {
      'p_badge_id': badgeId,
      'p_is_active': active,
      'p_request_id': const Uuid().v4(),
    });
  }

  Future<void> assignToUser({required String userId, required String badgeKey}) async {
    await _client.rpc('set_user_member_badge', params: {
      'p_user_id': userId,
      'p_badge_key': badgeKey,
      'p_request_id': const Uuid().v4(),
    });
  }

  Future<void> clearForUser(String userId) async {
    await _client.rpc('clear_user_member_badge', params: {
      'p_user_id': userId,
      'p_request_id': const Uuid().v4(),
    });
  }
}
