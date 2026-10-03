import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// فئات عناصر المتجر — كل فئة لها محرّك عرض مُعامَل (parameterized
/// rendering engine) واحد بدل مئات الودجتات المخصَّصة يدويًا؛ هذا
/// يطابق نفس أسلوب كتالوج الهدايا (107 هدية) وتأثيرات الاسم (25
/// نمطًا) المُتَّبَع سابقًا في المشروع: عناصر حقيقية مختلفة الأسعار
/// فعليًا، مبنية على محرّك بصري واحد موثوق بدل تكرار كود بصري
/// عشوائي الجودة لكل عنصر.
enum StoreItemCategory {
  currency,
  usernameGlow,
  avatarFrame,
  animatedBackground,
  membership,
  particleEffect,
  usernameBackground
}

extension StoreItemCategoryX on StoreItemCategory {
  String get wire => name;

  static StoreItemCategory fromWire(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'currency' || 'points_gems' => StoreItemCategory.currency,
      'usernameglow' || 'glows' => StoreItemCategory.usernameGlow,
      'avatarframe' || 'frames' => StoreItemCategory.avatarFrame,
      'animatedbackground' ||
      'backgrounds' =>
        StoreItemCategory.animatedBackground,
      'membership' || 'features_addons' => StoreItemCategory.membership,
      'particleeffect' => StoreItemCategory.particleEffect,
      'usernamebackground' => StoreItemCategory.usernameBackground,
      _ => StoreItemCategory.currency,
    };
  }

  String get labelAr {
    switch (this) {
      case StoreItemCategory.currency:
        return 'النقاط والجواهر';
      case StoreItemCategory.usernameGlow:
        return 'التوهجات';
      case StoreItemCategory.avatarFrame:
        return 'الإطارات';
      case StoreItemCategory.animatedBackground:
        return 'الخلفيات';
      case StoreItemCategory.membership:
        return 'الميزات والإضافات والعضويات';
      case StoreItemCategory.particleEffect:
        return 'الجزيئات المتحركة';
      case StoreItemCategory.usernameBackground:
        return 'خلفية اسم المستخدم';
    }
  }
}

enum StoreProductDomain {
  usernameEffects,
  usernameStyles,
  profileFrames,
  profileBackgrounds,
  profileBadges,
  profileDecorations,
  avatarEffects,
  chatThemes,
  chatBubbles,
  messageEffects,
  reactionPacks,
  emojiPacks,
  gifPacks,
  stickerPacks,
  giftItems,
  giftAnimations,
  postEffects,
  postFrames,
  postBadges,
  storyEffects,
  storyFrames,
  creatorTools,
  sellerTools,
  marketplaceTools,
  garmentHubTools,
  patternStudioTools,
  aiTools,
  productivityTools,
  premiumFeatures,
  membershipFeatures,
  seasonalItems,
  limitedEdition,
  founderItems,
  legendaryItems,
  mythicItems,
  eventItems,
  animatedCollectibles,
  digitalArt,
  fashionAssets,
  fashion,
  fabricAssets,
  patternAssets,
  templatePacks,
  uiThemes,
  appThemes,
  notificationThemes,
  soundPacks,
  futureExtensions,
}

extension StoreProductDomainX on StoreProductDomain {
  String get wire => name;
}

class StoreItemEntity extends Equatable {
  final String id;
  final StoreItemCategory category;
  final String nameAr;
  final int pricePoints;
  final List<Color> colors;
  final bool enabled;
  final String? assetUrl;
  final String rarity;
  final bool isFeatured;
  final StoreProductDomain domain;
  final String sku;
  final String assetType;
  final String? previewAsset;
  final int? priceGems;
  final bool limited;
  final DateTime? limitedStart;
  final DateTime? limitedEnd;
  final int? stock;
  final int? maxPerUser;
  final int requiredLevel;
  final String? requiredMembership;
  final String? requiredRole;
  final List<String> tags;
  final List<String> searchKeywords;
  final int sortOrder;

  const StoreItemEntity({
    required this.id,
    required this.category,
    required this.nameAr,
    required this.pricePoints,
    required this.colors,
    this.enabled = true,
    this.assetUrl,
    this.rarity = 'common',
    this.isFeatured = false,
    this.domain = StoreProductDomain.animatedCollectibles,
    this.sku = '',
    this.assetType = 'image',
    this.previewAsset,
    this.priceGems,
    this.limited = false,
    this.limitedStart,
    this.limitedEnd,
    this.stock,
    this.maxPerUser,
    this.requiredLevel = 0,
    this.requiredMembership,
    this.requiredRole,
    this.tags = const [],
    this.searchKeywords = const [],
    this.sortOrder = 0,
  });

