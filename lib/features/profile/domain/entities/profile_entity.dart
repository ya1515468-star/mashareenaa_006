import 'package:equatable/equatable.dart';

enum ProfileVisibility { public, friends, private }

extension ProfileVisibilityX on ProfileVisibility {
  String get wire => name;

  static ProfileVisibility fromWire(String? s) =>
      ProfileVisibility.values.firstWhere(
        (e) => e.wire == s,
        orElse: () => ProfileVisibility.public,
      );
}

/// نوع الحساب — يميّز الحسابات الفردية عن الحسابات التجارية
/// (Factory, Workshop, Supplier, Business Owner...) بحسب المخطط
/// الرسمي لمجموعة accounts.
enum AccountType {
  individual,
  business,
  workshop,
  factory,
  supplier,
  store,
  designer,
  serviceProvider
}

extension AccountTypeX on AccountType {
  String get wire => switch (this) {
        AccountType.individual => 'individual',
        AccountType.business => 'business',
        AccountType.workshop => 'workshop',
        AccountType.factory => 'factory',
        AccountType.supplier => 'supplier',
        AccountType.store => 'store',
        AccountType.designer => 'designer',
        AccountType.serviceProvider => 'service_provider',
      };

  static AccountType fromWire(String? s) => AccountType.values.firstWhere(
        (e) => e.wire == s,
        orElse: () => AccountType.individual,
      );
}

/// رابط وسيلة تواصل اجتماعي واحد (مثل "Instagram: @user").
class SocialLink extends Equatable {
  final String platform;
  final String url;

  const SocialLink({required this.platform, required this.url});

  factory SocialLink.fromMap(Map<String, dynamic> m) => SocialLink(
      platform: m['platform'] as String? ?? '', url: m['url'] as String? ?? '');

  Map<String, dynamic> toMap() => {'platform': platform, 'url': url};

  @override
  List<Object?> get props => [platform, url];
}

/// كيان الملف الشخصي. مرتبط دائمًا بـ uid موحّد مع UserEntity من
/// وحدة Auth، وهو ما يضمن الترابط الكامل بين الوحدتين.
class ProfileEntity extends Equatable {
  final String uid;
  final String displayName;
  final String email;
  final String bio;
  final String? avatarUrl;
  final String? coverUrl;
  final String? statusText;
  final String? profileMusicUrl;
  final int? profileMusicDurationMs;
  final int? profileMusicSizeBytes;
  final String? country;
  final String? city;
  final String? profession;
  final List<String> experiences;
  final List<SocialLink> socialLinks;
  final bool verified;
  final ProfileVisibility visibility;
  final AccountType accountType;

  /// لون اسم المستخدم المخصّص (ARGB) — يُعرض بدل اللون الافتراضي إن
  /// كان مضبوطًا ولا يوجد تأثير رتبة/متجر له أولوية أعلى.
  final int? usernameColor;

  /// حجم اسم المستخدم المحفوظ على الخادم (14..34).
  final double usernameFontSize;

  /// عائلة خط اسم المستخدم العربي المحفوظة على الخادم.
  final String usernameFontFamily;

  /// عائلة خط رسائل المستخدم في الدردشة، محفوظة على الخادم.
  final String messageFontFamily;

  final int messageColor;

  /// حجم نص الحالة المحفوظ على الخادم (10..22).
  final double statusFontSize;

  /// تنسيق نص الحالة: عريض/مائل ولون مخصّص للفقاعة النصية.
  final bool statusBold;
  final bool statusItalic;
  final int? statusColor;

  /// رابط صورة شخصية متحركة (GIF/فيديو قصير) تُستخدم بدل الصورة
  /// الثابتة عند ضبطها؛ avatarUrl يبقى الاحتياطي دائمًا.
  final String? animatedAvatarUrl;

  /// مفتاح إطار الصورة المتحرك المحفوظ خادميًا.
  final String? avatarFrameKey;
  /// Standalone video-reference name template. Intentionally independent of UsernameEffect/VisualEffect.
  final String? usernameTemplateKey;

  /// التأثير الحركي الحالي لاسم المستخدم، مصدره الخادم.
  final String usernameEffect;

