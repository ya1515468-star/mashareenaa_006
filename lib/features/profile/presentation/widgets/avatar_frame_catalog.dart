import 'package:flutter/foundation.dart';

import '../../../../core/widgets/avatar_frame_metrics.dart';
import '../../../../core/widgets/frame_effect_catalog.dart';

/// Server-backed avatar frame definition.
/// No local frame assets are part of the production contract.
@immutable
class AvatarFrameDefinition {
  final String key;
  final String gender;
  final String nameAr;
  final String? assetUrl;
  final String? storagePath;
  final int durationMs;
  final List<String> allowedRoleCodes;
  final int minRankLevel;
  final int? maxRankLevel;
  final String frameEffect;
  final AvatarFrameMetrics metrics;
  // كان العميل يحسب "مقفل" من الملكية فقط (شراء)، متجاهلًا ١٠٠ إطار من
  // أصل ٢٠٢ مجانية فعليًا حسب منطق الخادم (بلا سعر ولا قيد رتبة) — فتظهر
  // مقفلة أبديًا. الخادم الآن يحسب الإتاحة الحقيقية بنفسه ويرسلها هنا
  // مباشرة، فلا حساب منفصل ناقص في التطبيق.
  final bool canActivate;
  final bool isOwned;
  final int pricePoints;
  final int priceGems;

  const AvatarFrameDefinition({
    required this.key,
    required this.gender,
    required this.nameAr,
    required this.assetUrl,
    required this.storagePath,
    required this.durationMs,
    required this.allowedRoleCodes,
    required this.minRankLevel,
    required this.maxRankLevel,
    this.canActivate = false,
    this.isOwned = false,
    this.pricePoints = 0,
    this.priceGems = 0,
    this.frameEffect = 'pulse_glow',
    this.metrics = const AvatarFrameMetrics(
      innerOpeningRatio: 0.74,
      innerCenterX: 0.5,
      innerCenterY: 0.5,
      detectedFromTransparency: false,
    ),
  });

  factory AvatarFrameDefinition.fromMap(Map<String, dynamic> map) {
    return AvatarFrameDefinition(
      key: map['frame_key']?.toString() ?? '',
      gender: map['gender']?.toString() ?? 'unisex',
      nameAr: map['name_ar']?.toString() ?? 'إطار',
      assetUrl: _nullableText(map['asset_url']),
      storagePath: _nullableText(map['storage_path']),
      durationMs: (map['duration_ms'] as num?)?.toInt() ?? 0,
      allowedRoleCodes: map['allowed_role_codes'] is List
          ? (map['allowed_role_codes'] as List<dynamic>)
              .map((e) => e.toString().trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
      minRankLevel: (map['min_rank_level'] as num?)?.toInt() ?? 0,
      maxRankLevel: (map['max_rank_level'] as num?)?.toInt(),
      canActivate: map['can_activate'] == true,
      isOwned: map['is_owned'] == true,
      pricePoints: (map['price_points'] as num?)?.toInt() ?? 0,
      priceGems: (map['price_gems'] as num?)?.toInt() ?? 0,
      frameEffect: _normalizeEffect(map['frame_effect'] ?? map['palette_key']),
      metrics: AvatarFrameMetrics.fromMap(
        map['frame_metrics'] is Map
            ? Map<String, dynamic>.from(map['frame_metrics'] as Map)
            : null,
      ),
    );
  }

  static String _normalizeEffect(Object? value) => FrameEffectCatalog.normalize(value);

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
