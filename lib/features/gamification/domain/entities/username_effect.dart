import 'package:flutter/material.dart';

/// 100 تأثير فعلي متحرك لاسم المستخدم، مولّدة من محركات حركة Flutter داخلية ولوحات ألوان متعددة،
/// مع الحفاظ على جميع التأثيرات السابقة وتوسيعها إلى 100 نمط. كل تأثير له لون/تدرج تمثيلي تستخدمه [UsernameEffectText]
/// لعرض الاسم بأسلوبه الفعلي في الواجهة. الملكية والصلاحية يتحققان خادميًا
/// عبر RPC `set_username_effect` (فحص ملكية حقيقي عبر جدول المشتريات)، وليس
/// من قيمة رتبة محلية في العميل. تأثير [dragonFire] حصري لحساب DRAGON نفسه
/// فقط (راجع [UsernameEffectX.isDragonExclusive]).
enum UsernameEffect {
  none,
  fire,
  thunder,
  gold,
  royal,
  vip,
  camouflage,
  ice,
  diamond,
  neon,
  galaxy,
  rainbow,
  smoke,
  lightning,
  glass,
  crystal,
  rose,
  royalBlue,
  matteBlack,
  silver,
  bronze,
  emerald,
  sapphire,
  amber,
  violet,
  lunar,
  solar,
  coral,
  magenta,
  obsidian,
  platinum,
  jade,
  ruby,
  cobalt,
  sunset,
  aurora,
  phoenix,
  storm,
  mystic,
  venom,
  frost,
  blaze,
  cosmic,
  shadow,
  prism,
  mercury,
  titanium,
  opal,
  garnet,
  dragonFire,
  ember,
  inferno,
  flameGold,
  wildfire,
  molten,
  ashGlow,
  sunFlare,
  lava,
  firestorm,
  hellfire,
  plasma,
  electricBlue,
  electricPurple,
  laser,
  hologram,
  glitch,
  scanline,
  pixel,
  chroma,
  spectrum,
  prismGlow,
  ocean,
  deepSea,
  aqua,
  wave,
  tidal,
  arctic,
  snowSpark,
  iceCrystal,
  winterMoon,
  starlight,
  starBurst,
  nebula,
  universe,
  galaxyPink,
  comet,
  meteor,
  cosmicDust,
  auroraPink,
  auroraGreen,
  velvet,
  amethyst,
  roseGold,
  hotPink,
  rubyGlow,
  emeraldGlow,
  sapphireGlow,
  pearl,
  moonstone,
  candyNeon,
  toxicGreen,
}

/// مستوى ندرة التأثير — يُستخدم لتصنيف عرضه في المتجر/شاشة الاختيار
/// (Common أبسط أدوات العرض، Exclusive لا يُمنح إلا يدويًا).
enum UsernameEffectRarity { common, rare, epic, legendary, exclusive }

extension UsernameEffectX on UsernameEffect {
  String get wire => name;

  static UsernameEffect fromWire(String? s) => UsernameEffect.values.firstWhere(
        (e) => e.wire == s,
        orElse: () => UsernameEffect.none,
      );

  bool get isFree => this == UsernameEffect.none;

  /// حصري لحساب DRAGON — لا يُفتح بمستوى رتبة ولا بعضوية مهما
  /// ارتفعت، فقط منحًا يدويًا مباشرًا (وDRAGON نفسه يملكه دائمًا عبر
  /// unlimited_resources).
  bool get isDragonExclusive => this == UsernameEffect.dragonFire;

  UsernameEffectRarity get rarity {
    if (isDragonExclusive) return UsernameEffectRarity.exclusive;
    final index = UsernameEffect.values.indexOf(this);
    if (index == 0) return UsernameEffectRarity.common;
    if (index <= 12) return UsernameEffectRarity.common;
    if (index <= 26) return UsernameEffectRarity.rare;
    if (index <= 39) return UsernameEffectRarity.epic;
    return UsernameEffectRarity.legendary;
  }

