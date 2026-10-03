/// Canonical catalog of animated avatar-frame effects.
/// The key is persisted with the frame catalog and rendered client-side.
class FrameEffectOption {
  final String key;
  final String nameAr;
  const FrameEffectOption(this.key, this.nameAr);
}

class FrameEffectCatalog {
  static const options = <FrameEffectOption>[
    FrameEffectOption('pulse_glow', '✨ وهج نابض'),
    FrameEffectOption('lightning', '⚡ برق'),
    FrameEffectOption('fire', '🔥 نار'),
    FrameEffectOption('flame', '🔥 لهب متحرك'),
    FrameEffectOption('crossed_swords', '⚔️ سيوف متصارعة'),
    FrameEffectOption('ice_crystals', '❄️ بلورات جليد'),
    FrameEffectOption('orbiting_stars', '⭐ نجوم مدارية'),
    FrameEffectOption('meteor_shower', '☄️ شهب نيزكية'),
    FrameEffectOption('neon_rainbow', '🌈 نيون قوس قزح'),
    FrameEffectOption('rotating_ring', '⭕ حلقة دوارة'),
    FrameEffectOption('spark_burst', '💥 انفجار شرر'),
    FrameEffectOption('bubbles', '🫧 فقاعات'),
    FrameEffectOption('snow', '❄️ تساقط ثلجي'),
    FrameEffectOption('petals', '🌸 بتلات متطايرة'),
    FrameEffectOption('hearts', '❤️ قلوب عائمة'),
    FrameEffectOption('coins', '🪙 عملات دوارة'),
    FrameEffectOption('magic_runes', '🔮 رموز سحرية'),
    FrameEffectOption('plasma_arc', '🟣 قوس بلازما'),
    FrameEffectOption('cosmic_dust', '🌌 غبار كوني'),
    FrameEffectOption('solar_flare', '☀️ توهج شمسي'),
    FrameEffectOption('shadow_smoke', '🌫️ دخان ظل'),
    FrameEffectOption('wind_blades', '💨 شفرات هواء'),
    FrameEffectOption('electric_orbit', '⚡ مدار كهربائي'),
    FrameEffectOption('golden_sparkle', '✨ لمعان ذهبي'),
    FrameEffectOption('diamond_shine', '💎 بريق ألماسي'),
    FrameEffectOption('water_wave', '💧 موجة مائية'),
    FrameEffectOption('rose_petal', '🌹 بتلات ورد'),
    FrameEffectOption('phoenix', '🔥 طائر العنقاء'),
    FrameEffectOption('comet', '🌠 مذنب دوار'),
    FrameEffectOption('vortex', '🌀 دوامة طاقة'),
  ];

  static String normalize(Object? value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    const aliases = <String, String>{
      'glow': 'pulse_glow', 'وهج نابض': 'pulse_glow',
      'برق': 'lightning', 'electric': 'lightning',
      'نار': 'fire', 'لهب': 'flame',
      'سيوف': 'crossed_swords', 'سيوف متصارعة': 'crossed_swords',
      'swords': 'crossed_swords',
    };
    final mapped = aliases[raw] ?? raw;
    return options.any((o) => o.key == mapped) ? mapped : 'pulse_glow';
  }

  static String name(Object? value) {
    final key = normalize(value);
    return options.firstWhere((o) => o.key == key).nameAr;
  }
}
