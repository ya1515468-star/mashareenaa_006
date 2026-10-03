import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../gamification/domain/entities/username_effect.dart';
import '../../../wallet/domain/entities/currency.dart';

/// شارة العضوية — الوسم الصغير الذي يظهر بجانب اسم العضو في
/// الدردشة والبروفايل (بنفس فكرة شارات "شات ملكي / شات ليالينا" في
/// تطبيقات الدردشة العربية الشهيرة)، بأيقونة/إيموجي مميز ولون خاص
/// بكل عضوية.
class MembershipBadge extends Equatable {
  final String emoji;

  /// صورة شارة يرفعها المالك لهذا المستوى (bucket: tier-badges).
  /// تسبق الإيموجي في العرض حين تكون موجودة، وتحلّ محلّ النجمة ⭐
  /// الافتراضية التي كانت الخيار الوحيد.
  final String? imageUrl;
  final String labelAr;
  final Color color;

  const MembershipBadge(
      {required this.emoji, required this.labelAr, required this.color,
      this.imageUrl});

  @override
  List<Object?> get props => [emoji, labelAr, color, imageUrl];
}

/// مزايا العضوية الفعلية — كل حقل هنا يُفرض في مكانه المناسب من
/// التطبيق (وليس وصفًا تسويقيًا فقط):
/// - profileMusic/animatedProfilePhoto/profileBackground/avatarFrame/
///   animatedSmileyNextToName: تُفعَّل في شاشة البروفايل.
/// - canCreateAds: تتحقق منها وحدة الإعلانات المموّلة قبل السماح
///   بإنشاء إعلان.
/// - canHideOnlineStatus: تتحقق منها خدمة الحضور (Presence) قبل بث
///   isOnline=true فعليًا للآخرين.
class MembershipFeatures extends Equatable {
  final bool profileMusic;
  final bool animatedProfilePhoto;
  final bool profileBackground;
  final bool avatarFrame;
  final bool animatedSmileyNextToName;
  final bool canCreateAds;
  final bool canHideOnlineStatus;

  const MembershipFeatures({
    this.profileMusic = false,
    this.animatedProfilePhoto = false,
    this.profileBackground = false,
    this.avatarFrame = false,
    this.animatedSmileyNextToName = false,
    this.canCreateAds = false,
    this.canHideOnlineStatus = false,
  });

  /// يُبنى من نتيجة get_membership_tier_features — الدالة الخادمية
  /// الوحيدة المخوَّلة بحل مزايا أي عضوية، ثابتة أو مخصصة. سابقًا كانت
  /// المزايا الفعلية تُحسب محليًا بمطابقة رقم تعريف العضوية مع خمس
  /// قوالب ثابتة فقط؛ أي عضوية بمعرِّف آخر (كل عضوية يُنشئها المالك
  /// عبر محرر العضويات) كانت تفشل المطابقة وتتحول صمتًا إلى صفر مزايا
  /// — أي أن المشترك في عضوية مخصصة لا يحصل على شيء يدفع ثمنه فعليًا.
  factory MembershipFeatures.fromMap(Map<String, dynamic> map) => MembershipFeatures(
        profileMusic: map['profileMusic'] == true,
        animatedProfilePhoto: map['animatedProfilePhoto'] == true,
        profileBackground: map['profileBackground'] == true,
        avatarFrame: map['avatarFrame'] == true,
        animatedSmileyNextToName: map['animatedSmileyNextToName'] == true,
        canCreateAds: map['canCreateAds'] == true,
        canHideOnlineStatus: map['canHideOnlineStatus'] == true,
      );

  @override
  List<Object?> get props => [
        profileMusic,
        animatedProfilePhoto,
        profileBackground,
        avatarFrame,
        animatedSmileyNextToName,
        canCreateAds,
        canHideOnlineStatus,
      ];

