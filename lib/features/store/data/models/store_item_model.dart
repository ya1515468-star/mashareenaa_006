import 'package:flutter/material.dart';
import '../../domain/entities/store_item_entity.dart';

class StoreItemModel extends StoreItemEntity {
  const StoreItemModel({
    required super.id,
    required super.category,
    required super.nameAr,
    required super.pricePoints,
    required super.colors,
    super.enabled,
    super.assetUrl,
    super.rarity,
    super.isFeatured,
    super.domain = StoreProductDomain.animatedCollectibles,
    super.sku,
    super.assetType,
    super.previewAsset,
    super.priceGems,
    super.limited,
    super.limitedStart,
    super.limitedEnd,
    super.stock,
    super.maxPerUser,
    super.requiredLevel,
    super.requiredMembership,
    super.requiredRole,
    super.tags,
    super.searchKeywords,
    super.sortOrder,
  });

  factory StoreItemModel.fromEntity(StoreItemEntity e) => StoreItemModel(
        id: e.id,
        category: e.category,
        nameAr: e.nameAr,
        pricePoints: e.pricePoints,
        colors: e.colors,
        enabled: e.enabled,
        assetUrl: e.assetUrl,
        rarity: e.rarity,
        isFeatured: e.isFeatured,
        domain: e.domain,
        sku: e.sku,
        assetType: e.assetType,
        previewAsset: e.previewAsset,
        priceGems: e.priceGems,
        limited: e.limited,
        limitedStart: e.limitedStart,
        limitedEnd: e.limitedEnd,
        stock: e.stock,
        maxPerUser: e.maxPerUser,
        requiredLevel: e.requiredLevel,
        requiredMembership: e.requiredMembership,
        requiredRole: e.requiredRole,
        tags: e.tags,
        searchKeywords: e.searchKeywords,
        sortOrder: e.sortOrder,
      );

  factory StoreItemModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final sectionRaw = map['store_sections'];

    String? sectionCode;

    if (sectionRaw is Map) {
      sectionCode = sectionRaw['code']?.toString();
    }

    if (sectionRaw is List && sectionRaw.isNotEmpty) {
      final first = sectionRaw.first;

      if (first is Map) {
        sectionCode = first['code']?.toString();
      }
    }

    final categoryWire = (map['category'] ??
            sectionCode ??
            map['store_category'] ??
            map['section_code'])
        ?.toString()
        .trim()
        .toLowerCase();

    final category = StoreItemCategoryX.fromWire(categoryWire);

    final rawColors = map['colors'];

    final colors = <Color>[
      if (rawColors is List)
        ...rawColors.whereType<num>().map(
              (value) => Color(value.toInt()),
            ),
    ];

    if (colors.isEmpty) {
      final fallbackColor = switch (category) {
        StoreItemCategory.currency => const Color(0xFF00C2FF),
        StoreItemCategory.usernameGlow => const Color(0xFF8E24AA),
        StoreItemCategory.avatarFrame => const Color(0xFFD4AF37),
        StoreItemCategory.animatedBackground => const Color(0xFF3F51B5),
        StoreItemCategory.membership => const Color(0xFFFFC107),
        StoreItemCategory.particleEffect => const Color(0xFF00FFF7),
        StoreItemCategory.usernameBackground => const Color(0xFF9C27B0),
      };

      colors.add(fallbackColor);
    }

    DateTime? parseDate(dynamic value) {
      if (value is DateTime) {
        return value;
      }

      if (value is String) {
        return DateTime.tryParse(value);
      }

      return null;
    }

    final rawDomain = map['domain']?.toString();

    final domain = StoreProductDomain.values.firstWhere(
      (value) => value.wire == rawDomain,
      orElse: () {
        return switch (category) {
          StoreItemCategory.currency => StoreProductDomain.animatedCollectibles,
          StoreItemCategory.usernameGlow => StoreProductDomain.usernameEffects,
          StoreItemCategory.avatarFrame => StoreProductDomain.profileFrames,
          StoreItemCategory.animatedBackground =>
            StoreProductDomain.profileBackgrounds,
          StoreItemCategory.membership => StoreProductDomain.membershipFeatures,
          StoreItemCategory.particleEffect => StoreProductDomain.avatarEffects,
          StoreItemCategory.usernameBackground =>
            StoreProductDomain.usernameStyles,
        };
      },
    );

    final assetUrl = (map['assetUrl'] ??
            map['asset_url'] ??
            map['previewAsset'] ??
            map['preview_asset'])
        ?.toString()
        .trim();

    final effectiveAssetUrl =
        assetUrl == null || assetUrl.isEmpty ? null : assetUrl;

    final name = (map['nameAr'] ?? map['name'])?.toString().trim() ?? '';

    final sku = (map['sku'] ?? map['code'])?.toString().trim() ?? id;

    return StoreItemModel(
      id: id,
      category: category,
      nameAr: name,
      pricePoints: (map['pricePoints'] as num?)?.toInt() ?? 0,
      colors: colors,
      enabled: map['enabled'] as bool? ?? map['is_active'] as bool? ?? true,
      assetUrl: effectiveAssetUrl,
      rarity: map['rarity']?.toString() ?? 'common',
      isFeatured:
          map['isFeatured'] as bool? ?? map['featured'] as bool? ?? false,
      domain: domain,
      sku: sku.isEmpty ? id : sku,
      assetType: map['assetType']?.toString() ??
          map['asset_type']?.toString() ??
          'gif',
      previewAsset: effectiveAssetUrl,
      priceGems: (map['priceGems'] as num?)?.toInt(),
      limited: map['limited'] as bool? ?? map['is_limited'] as bool? ?? false,
      limitedStart: parseDate(
        map['limitedStart'] ?? map['effective_from'],
      ),
      limitedEnd: parseDate(
        map['limitedEnd'] ?? map['effective_until'],
      ),
      stock: (map['stock'] as num?)?.toInt() ??
          (map['stock_quantity'] as num?)?.toInt(),
      maxPerUser: (map['maxPerUser'] as num?)?.toInt(),
      requiredLevel: (map['requiredLevel'] as num?)?.toInt() ?? 0,
      requiredMembership: map['requiredMembership']?.toString(),
      requiredRole: map['requiredRole']?.toString(),
      tags: map['tags'] is List
          ? List<String>.from(map['tags'] as List)
          : const [],
      searchKeywords: map['searchKeywords'] is List
          ? List<String>.from(
              map['searchKeywords'] as List,
            )
          : const [],
      sortOrder: (map['sortOrder'] as num?)?.toInt() ??
          (map['sort_order'] as num?)?.toInt() ??
          0,
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'category': category.wire,
      'nameAr': nameAr,
      'pricePoints': pricePoints,
      'colors': colors.map((c) => c.toARGB32()).toList(),
      'enabled': enabled,
      'assetUrl': assetUrl,
      'rarity': rarity,
      'isFeatured': isFeatured,
      'domain': domain.wire,
      'sku': sku.isEmpty ? id : sku,
      'assetType': assetType,
      'previewAsset': previewAsset,
      'priceGems': priceGems,
      'limited': limited,
      'limitedStart': limitedStart?.toIso8601String(),
      'limitedEnd': limitedEnd?.toIso8601String(),
      'stock': stock,
      'maxPerUser': maxPerUser,
      'requiredLevel': requiredLevel,
      'requiredMembership': requiredMembership,
      'requiredRole': requiredRole,
      'tags': tags,
      'searchKeywords': searchKeywords,
      'sortOrder': sortOrder,
    };
  }
}