  String get labelAr {
    switch (this) {
      case UsernameEffect.none:
        return 'بلا تأثير';
      case UsernameEffect.fire:
        return 'نار';
      case UsernameEffect.thunder:
        return 'رعد';
      case UsernameEffect.gold:
        return 'ذهبي';
      case UsernameEffect.royal:
        return 'ملكي';
      case UsernameEffect.vip:
        return 'VIP';
      case UsernameEffect.camouflage:
        return 'تمويه';
      case UsernameEffect.ice:
        return 'جليدي';
      case UsernameEffect.diamond:
        return 'ماسي';
      case UsernameEffect.neon:
        return 'نيون';
      case UsernameEffect.galaxy:
        return 'مجرّي';
      case UsernameEffect.rainbow:
        return 'قوس قزح';
      case UsernameEffect.smoke:
        return 'دخاني';
      case UsernameEffect.lightning:
        return 'برق';
      case UsernameEffect.glass:
        return 'زجاجي';
      case UsernameEffect.crystal:
        return 'كريستالي';
      case UsernameEffect.rose:
        return 'وردي';
      case UsernameEffect.royalBlue:
        return 'أزرق ملكي';
      case UsernameEffect.matteBlack:
        return 'أسود لامع';
      case UsernameEffect.silver:
        return 'فضي';
      case UsernameEffect.bronze:
        return 'برونزي';
      case UsernameEffect.emerald:
        return 'زمردي';
      case UsernameEffect.sapphire:
        return 'ياقوتي';
      case UsernameEffect.amber:
        return 'كهرماني';
      case UsernameEffect.violet:
        return 'بنفسجي';
      case UsernameEffect.lunar:
        return 'قمري';
      case UsernameEffect.solar:
        return 'شمسي';
      case UsernameEffect.coral:
        return 'مرجاني';
      case UsernameEffect.magenta:
        return 'أرجواني فاقع';
      case UsernameEffect.obsidian:
        return 'سبج بركاني';
      case UsernameEffect.platinum:
        return 'بلاتيني';
      case UsernameEffect.jade:
        return 'يشم';
      case UsernameEffect.ruby:
        return 'ياقوت أحمر';
      case UsernameEffect.cobalt:
        return 'كوبالتي';
      case UsernameEffect.sunset:
        return 'غروب';
      case UsernameEffect.aurora:
        return 'شفق قطبي';
      case UsernameEffect.phoenix:
        return 'العنقاء';
      case UsernameEffect.storm:
        return 'عاصفة';
      case UsernameEffect.mystic:
        return 'غامض';
      case UsernameEffect.venom:
        return 'سام';
      case UsernameEffect.frost:
        return 'صقيعي';
      case UsernameEffect.blaze:
        return 'لهيب';
      case UsernameEffect.cosmic:
        return 'كوني';
      case UsernameEffect.shadow:
        return 'ظلّي';
      case UsernameEffect.prism:
        return 'منشوري';
      case UsernameEffect.mercury:
        return 'زئبقي';
      case UsernameEffect.titanium:
        return 'تيتانيومي';
      case UsernameEffect.opal:
        return 'أوبال';
      case UsernameEffect.garnet:
        return 'عقيق';
      case UsernameEffect.dragonFire:
        return 'نار التنين 🐉';
      case UsernameEffect.ember:
        return 'جمرة';
      case UsernameEffect.inferno:
        return 'جحيم';
      case UsernameEffect.flameGold:
        return 'لهيب ذهبي';
      case UsernameEffect.wildfire:
        return 'حريق متحرك';
      case UsernameEffect.molten:
        return 'معدن منصهر';
      case UsernameEffect.ashGlow:
        return 'وهج الرماد';
      case UsernameEffect.sunFlare:
        return 'وهج شمسي';
      case UsernameEffect.lava:
        return 'حمم';
      case UsernameEffect.firestorm:
        return 'عاصفة نارية';
      case UsernameEffect.hellfire:
        return 'نار جهنمية';
      case UsernameEffect.plasma:
        return 'بلازما';
      case UsernameEffect.electricBlue:
        return 'كهرباء زرقاء';
      case UsernameEffect.electricPurple:
        return 'كهرباء بنفسجية';
      case UsernameEffect.laser:
        return 'ليزر';
      case UsernameEffect.hologram:
        return 'هولوغرام';
      case UsernameEffect.glitch:
        return 'تشويش';
      case UsernameEffect.scanline:
        return 'خطوط ضوئية';
      case UsernameEffect.pixel:
        return 'بيكسل';
      case UsernameEffect.chroma:
        return 'كروما';
      case UsernameEffect.spectrum:
        return 'طيف ضوئي';
      case UsernameEffect.prismGlow:
        return 'وهج منشوري';
      case UsernameEffect.ocean:
        return 'محيط';
      case UsernameEffect.deepSea:
        return 'أعماق البحر';
      case UsernameEffect.aqua:
        return 'أكوا';
      case UsernameEffect.wave:
        return 'موجة';
      case UsernameEffect.tidal:
        return 'مدّ وجزر';
      case UsernameEffect.arctic:
        return 'قطبي';
      case UsernameEffect.snowSpark:
        return 'بريق الثلج';
      case UsernameEffect.iceCrystal:
        return 'كريستال ثلجي';
      case UsernameEffect.winterMoon:
        return 'قمر شتوي';
      case UsernameEffect.starlight:
        return 'ضوء النجوم';
      case UsernameEffect.starBurst:
        return 'انفجار نجمي';
      case UsernameEffect.nebula:
        return 'سديم';
      case UsernameEffect.universe:
        return 'الكون';
      case UsernameEffect.galaxyPink:
        return 'مجرة وردية';
      case UsernameEffect.comet:
        return 'مذنب';
      case UsernameEffect.meteor:
        return 'شهاب';
      case UsernameEffect.cosmicDust:
        return 'غبار كوني';
      case UsernameEffect.auroraPink:
        return 'شفق وردي';
      case UsernameEffect.auroraGreen:
        return 'شفق أخضر';
      case UsernameEffect.velvet:
        return 'مخمل';
      case UsernameEffect.amethyst:
        return 'جمشت';
      case UsernameEffect.roseGold:
        return 'ذهب وردي';
      case UsernameEffect.hotPink:
        return 'وردي ناري';
      case UsernameEffect.rubyGlow:
        return 'وهج ياقوتي';
      case UsernameEffect.emeraldGlow:
        return 'وهج زمردي';
      case UsernameEffect.sapphireGlow:
        return 'وهج ياقوت أزرق';
      case UsernameEffect.pearl:
        return 'لؤلؤ';
      case UsernameEffect.moonstone:
        return 'حجر القمر';
      case UsernameEffect.candyNeon:
        return 'نيون حلو';
      case UsernameEffect.toxicGreen:
        return 'أخضر سام';
    }
  }