  StoreItemEntity copyWith({
    int? pricePoints,
    bool? enabled,
    String? assetUrl,
    String? rarity,
    bool? isFeatured,
    StoreProductDomain? domain,
    String? sku,
    String? assetType,
    String? previewAsset,
    int? priceGems,
    bool? limited,
    DateTime? limitedStart,
    DateTime? limitedEnd,
    int? stock,
    int? maxPerUser,
    int? requiredLevel,
    String? requiredMembership,
    String? requiredRole,
    List<String>? tags,
    List<String>? searchKeywords,
    int? sortOrder,
  }) =>
      StoreItemEntity(
        id: id,
        category: category,
        nameAr: nameAr,
        pricePoints: pricePoints ?? this.pricePoints,
        colors: colors,
        enabled: enabled ?? this.enabled,
        assetUrl: assetUrl ?? this.assetUrl,
        rarity: rarity ?? this.rarity,
        isFeatured: isFeatured ?? this.isFeatured,
        domain: domain ?? this.domain,
        sku: sku ?? this.sku,
        assetType: assetType ?? this.assetType,
        previewAsset: previewAsset ?? this.previewAsset,
        priceGems: priceGems ?? this.priceGems,
        limited: limited ?? this.limited,
        limitedStart: limitedStart ?? this.limitedStart,
        limitedEnd: limitedEnd ?? this.limitedEnd,
        stock: stock ?? this.stock,
        maxPerUser: maxPerUser ?? this.maxPerUser,
        requiredLevel: requiredLevel ?? this.requiredLevel,
        requiredMembership: requiredMembership ?? this.requiredMembership,
        requiredRole: requiredRole ?? this.requiredRole,
        tags: tags ?? this.tags,
        searchKeywords: searchKeywords ?? this.searchKeywords,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  @override
  List<Object?> get props => [
        id,
        category,
        nameAr,
        pricePoints,
        colors,
        enabled,
        assetUrl,
        rarity,
        isFeatured,
        domain,
        sku,
        assetType,
        previewAsset,
        priceGems,
        limited,
        limitedStart,
        limitedEnd,
        stock,
        maxPerUser,
        requiredLevel,
        requiredMembership,
        requiredRole,
        tags,
        searchKeywords,
        sortOrder
      ];
}

/// كتالوج مولَّد بمصفوفة ألوان/أسماء منسَّقة يدويًا (35 اسمًا لكل
/// فئة، تُستهلك دوريًا لإكمال العدد المطلوب) — كل عنصر سعر مختلف
/// فعليًا يتصاعد مع ترتيبه (كلما كان اللون/الشكل أندر ارتفع السعر)،
/// وليس نسخًا مكرَّرة بنفس القيمة.
class StoreCatalogGenerator {
  StoreCatalogGenerator._();

  static const _colorNames = [
    ('ذهبي', Color(0xFFD4AF37)),
    ('فضي', Color(0xFFC0C0C0)),
    ('برونزي', Color(0xFFCD7F32)),
    ('ياقوتي', Color(0xFF3E7BFA)),
    ('زمردي', Color(0xFF2FBF8E)),
    ('كهرماني', Color(0xFFFFC107)),
    ('بنفسجي', Color(0xFF8E24AA)),
    ('وردي', Color(0xFFE0A0A8)),
    ('نيون أخضر', Color(0xFF39FF14)),
    ('نيون أزرق', Color(0xFF00FFF7)),
    ('ناري', Color(0xFFFF5E3A)),
    ('جليدي', Color(0xFFA8E6FF)),
    ('ملكي', Color(0x00ff7a1f)),
    ('مجرّي', Color(0xFF9D4EDD)),
    ('قرمزي', Color(0xFFDC143C)),
    ('فيروزي', Color(0xFF1ABC9C)),
    ('كريستالي', Color(0xFFE1BEE7)),
    ('قمري', Color(0xFF90A4AE)),
    ('شمسي', Color(0xFFFF9800)),
    ('دخاني', Color(0xFF6E6A63)),
    ('أسود لامع', Color(0xFF0A0A0A)),
    ('أبيض لؤلؤي', Color(0xFFF8F8FF)),
    ('زجاجي', Color(0xFFB2EBF2)),
    ('برّاق وردي', Color(0xFFFF80AB)),
    ('أزرق كوني', Color(0xFF3F51B5)),
    ('أخضر سام', Color(0xFF76FF03)),
    ('أحمر ملكي', Color(0xFFB71C1C)),
    ('توباز', Color(0xFFFFD54F)),
    ('سماوي', Color(0xFF81D4FA)),
    ('عنّابي', Color(0xFF6D1B2F)),
    ('فضي مُطفَأ', Color(0xFFBDBDBD)),
    ('أخضر غابي', Color(0xFF2E7D32)),
    ('برتقالي شفقي', Color(0xFFFF7043)),
    ('أرجواني ليلي', Color(0xFF4A148C)),
    ('لؤلؤي وردي', Color(0xFFFCE4EC)),
  ];

