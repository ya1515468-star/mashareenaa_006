import 'package:flutter/material.dart';

/// Flutter can't build an [IconData] from an arbitrary string at runtime, so
/// section icons are stored in the database as a short key from this curated
/// set, and resolved to a real icon here. Add more entries as needed — the
/// key is what the admin picks from and what gets saved server-side.
const Map<String, IconData> kChatStoreSectionIcons = {
  'photo_camera_back': Icons.photo_camera_back,
  'palette': Icons.palette,
  'wallpaper': Icons.wallpaper,
  'auto_awesome': Icons.auto_awesome,
  'badge': Icons.badge,
  'color_lens': Icons.color_lens,
  'workspace_premium': Icons.workspace_premium,
  'style': Icons.style,
  'pets': Icons.pets,
  'star': Icons.star,
  'diamond': Icons.diamond,
  'card_giftcard': Icons.card_giftcard,
  'bolt': Icons.bolt,
  'favorite': Icons.favorite,
  'local_fire_department': Icons.local_fire_department,
  'emoji_events': Icons.emoji_events,
  'shield': Icons.shield,
  'crown': Icons.emoji_events,
  'brush': Icons.brush,
  'image': Icons.image,
  'category': Icons.category,
  'storefront': Icons.storefront,
};

IconData resolveChatStoreSectionIcon(String? key) => kChatStoreSectionIcons[key] ?? Icons.style;