  /// مفتاح خلفية اسم المستخدم/المستطيل المتحرك.
  final String? usernameBackgroundKey;
  final String? usernameBackgroundMode;
  final String? usernameBackgroundColor1;
  final String? usernameBackgroundColor2;
  final double usernameBackgroundOpacity;
  final String? usernameBackgroundExternalEffect;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileEntity({
    required this.uid,
    required this.displayName,
    required this.email,
    this.bio = '',
    this.avatarUrl,
    this.coverUrl,
    this.statusText,
    this.profileMusicUrl,
    this.profileMusicDurationMs,
    this.profileMusicSizeBytes,
    this.country,
    this.city,
    this.profession,
    this.experiences = const [],
    this.socialLinks = const [],
    this.verified = false,
    this.visibility = ProfileVisibility.public,
    this.accountType = AccountType.individual,
    this.usernameColor,
    this.usernameFontSize = 12,
    this.usernameFontFamily = '',
    this.messageFontFamily = '',
    this.messageColor = 4294967295,
    this.statusFontSize = 12.5,
    this.statusBold = false,
    this.statusItalic = false,
    this.statusColor,
    this.animatedAvatarUrl,
    this.avatarFrameKey,
    this.usernameTemplateKey,
    this.usernameEffect = 'none',
    this.usernameBackgroundKey,
    this.usernameBackgroundMode,
    this.usernameBackgroundColor1,
    this.usernameBackgroundColor2,
    this.usernameBackgroundOpacity = .82,
    this.usernameBackgroundExternalEffect,
    required this.createdAt,
    required this.updatedAt,
  });

  ProfileEntity copyWith({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    String? statusText,
    String? profileMusicUrl,
    int? profileMusicDurationMs,
    int? profileMusicSizeBytes,
    String? country,
    String? city,
    String? profession,
    List<String>? experiences,
    List<SocialLink>? socialLinks,
    ProfileVisibility? visibility,
    AccountType? accountType,
    int? usernameColor,
    double? usernameFontSize,
    String? usernameFontFamily,
    String? messageFontFamily,
    int? messageColor,
    double? statusFontSize,
    bool? statusBold,
    bool? statusItalic,
    int? statusColor,
    String? animatedAvatarUrl,
    String? avatarFrameKey,
    String? usernameTemplateKey,
    String? usernameEffect,
    String? usernameBackgroundKey,
    String? usernameBackgroundMode,
    String? usernameBackgroundColor1,
    String? usernameBackgroundColor2,
    double? usernameBackgroundOpacity,
    String? usernameBackgroundExternalEffect,
    DateTime? updatedAt,
  }) {
    return ProfileEntity(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      statusText: statusText ?? this.statusText,
      profileMusicUrl: profileMusicUrl ?? this.profileMusicUrl,
      profileMusicDurationMs:
          profileMusicDurationMs ?? this.profileMusicDurationMs,
      profileMusicSizeBytes:
          profileMusicSizeBytes ?? this.profileMusicSizeBytes,
      country: country ?? this.country,
      city: city ?? this.city,
      profession: profession ?? this.profession,
      experiences: experiences ?? this.experiences,
      socialLinks: socialLinks ?? this.socialLinks,
      verified: verified,
      visibility: visibility ?? this.visibility,
      accountType: accountType ?? this.accountType,
      usernameColor: usernameColor ?? this.usernameColor,
      usernameFontSize: usernameFontSize ?? this.usernameFontSize,
      usernameFontFamily: usernameFontFamily ?? this.usernameFontFamily,
      messageFontFamily: messageFontFamily ?? this.messageFontFamily,
      messageColor: messageColor ?? this.messageColor,
      statusFontSize: statusFontSize ?? this.statusFontSize,
      statusBold: statusBold ?? this.statusBold,
      statusItalic: statusItalic ?? this.statusItalic,
      statusColor: statusColor ?? this.statusColor,
      animatedAvatarUrl: animatedAvatarUrl ?? this.animatedAvatarUrl,
      avatarFrameKey: avatarFrameKey ?? this.avatarFrameKey,
      usernameTemplateKey: usernameTemplateKey ?? this.usernameTemplateKey,
      usernameEffect: usernameEffect ?? this.usernameEffect,
      usernameBackgroundKey: usernameBackgroundKey ?? this.usernameBackgroundKey,
      usernameBackgroundMode: usernameBackgroundMode ?? this.usernameBackgroundMode,
      usernameBackgroundColor1: usernameBackgroundColor1 ?? this.usernameBackgroundColor1,
      usernameBackgroundColor2: usernameBackgroundColor2 ?? this.usernameBackgroundColor2,
      usernameBackgroundOpacity: usernameBackgroundOpacity ?? this.usernameBackgroundOpacity,
      usernameBackgroundExternalEffect: usernameBackgroundExternalEffect ?? this.usernameBackgroundExternalEffect,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        displayName,
        email,
        bio,
        avatarUrl,
        coverUrl,
        statusText,
        profileMusicUrl,
        profileMusicDurationMs,
        profileMusicSizeBytes,
        country,
        city,
        profession,
        experiences,
        socialLinks,
        verified,
        visibility,
        accountType,
        usernameColor,
        usernameFontSize,
        usernameFontFamily,
        messageFontFamily,
        statusFontSize,
        statusBold,
        statusItalic,
        statusColor,
        animatedAvatarUrl,
        avatarFrameKey,
        usernameTemplateKey,
        usernameEffect,
        usernameBackgroundKey,
        usernameBackgroundMode,
        usernameBackgroundColor1,
        usernameBackgroundColor2,
        usernameBackgroundOpacity,
        usernameBackgroundExternalEffect,
        createdAt,
        updatedAt,
      ];
}
