import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatStoreSection {
  final String key;
  final String nameAr;
  final String iconName;
  final String? backgroundImageUrl;
  final String displayMode; // 'details' | 'small_icons' | 'large_icons'
  final int sortOrder;

  const ChatStoreSection({
    required this.key,
    required this.nameAr,
    required this.iconName,
    required this.backgroundImageUrl,
    required this.displayMode,
    required this.sortOrder,
  });

  factory ChatStoreSection.fromMap(Map<String, dynamic> m) => ChatStoreSection(
        key: m['section_key'] as String,
        nameAr: m['name_ar'] as String? ?? m['section_key'] as String,
        iconName: m['icon_name'] as String? ?? 'style',
        backgroundImageUrl: m['background_image_url'] as String?,
        displayMode: m['display_mode'] as String? ?? 'details',
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      );

  /// Sensible fallback so the tab bar still renders its known label/icon even
  /// before the network call resolves, or if a key is somehow missing.
  static ChatStoreSection fallback(String key, String nameAr, String iconName, int sortOrder) =>
      ChatStoreSection(key: key, nameAr: nameAr, iconName: iconName, backgroundImageUrl: null, displayMode: 'details', sortOrder: sortOrder);
}

final chatStoreSectionsProvider = FutureProvider<Map<String, ChatStoreSection>>((ref) async {
  final rows = await Supabase.instance.client.rpc('get_chat_store_sections') as List;
  final map = <String, ChatStoreSection>{};
  for (final r in rows.cast<Map<String, dynamic>>()) {
    final s = ChatStoreSection.fromMap(r);
    map[s.key] = s;
  }
  return map;
});