  /// التدرج اللوني الذي يُرسَم به الاسم فعليًا (وليس وصفًا تسويقيًا
  /// فقط) — يُستهلك مباشرة في [UsernameEffectText].
  List<Color> get gradient {
    switch (this) {
      case UsernameEffect.none:
        return const [Color(0xFFF5F1E8), Color(0xFFF5F1E8)];
      case UsernameEffect.fire:
        return const [Color(0xFFFF5E3A), Color(0xFFFFB13A)];
      case UsernameEffect.thunder:
        return const [Color(0xFF7C4DFF), Color(0xFFB388FF)];
      case UsernameEffect.gold:
        return const [Color(0xFFD4AF37), Color(0xFFF1D07A)];
      case UsernameEffect.royal:
        return const [Color(0xFF7A1F3D), Color(0xFFD4AF37)];
      case UsernameEffect.vip:
        return const [Color(0xFF0A0A0C), Color(0xFFD4AF37)];
      case UsernameEffect.camouflage:
        return const [Color(0xFF4B5320), Color(0xFF8A9A5B)];
      case UsernameEffect.ice:
        return const [Color(0xFFA8E6FF), Color(0xFFFFFFFF)];
      case UsernameEffect.diamond:
        return const [Color(0xFFB9F2FF), Color(0xFFE0FFFF)];
      case UsernameEffect.neon:
        return const [Color(0xFF39FF14), Color(0xFF00FFF7)];
      case UsernameEffect.galaxy:
        return const [Color(0xFF1B0033), Color(0xFF9D4EDD)];
      case UsernameEffect.rainbow:
        return const [Color(0xFFFF0000), Color(0xFF8000FF)];
      case UsernameEffect.smoke:
        return const [Color(0xFF6E6A63), Color(0xFFAFA79A)];
      case UsernameEffect.lightning:
        return const [Color(0xFFFFE066), Color(0xFF4D96FF)];
      case UsernameEffect.glass:
        return const [Color(0xFFE0F7FA), Color(0xFFB2EBF2)];
      case UsernameEffect.crystal:
        return const [Color(0xFFE1BEE7), Color(0xFFFFFFFF)];
      case UsernameEffect.rose:
        return const [Color(0xFFE0A0A8), Color(0xFFF3C7CD)];
      case UsernameEffect.royalBlue:
        return const [Color(0xFF1E3A8A), Color(0xFF3B82F6)];
      case UsernameEffect.matteBlack:
        return const [Color(0xFF0A0A0A), Color(0xFF3A3A3A)];
      case UsernameEffect.silver:
        return const [Color(0xFFC0C0C0), Color(0xFFE8E8E8)];
      case UsernameEffect.bronze:
        return const [Color(0xFFCD7F32), Color(0xFFE3A869)];
      case UsernameEffect.emerald:
        return const [Color(0xFF2FBF8E), Color(0xFF7FE3BC)];
      case UsernameEffect.sapphire:
        return const [Color(0xFF3E7BFA), Color(0xFF8FB2FF)];
      case UsernameEffect.amber:
        return const [Color(0xFFFFC107), Color(0xFFFFE082)];
      case UsernameEffect.violet:
        return const [Color(0xFF8E24AA), Color(0xFFCE93D8)];
      case UsernameEffect.lunar:
        return const [Color(0xFFCFD8DC), Color(0xFF90A4AE)];
      case UsernameEffect.solar:
        return const [Color(0xFFFF9800), Color(0xFFFFEB3B)];
      case UsernameEffect.coral:
        return const [Color(0xFFFF7F50), Color(0xFFFFB199)];
      case UsernameEffect.magenta:
        return const [Color(0xFFE91E8C), Color(0xFFFF6EC7)];
      case UsernameEffect.obsidian:
        return const [Color(0xFF120E12), Color(0xFF3D2E3D)];
      case UsernameEffect.platinum:
        return const [Color(0xFFE5E4E2), Color(0xFFB8B8B8)];
      case UsernameEffect.jade:
        return const [Color(0xFF00A86B), Color(0xFFA5E8C9)];
      case UsernameEffect.ruby:
        return const [Color(0xFF9B111E), Color(0xFFE0115F)];
      case UsernameEffect.cobalt:
        return const [Color(0xFF0047AB), Color(0xFF6699FF)];
      case UsernameEffect.sunset:
        return const [Color(0xFFFF5F6D), Color(0xFFFFC371)];
      case UsernameEffect.aurora:
        return const [Color(0xFF00C9A7), Color(0xFF92FE9D)];
      case UsernameEffect.phoenix:
        return const [Color(0xFFB71C1C), Color(0xFFFFA000)];
      case UsernameEffect.storm:
        return const [Color(0xFF37474F), Color(0xFF90A4AE)];
      case UsernameEffect.mystic:
        return const [Color(0xFF4A148C), Color(0xFF7B1FA2)];
      case UsernameEffect.venom:
        return const [Color(0xFF1B5E20), Color(0xFF76FF03)];
      case UsernameEffect.frost:
        return const [Color(0xFFBBDEFB), Color(0xFFE3F2FD)];
      case UsernameEffect.blaze:
        return const [Color(0xFFE65100), Color(0xFFFFD54F)];
      case UsernameEffect.cosmic:
        return const [Color(0xFF0D0221), Color(0xFF7303C0)];
      case UsernameEffect.shadow:
        return const [Color(0xFF000000), Color(0xFF424242)];
      case UsernameEffect.prism:
        return const [Color(0xFFFF00FF), Color(0xFF00FFFF)];
      case UsernameEffect.mercury:
        return const [Color(0xFFAEB6BF), Color(0xFFEAEDED)];
      case UsernameEffect.titanium:
        return const [Color(0xFF878E88), Color(0xFFC0C0C0)];
      case UsernameEffect.opal:
        return const [Color(0xFFA8C3BC), Color(0xFFE8D5E8)];
      case UsernameEffect.garnet:
        return const [Color(0xFF733635), Color(0xFFC62828)];
      case UsernameEffect.dragonFire:
        return const [Color(0xFF1A0000), Color(0xFFFF0000), Color(0xFFFFA500)];
      case UsernameEffect.ember:
        return const [Color(0xFFF4511E), Color(0xFFFFD180)];
      case UsernameEffect.inferno:
        return const [Color(0xFFB71C1C), Color(0xFFFF6D00)];
      case UsernameEffect.flameGold:
        return const [Color(0xFFFF8F00), Color(0xFFFFE082)];
      case UsernameEffect.wildfire:
        return const [Color(0xFFFF3D00), Color(0xFFFFEA00)];
      case UsernameEffect.molten:
        return const [Color(0xFF8D6E63), Color(0xFFFF7043)];
      case UsernameEffect.ashGlow:
        return const [Color(0xFF4E342E), Color(0xFFD7CCC8)];
      case UsernameEffect.sunFlare:
        return const [Color(0xFFFF6F00), Color(0xFFFFF176)];
      case UsernameEffect.lava:
        return const [Color(0xFFBF360C), Color(0xFFFF8A50)];
      case UsernameEffect.firestorm:
        return const [Color(0xFF5D001E), Color(0xFFFF5722)];
      case UsernameEffect.hellfire:
        return const [Color(0xFF6A0000), Color(0xFFFF1744)];
      case UsernameEffect.plasma:
        return const [Color(0xFF00E5FF), Color(0xFFE040FB)];
      case UsernameEffect.electricBlue:
        return const [Color(0xFF2196F3), Color(0xFF80D8FF)];
      case UsernameEffect.electricPurple:
        return const [Color(0xFF7C4DFF), Color(0xFFEA80FC)];
      case UsernameEffect.laser:
        return const [Color(0xFFFF1744), Color(0xFFFF80AB)];
      case UsernameEffect.hologram:
        return const [Color(0xFF00E5FF), Color(0xFF64FFDA)];
      case UsernameEffect.glitch:
        return const [Color(0xFFFF0055), Color(0xFF00FF99)];
      case UsernameEffect.scanline:
        return const [Color(0xFF00B8D4), Color(0xFFB2FF59)];
      case UsernameEffect.pixel:
        return const [Color(0xFF76FF03), Color(0xFF00E676)];
      case UsernameEffect.chroma:
        return const [Color(0xFFFF00FF), Color(0xFF00FFFF)];
      case UsernameEffect.spectrum:
        return const [Color(0xFFFF0000), Color(0xFFFFFF00)];
      case UsernameEffect.prismGlow:
        return const [Color(0xFFFF4081), Color(0xFF7C4DFF)];
      case UsernameEffect.ocean:
        return const [Color(0xFF01579B), Color(0xFF00E5FF)];
      case UsernameEffect.deepSea:
        return const [Color(0xFF002B36), Color(0xFF268BD2)];
      case UsernameEffect.aqua:
        return const [Color(0xFF00B8D4), Color(0xFF1DE9B6)];
      case UsernameEffect.wave:
        return const [Color(0xFF1565C0), Color(0xFF64B5F6)];
      case UsernameEffect.tidal:
        return const [Color(0xFF006064), Color(0xFF80DEEA)];
      case UsernameEffect.arctic:
        return const [Color(0xFF0288D1), Color(0xFFE1F5FE)];
      case UsernameEffect.snowSpark:
        return const [Color(0xFF90CAF9), Color(0xFFFFFFFF)];
      case UsernameEffect.iceCrystal:
        return const [Color(0xFF81D4FA), Color(0xFFE0F7FA)];
      case UsernameEffect.winterMoon:
        return const [Color(0xFF37474F), Color(0xFFCFD8DC)];
      case UsernameEffect.starlight:
        return const [Color(0xFFFFF8E1), Color(0xFFFFD54F)];
      case UsernameEffect.starBurst:
        return const [Color(0xFFF9A825), Color(0xFFFFF59D)];
      case UsernameEffect.nebula:
        return const [Color(0xFF4A148C), Color(0xFFAA00FF)];
      case UsernameEffect.universe:
        return const [Color(0xFF0D47A1), Color(0xFF7E57C2)];
      case UsernameEffect.galaxyPink:
        return const [Color(0xFFD500F9), Color(0xFFFF80AB)];
      case UsernameEffect.comet:
        return const [Color(0xFF00ACC1), Color(0xFFFFFFFF)];
      case UsernameEffect.meteor:
        return const [Color(0xFF5E35B1), Color(0xFFFF7043)];
      case UsernameEffect.cosmicDust:
        return const [Color(0xFF311B92), Color(0xFF00E5FF)];
      case UsernameEffect.auroraPink:
        return const [Color(0xFFFF4081), Color(0xFFB388FF)];
      case UsernameEffect.auroraGreen:
        return const [Color(0xFF00C853), Color(0xFF64FFDA)];
      case UsernameEffect.velvet:
        return const [Color(0xFF4A0E2E), Color(0xFFAD1457)];
      case UsernameEffect.amethyst:
        return const [Color(0xFF6A1B9A), Color(0xFFCE93D8)];
      case UsernameEffect.roseGold:
        return const [Color(0xFFAD1457), Color(0xFFFFD54F)];
      case UsernameEffect.hotPink:
        return const [Color(0xFFF50057), Color(0xFFFF80AB)];
      case UsernameEffect.rubyGlow:
        return const [Color(0xFF8E0000), Color(0xFFFF5252)];
      case UsernameEffect.emeraldGlow:
        return const [Color(0xFF00695C), Color(0xFF69F0AE)];
      case UsernameEffect.sapphireGlow:
        return const [Color(0xFF0D47A1), Color(0xFF82B1FF)];
      case UsernameEffect.pearl:
        return const [Color(0xFFB0BEC5), Color(0xFFFFFFFF)];
      case UsernameEffect.moonstone:
        return const [Color(0xFF90A4AE), Color(0xFFECEFF1)];
      case UsernameEffect.candyNeon:
        return const [Color(0xFFFF2D95), Color(0xFF7C4DFF)];
      case UsernameEffect.toxicGreen:
        return const [Color(0xFF1B5E20), Color(0xFFB2FF59)];
    }
  }

  /// أقل مستوى رتبة (Gamification Rank) مطلوب — يُستخدم فقط
  /// كبديل احتياطي إن لم تمنح أي عضوية هذا التأثير صراحة. تأثير
  /// DRAGON الحصري خارج هذا المقياس تمامًا (راجع isDragonExclusive).
  int get minRankLevel {
    if (isDragonExclusive) return 999999;
    final index = UsernameEffect.values.indexOf(this);
    return index * 2;
  }

  int get animationIndex => UsernameEffect.values.indexOf(this) - 1;

  /// كل تأثير له حركة فعلية؛ يتم توليد 100 تركيبة (10 محركات × 10 لوحات)
  /// بدون الاعتماد على صور ثابتة. 0=ثابت/none، و1..10 محركات حركة مختلفة.
  int get animationMode {
    if (this == UsernameEffect.none) return 0;
    return (animationIndex % 10) + 1;
  }

  int get paletteIndex {
    if (this == UsernameEffect.none) return 0;
    return (animationIndex ~/ 10) % 10;
  }

  bool get isAnimated => this != UsernameEffect.none;
}
