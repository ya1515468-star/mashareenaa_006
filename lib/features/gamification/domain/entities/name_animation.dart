import 'package:equatable/equatable.dart';

class NameAnimation extends Equatable {
  final String key;
  final String nameAr;
  final String category;
  final String? assetPath;
  final String? assetUrl;
  final String? storagePath;
  final int sizeBytes;
  final String animationType;
  final int fps;
  final int durationMs;
  final double maxWidth;
  final double maxHeight;
  final bool transparent;
  final bool loop;
  final int pricePoints;
  final int priceGems;
  final bool ownerFree;
  final bool isActive;
  final int sortOrder;
  final Map<String, dynamic> metadata;
  /// Legacy payload retained only for database compatibility. Runtime animal rendering always uses GIF Storage.
  final Map<String, dynamic>? animationJson;
  final int? sourceWidth;
  final int? sourceHeight;
  final int frameCount;
  final String renderEffect;

  const NameAnimation({
    required this.key,
    required this.nameAr,
    required this.category,
    this.assetPath,
    this.assetUrl,
    this.storagePath,
    this.sizeBytes = 0,
    this.animationType = 'gif',
    this.fps = 24,
    this.durationMs = 1800,
    this.maxWidth = 46,
    this.maxHeight = 36,
    this.transparent = true,
    this.loop = true,
    this.pricePoints = 0,
    this.priceGems = 0,
    this.ownerFree = false,
    this.isActive = true,
    this.sortOrder = 0,
    this.metadata = const {},
    this.animationJson,
    this.sourceWidth,
    this.sourceHeight,
    this.frameCount = 1,
    this.renderEffect = 'float_glow',
  });

  factory NameAnimation.fromMap(Map<String, dynamic> m) => NameAnimation(
    key: (m['effect_key'] ?? m['key'] ?? '').toString().trim(),
    nameAr: (m['name_ar'] ?? 'تأثير').toString().trim(),
    category: (m['category'] ?? 'animal').toString().trim(),
    assetPath: _text(m['asset_path']),
    assetUrl: _text(m['asset_url']),
    storagePath: _text(m['storage_path']),
    sizeBytes: (m['size_bytes'] as num?)?.toInt() ?? 0,
    animationType: (m['animation_type'] ?? 'gif').toString(),
    fps: (m['fps'] as num?)?.toInt() ?? 24,
    durationMs: (m['duration_ms'] as num?)?.toInt() ?? 1800,
    maxWidth: (m['max_width'] as num?)?.toDouble() ?? 44,
    maxHeight: (m['max_height'] as num?)?.toDouble() ?? 30,
    transparent: m['transparent'] != false,
    loop: m['loop'] != false,
    pricePoints: (m['price_points'] as num?)?.toInt() ?? 0,
    priceGems: (m['price_gems'] as num?)?.toInt() ?? 0,
    ownerFree: m['owner_free'] == true,
    isActive: m['is_active'] != false,
    sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
    metadata: m['metadata'] is Map ? Map<String, dynamic>.from(m['metadata'] as Map) : const {},
    animationJson: m['animation_json'] is Map ? Map<String, dynamic>.from(m['animation_json'] as Map) : null,
    sourceWidth: (m['source_width'] as num?)?.toInt() ?? ((m['metadata'] is Map ? (m['metadata']['source_width'] as num?) : null)?.toInt()),
    sourceHeight: (m['source_height'] as num?)?.toInt() ?? ((m['metadata'] is Map ? (m['metadata']['source_height'] as num?) : null)?.toInt()),
    frameCount: (m['frame_count'] as num?)?.toInt() ?? ((m['metadata'] is Map ? (m['metadata']['frame_count'] as num?) : null)?.toInt() ?? 1),
    renderEffect: (m['render_effect'] ?? (m['metadata'] is Map ? m['metadata']['render_effect'] : null) ?? 'float_glow').toString(),
  );

  static String? _text(dynamic v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }

  @override
  List<Object?> get props => [key, assetPath, assetUrl, storagePath, animationJson, sourceWidth, sourceHeight, frameCount, renderEffect, pricePoints, priceGems, isActive, sortOrder];
}
