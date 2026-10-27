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

/// أحجام الخطّ والسمايلات لكل قسم من أقسام متجر الشات (البند ٧).
///
/// كانت الأحجام أرقامًا ثابتة في الشيفرة، فلا يملك المالك تكبير اسم
/// طويل يُقصّ ولا سعرًا لا يكاد يُقرأ إلّا بإصدار جديد. الآن تُقرأ من
/// الخادم فتسري على كل الأعضاء.
class ChatStoreSectionStyle {
  const ChatStoreSectionStyle({
    this.title = 15,
    this.item = 12,
    this.price = 10,
    this.emoji = 20,
  });

  final double title;
  final double item;
  final double price;
  final double emoji;

  factory ChatStoreSectionStyle.fromMap(Map<String, dynamic> m) =>
      ChatStoreSectionStyle(
        title: (m['title'] as num?)?.toDouble() ?? 15,
        item: (m['item'] as num?)?.toDouble() ?? 12,
        price: (m['price'] as num?)?.toDouble() ?? 10,
        emoji: (m['emoji'] as num?)?.toDouble() ?? 20,
      );

  static const fallback = ChatStoreSectionStyle();
}

final chatStoreSectionStylesProvider =
    FutureProvider<Map<String, ChatStoreSectionStyle>>((ref) async {
  try {
    final raw =
        await Supabase.instance.client.rpc('get_chat_store_section_styles');
    if (raw is! Map) return const {};
    final out = <String, ChatStoreSectionStyle>{};
    raw.forEach((k, v) {
      if (v is Map) {
        out[k.toString()] =
            ChatStoreSectionStyle.fromMap(Map<String, dynamic>.from(v));
      }
    });
    return out;
  } catch (_) {
    // الأحجام تحسين لا شرط: فشل قراءتها يُبقي الافتراضي ولا يُفرِغ المتجر.
    return const {};
  }
});

/// حجم قسمٍ بعينه، أو الافتراضي إن لم يُضبَط بعد.
ChatStoreSectionStyle chatStoreStyleOf(
  Map<String, ChatStoreSectionStyle>? all,
  String sectionKey,
) =>
    all?[sectionKey] ?? ChatStoreSectionStyle.fallback;