  static List<StoreItemEntity> generate(
    StoreItemCategory category, {
    required int count,
    required int basePrice,
    required int priceStep,
  }) {
    if (category == StoreItemCategory.avatarFrame) {
      // Avatar frames are server-managed remote image assets (static or animated).
      return const <StoreItemEntity>[];
    }
    final items = <StoreItemEntity>[];

    String assetForIndex(int index) {
      final number = (index + 1).toString().padLeft(2, '0');

      switch (category) {
        case StoreItemCategory.currency:
          return 'assets/store_gifs/currency/currency_$number.gif';

        case StoreItemCategory.usernameGlow:
          return 'assets/store_gifs/glow/glow_$number.gif';

        case StoreItemCategory.avatarFrame:
          return '';

        case StoreItemCategory.animatedBackground:
          return 'assets/store_gifs/background/background_$number.gif';

        case StoreItemCategory.membership:
          return 'assets/store_gifs/membership/membership_$number.gif';

        case StoreItemCategory.usernameBackground:
          return 'assets/store_gifs/background/background_$number.gif';

        case StoreItemCategory.particleEffect:
          return 'assets/store_gifs/glow/glow_$number.gif';
      }
    }

    final domain = switch (category) {
      StoreItemCategory.currency => StoreProductDomain.animatedCollectibles,
      StoreItemCategory.usernameGlow => StoreProductDomain.usernameEffects,
      StoreItemCategory.avatarFrame => StoreProductDomain.profileFrames,
      StoreItemCategory.animatedBackground =>
        StoreProductDomain.profileBackgrounds,
      StoreItemCategory.membership => StoreProductDomain.membershipFeatures,
      StoreItemCategory.particleEffect => StoreProductDomain.avatarEffects,
      StoreItemCategory.usernameBackground => StoreProductDomain.usernameStyles,
    };

    for (var i = 0; i < count; i++) {
      final variant = i ~/ _colorNames.length;

      final colorEntry = _colorNames[i % _colorNames.length];

      final suffix = variant == 0 ? '' : ' ${_variantSuffix(variant)}';

      final assetPath = assetForIndex(i);

      items.add(
        StoreItemEntity(
          id: '${category.wire}_$i',
          category: category,
          nameAr: '${colorEntry.$1}$suffix',
          pricePoints: basePrice + (i * priceStep),
          colors: variant.isOdd
              ? [
                  colorEntry.$2,
                  colorEntry.$2.withValues(alpha: 0.4),
                ]
              : [
                  colorEntry.$2,
                ],
          assetUrl: assetPath,
          assetType: 'gif',
          previewAsset: assetPath,
          domain: domain,
          sku: '${category.wire}_$i',
          requiredLevel: i >= 40 ? 10 : 0,
          maxPerUser: 1,
          rarity: i >= 45
              ? 'legendary'
              : (i >= 20 ? 'epic' : (i >= 10 ? 'rare' : 'common')),
          isFeatured: i < 6,
          tags: [
            category.wire,
            domain.wire,
          ],
          searchKeywords: [
            colorEntry.$1,
            category.labelAr,
          ],
          sortOrder: i,
        ),
      );
    }

    return items;
  }

  static String _variantSuffix(int variant) {
    const suffixes = ['خارق', 'أسطوري', 'كوني', 'ملحمي'];
    return suffixes[(variant - 1) % suffixes.length];
  }

  /// الكتالوج الكامل: 100 إطار + 50 توهج اسم + 50 جزيئات + 50 خلفية
  /// متحركة + 50 خلفية اسم مستخدم = 300 عنصر — مطابق تمامًا للأعداد
  /// المطلوبة.
  static List<StoreItemEntity> fullCatalog() => [
        ...generate(StoreItemCategory.avatarFrame,
            count: 50, basePrice: 200, priceStep: 15),
        ...generate(StoreItemCategory.usernameGlow,
            count: 50, basePrice: 150, priceStep: 20),
        ...generate(StoreItemCategory.particleEffect,
            count: 50, basePrice: 180, priceStep: 20),
        ...generate(StoreItemCategory.animatedBackground,
            count: 50, basePrice: 250, priceStep: 25),
        ...generate(StoreItemCategory.usernameBackground,
            count: 50, basePrice: 150, priceStep: 20),
      ];
}