  /// يدمج مزايا العضوية الأساسية مع خريطة تجاوزات (Overrides) خاصة
  /// بحساب معيّن — أي مفتاح موجود في الخريطة يطغى على قيمة العضوية،
  /// وأي مفتاح غائب يبقى بقيمة العضوية كما هي.
  MembershipFeatures mergeOverrides(Map<String, bool> overrides) {
    return MembershipFeatures(
      profileMusic:
          overrides[MembershipFeatureKeys.profileMusic] ?? profileMusic,
      animatedProfilePhoto:
          overrides[MembershipFeatureKeys.animatedProfilePhoto] ??
              animatedProfilePhoto,
      profileBackground: overrides[MembershipFeatureKeys.profileBackground] ??
          profileBackground,
      avatarFrame: overrides[MembershipFeatureKeys.avatarFrame] ?? avatarFrame,
      animatedSmileyNextToName:
          overrides[MembershipFeatureKeys.animatedSmileyNextToName] ??
              animatedSmileyNextToName,
      canCreateAds:
          overrides[MembershipFeatureKeys.canCreateAds] ?? canCreateAds,
      canHideOnlineStatus:
          overrides[MembershipFeatureKeys.canHideOnlineStatus] ??
              canHideOnlineStatus,
    );
  }

  static const MembershipFeatures allEnabled = MembershipFeatures(
    profileMusic: true,
    animatedProfilePhoto: true,
    profileBackground: true,
    avatarFrame: true,
    animatedSmileyNextToName: true,
    canCreateAds: true,
    canHideOnlineStatus: true,
  );
}

class MembershipFeatureKeys {
  MembershipFeatureKeys._();
  static const profileMusic = 'profileMusic';
  static const animatedProfilePhoto = 'animatedProfilePhoto';
  static const profileBackground = 'profileBackground';
  static const avatarFrame = 'avatarFrame';
  static const animatedSmileyNextToName = 'animatedSmileyNextToName';
  static const canCreateAds = 'canCreateAds';
  static const canHideOnlineStatus = 'canHideOnlineStatus';

  static const List<String> all = [
    profileMusic,
    animatedProfilePhoto,
    profileBackground,
    avatarFrame,
    animatedSmileyNextToName,
    canCreateAds,
    canHideOnlineStatus,
  ];
}

class SubscriptionTierEntity extends Equatable {
  final String id;
  final String name;
  final String description;
  final Money price;
  final int durationDays;
  final List<UsernameEffect> unlockedEffects;
  final int dailyRewardMultiplier;
  final MembershipBadge badge;
  final MembershipFeatures features;
  /// One-time grants on purchase (spec 8.2) — separate from [features],
  /// which stay tied to the subscription's own active/expired state.
  final int pointsGranted;
  final int gemsGranted;
  final List<String> grantedCosmeticKeys;
  final List<String> grantedAnimationKeys;
  /// VIP service feature_keys this tier grants on purchase/gift — resolved
  /// server-side in purchase_membership / admin_grant_membership_tier.
  final List<String> grantedServiceKeys;
  final bool enabled;
  final int displayOrder;
  final bool trial;
  final int trialDays;
  final bool autoRenew;
  final int level;
  final int unlockedServiceCount;

  const SubscriptionTierEntity({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    required this.durationDays,
    required this.unlockedEffects,
    required this.dailyRewardMultiplier,
    required this.badge,
    this.features = const MembershipFeatures(),
    this.pointsGranted = 0,
    this.gemsGranted = 0,
    this.grantedCosmeticKeys = const [],
    this.grantedAnimationKeys = const [],
    this.grantedServiceKeys = const [],
    this.enabled = true,
    this.displayOrder = 0,
    this.trial = false,
    this.trialDays = 0,
    this.autoRenew = false,
    this.level = 1,
    this.unlockedServiceCount = 0,
  });

  bool get isFree => price.minorUnits == 0;
  bool get hasOneTimeGrants =>
      pointsGranted > 0 || gemsGranted > 0 || grantedCosmeticKeys.isNotEmpty || grantedAnimationKeys.isNotEmpty || grantedServiceKeys.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        name,
        price,
        durationDays,
        unlockedEffects,
        dailyRewardMultiplier,
        badge,
        features,
        pointsGranted,
        gemsGranted,
        grantedCosmeticKeys,
        grantedAnimationKeys,
        grantedServiceKeys,
        enabled,
        displayOrder,
        trial,
        trialDays,
        autoRenew,
        level,
        unlockedServiceCount,
      ];
}

