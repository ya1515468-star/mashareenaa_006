import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/name_animation.dart';

class NameAnimationRepository {
  const NameAnimationRepository();

  SupabaseClient get _sb => Supabase.instance.client;

  Future<List<NameAnimation>> catalog() async {
    final raw = await _sb.rpc('get_name_animation_catalog');
    final rows = raw is List ? raw : const <dynamic>[];
    return rows.whereType<Map>().map((m) => NameAnimation.fromMap(Map<String, dynamic>.from(m))).where((e) => e.key.isNotEmpty && e.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<Set<String>> owned() async {
    final raw = await _sb.rpc('get_my_name_animation_effects');
    final rows = raw is List ? raw : const <dynamic>[];
    return rows.whereType<Map>().map((m) => (m['effect_key'] ?? '').toString()).where((e) => e.isNotEmpty).toSet();
  }

  Future<NameAnimation?> active(String uid) async {
    final raw = await _sb.rpc('get_active_name_animation', params: {'p_user_id': uid});
    if (raw is! Map) return null;
    final key = (raw['effect_key'] ?? '').toString().trim();
    if (key.isEmpty) return null;
    return NameAnimation.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> purchase(String key, String currency) async {
    await _sb.rpc('purchase_name_animation', params: {
      'p_effect_key': key,
      'p_currency': currency,
      'p_request_id': const Uuid().v4(),
    });
  }

  Future<void> activate(String key) async {
    await _sb.rpc('set_name_animation', params: {'p_effect_key': key});
  }

  Future<void> clear() async {
    await _sb.rpc('set_name_animation', params: {'p_effect_key': null});
  }
}
