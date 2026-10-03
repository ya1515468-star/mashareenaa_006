import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final vipFavoriteMessageProvider =
    FutureProvider.family<bool, String>((ref, messageId) async {
  try {
    final raw = await Supabase.instance.client.rpc(
      'get_profile_service_runtime',
      params: {'p_feature_key': 'chat_favorites_plus'},
    );
    if (raw is! Map || raw['enabled'] != true) return false;
    final settings = raw['settings'];
    if (settings is! Map) return false;
    final ids = settings['favorite_message_ids'];
    return ids is List && ids.map((e) => e.toString()).contains(messageId);
  } catch (_) {
    return false;
  }
});

class VipFavoriteButton extends ConsumerWidget {
  final String messageId;
  final bool enabled;
  final VoidCallback? onChanged;
  const VipFavoriteButton({super.key, required this.messageId, required this.enabled, this.onChanged});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool current) async {
    try {
      final raw = await Supabase.instance.client.rpc(
        'get_profile_service_runtime',
        params: {'p_feature_key': 'chat_favorites_plus'},
      );
      if (raw is! Map || raw['enabled'] != true) throw StateError('ITEM_NOT_OWNED');
      final settings = raw['settings'] is Map
          ? Map<String, dynamic>.from(raw['settings'] as Map)
          : <String, dynamic>{};
      final ids = (settings['favorite_message_ids'] is List
              ? (settings['favorite_message_ids'] as List).map((e) => e.toString())
              : const <String>[]) 
          .toSet();
      if (current) {
        ids.remove(messageId);
      } else {
        ids.add(messageId);
      }
      await Supabase.instance.client.rpc(
        'set_profile_service_setting',
        params: {
          'p_feature_key': 'chat_favorites_plus',
          'p_key': 'favorite_message_ids',
          'p_value': ids.toList(growable: false),
        },
      );
      ref.invalidate(vipFavoriteMessageProvider(messageId));
      onChanged?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث المفضلة: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: enabled ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
      icon: Icon(enabled ? Icons.star : Icons.star_border, size: 18,
          color: enabled ? Colors.amber : Colors.white54),
      onPressed: () => _toggle(context, ref, enabled),
    );
  }
}