/// كتالوج العضويات الثماني — مرتَّبة تصاعديًا، كل عضوية تضيف فرقًا
/// حقيقيًا واضحًا عن التي تسبقها (سعرًا ومزايا معًا)، بحيث يختار كل
/// مستخدم حسب حاجته الفعلية. الأسعار بوحدة شام كاش الصغرى
/// (minorUnits)، والمدة 30 يومًا لكل مستوى مدفوع.
class SubscriptionCatalog {
  SubscriptionCatalog._();

  static const String freeTierId = 'free';

  static const SubscriptionTierEntity free = SubscriptionTierEntity(
    id: freeTierId,
    name: 'مجاني',
    price: Money(minorUnits: 0, currency: Currency.shamCash),
    durationDays: 0,
    unlockedEffects: [UsernameEffect.none],
    dailyRewardMultiplier: 1,
    badge: MembershipBadge(emoji: '', labelAr: '', color: Color(0xFF6E6A63)),
  );

  static const SubscriptionTierEntity bronze = SubscriptionTierEntity(
    id: 'bronze',
    name: 'البرونزية',
    price: Money(minorUnits: 5000, currency: Currency.shamCash),
    durationDays: 30,
    unlockedEffects: [
      UsernameEffect.none,
      UsernameEffect.bronze,
      UsernameEffect.smoke
    ],
    dailyRewardMultiplier: 1,
    badge: MembershipBadge(
        emoji: '🥉', labelAr: 'عضو برونزي', color: Color(0xFFCD7F32)),
    features: MembershipFeatures(avatarFrame: true),
  );

  static const SubscriptionTierEntity silver = SubscriptionTierEntity(
    id: 'silver',
    name: 'الفضية',
    price: Money(minorUnits: 10000, currency: Currency.shamCash),
    durationDays: 30,
    unlockedEffects: [
      UsernameEffect.none,
      UsernameEffect.bronze,
      UsernameEffect.silver,
      UsernameEffect.ice,
      UsernameEffect.glass,
    ],
    dailyRewardMultiplier: 2,
    badge: MembershipBadge(
        emoji: '🥈', labelAr: 'عضو فضي', color: Color(0xFFC0C0C0)),
    features:
        MembershipFeatures(avatarFrame: true, animatedSmileyNextToName: true),
  );

  static const SubscriptionTierEntity gold = SubscriptionTierEntity(
    id: 'gold',
    name: 'الذهبية',
    price: Money(minorUnits: 15000, currency: Currency.shamCash),
    durationDays: 30,
    unlockedEffects: [
      UsernameEffect.none,
      UsernameEffect.fire,
      UsernameEffect.gold,
      UsernameEffect.amber,
      UsernameEffect.bronze,
      UsernameEffect.silver,
    ],
    dailyRewardMultiplier: 2,
    badge: MembershipBadge(
        emoji: '🏅', labelAr: 'عضو ذهبي', color: Color(0xFFD4AF37)),
    features: MembershipFeatures(
      avatarFrame: true,
      animatedSmileyNextToName: true,
      profileBackground: true,
    ),
  );

  static const SubscriptionTierEntity diamond = SubscriptionTierEntity(
    id: 'diamond',
    name: 'الماسية',
    price: Money(minorUnits: 22000, currency: Currency.shamCash),
    durationDays: 30,
    unlockedEffects: [
      UsernameEffect.none,
      UsernameEffect.fire,
      UsernameEffect.thunder,
      UsernameEffect.gold,
      UsernameEffect.diamond,
      UsernameEffect.crystal,
      UsernameEffect.sapphire,
    ],
    dailyRewardMultiplier: 3,
    badge: MembershipBadge(
        emoji: '💎', labelAr: 'عضو ماسي', color: Color(0xFFB9F2FF)),
    features: MembershipFeatures(
      avatarFrame: true,
      animatedSmileyNextToName: true,
      profileBackground: true,
      animatedProfilePhoto: true,
    ),
  );

  static const SubscriptionTierEntity royal = SubscriptionTierEntity(
    id: 'royal',
    name: 'الملكية',
    price: Money(minorUnits: 30000, currency: Currency.shamCash),
    durationDays: 30,
    unlockedEffects: [
      UsernameEffect.none,
      UsernameEffect.fire,
      UsernameEffect.thunder,
      UsernameEffect.gold,
      UsernameEffect.royal,
      UsernameEffect.royalBlue,
      UsernameEffect.violet,
      UsernameEffect.emerald,
    ],
    dailyRewardMultiplier: 4,
    badge: MembershipBadge(
        emoji: '👑', labelAr: 'عضو ملكي', color: Color(0xFF7A1F3D)),
    features: MembershipFeatures(
      avatarFrame: true,
      animatedSmileyNextToName: true,
      profileBackground: true,
      animatedProfilePhoto: true,
      profileMusic: true,
      canHideOnlineStatus: true,
    ),
  );

  static const SubscriptionTierEntity vip = SubscriptionTierEntity(
    id: 'vip',
    name: 'VIP',
    price: Money(minorUnits: 40000, currency: Currency.shamCash),
    durationDays: 30,
    unlockedEffects: [
      UsernameEffect.none,
      UsernameEffect.fire,
      UsernameEffect.thunder,
      UsernameEffect.gold,
      UsernameEffect.royal,
      UsernameEffect.vip,
      UsernameEffect.neon,
      UsernameEffect.galaxy,
      UsernameEffect.rainbow,
    ],
    dailyRewardMultiplier: 5,
    badge:
        MembershipBadge(emoji: '⭐', labelAr: 'VIP', color: Color(0xFFFFD700)),
    features: MembershipFeatures(
      avatarFrame: true,
      animatedSmileyNextToName: true,
      profileBackground: true,
      animatedProfilePhoto: true,
      profileMusic: true,
      canHideOnlineStatus: true,
      canCreateAds: true,
    ),
  );

  static const SubscriptionTierEntity legendary = SubscriptionTierEntity(
    id: 'legendary',
    name: 'النخبة الأسطورية',
    price: Money(minorUnits: 60000, currency: Currency.shamCash),
    durationDays: 30,
    unlockedEffects: [
      UsernameEffect.none,
      UsernameEffect.fire,
      UsernameEffect.thunder,
      UsernameEffect.gold,
      UsernameEffect.royal,
      UsernameEffect.vip,
      UsernameEffect.neon,
      UsernameEffect.galaxy,
      UsernameEffect.rainbow,
      UsernameEffect.lightning,
      UsernameEffect.lunar,
      UsernameEffect.solar,
    ],
    dailyRewardMultiplier: 6,
    badge: MembershipBadge(
        emoji: '🔥', labelAr: 'نخبة أسطورية', color: Color(0xFFFF5E3A)),
    features: MembershipFeatures(
      profileMusic: true,
      animatedProfilePhoto: true,
      profileBackground: true,
      avatarFrame: true,
      animatedSmileyNextToName: true,
      canCreateAds: true,
      canHideOnlineStatus: true,
    ),
  );

  static const SubscriptionTierEntity ultimate = SubscriptionTierEntity(
    id: 'ultimate',
    name: 'Ultimate',
    price: Money(minorUnits: 85000, currency: Currency.shamCash),
    durationDays: 30,
    unlockedEffects: [
      UsernameEffect.none,
      UsernameEffect.rainbow,
      UsernameEffect.galaxy,
      UsernameEffect.lightning,
      UsernameEffect.solar
    ],
    dailyRewardMultiplier: 8,
    badge: MembershipBadge(
        emoji: '🐉', labelAr: 'Ultimate', color: Color(0xFF9B59FF)),
    features: MembershipFeatures.allEnabled,
  );

  static const List<SubscriptionTierEntity> paidTiers = [
    bronze,
    silver,
    gold,
    diamond,
    royal,
    vip,
    legendary,
    ultimate,
  ];

  static const List<SubscriptionTierEntity> all = [free, ...paidTiers];

  static SubscriptionTierEntity? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}
