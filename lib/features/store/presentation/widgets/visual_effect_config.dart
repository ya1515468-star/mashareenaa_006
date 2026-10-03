import 'package:flutter/material.dart';

enum VisualEffectPlacement { username, avatar, both }
enum VisualEffectLayer { behind, around, front }

enum VisualEffectQuality { low, medium, high, ultra }

class VisualEffectConfig {
  final String effectKey;
  final String nameAr;
  final VisualEffectPlacement placement;
  final VisualEffectLayer layer;
  final double intensity;
  final double speed;
  final double scale;
  final int particleCount;
  final List<Color> colors;

  const VisualEffectConfig({
    required this.effectKey,
    required this.nameAr,
    required this.placement,
    required this.layer,
    required this.intensity,
    required this.speed,
    required this.scale,
    required this.particleCount,
    required this.colors,
  });

  VisualEffectConfig forQuality(VisualEffectQuality quality) {
    final factor = switch (quality) {
      VisualEffectQuality.low => .55,
      VisualEffectQuality.medium => .8,
      VisualEffectQuality.high => 1.0,
      VisualEffectQuality.ultra => 1.15,
    };
    return VisualEffectConfig(
      effectKey: effectKey,
      nameAr: nameAr,
      placement: placement,
      layer: layer,
      intensity: intensity,
      speed: speed,
      scale: scale,
      particleCount: (particleCount * factor).round().clamp(4, particleCount).toInt(),
      colors: colors,
    );
  }
}


class VisualEffectRegistry {
  VisualEffectRegistry._();

  static const definitions = <String, VisualEffectConfig>{
    'pulse_glow': VisualEffectConfig(effectKey:'pulse_glow', nameAr:'وهج نابض', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.0, speed:1.0, scale:1.0, particleCount:14, colors:[Color(0xFF00E5FF), Color(0xFF7C4DFF)]),
    'lightning': VisualEffectConfig(effectKey:'lightning', nameAr:'برق', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.0, speed:1.35, scale:1.0, particleCount:10, colors:[Color(0xFF9BE7FF), Color(0xFFFFFFFF)]),
    'fire': VisualEffectConfig(effectKey:'fire', nameAr:'نار', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.0, speed:1.0, scale:1.0, particleCount:24, colors:[Color(0xFFFFC107), Color(0xFFFF5722), Color(0xFFFF1744)]),
    'flame': VisualEffectConfig(effectKey:'flame', nameAr:'لهب متحرك', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.05, speed:.9, scale:1.0, particleCount:20, colors:[Color(0xFFFFF176), Color(0xFFFF6D00), Color(0xFFD50000)]),
    'crossed_swords': VisualEffectConfig(effectKey:'crossed_swords', nameAr:'سيوف متصارعة', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.0, speed:1.0, scale:1.0, particleCount:8, colors:[Color(0xFFE0F7FA), Color(0xFF90CAF9)]),
    'ice_crystals': VisualEffectConfig(effectKey:'ice_crystals', nameAr:'بلورات جليد', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.0, speed:.7, scale:1.0, particleCount:18, colors:[Color(0xFFB3E5FC), Color(0xFFFFFFFF), Color(0xFF80DEEA)]),
    'orbiting_stars': VisualEffectConfig(effectKey:'orbiting_stars', nameAr:'نجوم مدارية', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.0, speed:.75, scale:1.0, particleCount:10, colors:[Color(0xFFFFF59D), Color(0xFFFFFFFF)]),
    'meteor_shower': VisualEffectConfig(effectKey:'meteor_shower', nameAr:'شهب نيزكية', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.0, speed:1.2, scale:1.0, particleCount:12, colors:[Color(0xFFFFCC80), Color(0xFFFFFFFF)]),
    'neon_rainbow': VisualEffectConfig(effectKey:'neon_rainbow', nameAr:'نيون قوس قزح', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.0, speed:.55, scale:1.0, particleCount:8, colors:[Color(0xFFFF3DFF), Color(0xFF00E5FF), Color(0xFFFFFF00), Color(0xFF69F0AE)]),
    'rotating_ring': VisualEffectConfig(effectKey:'rotating_ring', nameAr:'حلقة دوارة', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.0, speed:.7, scale:1.0, particleCount:12, colors:[Color(0xFF00E5FF), Color(0xFF7C4DFF)]),
    'spark_burst': VisualEffectConfig(effectKey:'spark_burst', nameAr:'انفجار شرر', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.0, speed:1.15, scale:1.0, particleCount:18, colors:[Color(0xFFFFF59D), Color(0xFFFF8A65)]),
    'bubbles': VisualEffectConfig(effectKey:'bubbles', nameAr:'فقاعات', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:.9, speed:.65, scale:1.0, particleCount:16, colors:[Color(0xFF80DEEA), Color(0xFFFFFFFF)]),
    'snow': VisualEffectConfig(effectKey:'snow', nameAr:'تساقط ثلجي', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:.9, speed:.45, scale:1.0, particleCount:20, colors:[Color(0xFFFFFFFF), Color(0xFFB3E5FC)]),
    'petals': VisualEffectConfig(effectKey:'petals', nameAr:'بتلات متطايرة', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:.9, speed:.5, scale:1.0, particleCount:14, colors:[Color(0xFFF48FB1), Color(0xFFFFCDD2)]),
    'hearts': VisualEffectConfig(effectKey:'hearts', nameAr:'قلوب عائمة', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:.9, speed:.55, scale:1.0, particleCount:12, colors:[Color(0xFFFF4081), Color(0xFFFF8A80)]),
    'coins': VisualEffectConfig(effectKey:'coins', nameAr:'عملات دوارة', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:.95, speed:.75, scale:1.0, particleCount:10, colors:[Color(0xFFFFD54F), Color(0xFFFFA000)]),
    'magic_runes': VisualEffectConfig(effectKey:'magic_runes', nameAr:'رموز سحرية', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.0, speed:.48, scale:1.0, particleCount:8, colors:[Color(0xFFB388FF), Color(0xFF80CBC4)]),
    'plasma_arc': VisualEffectConfig(effectKey:'plasma_arc', nameAr:'قوس بلازما', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.05, speed:.9, scale:1.0, particleCount:10, colors:[Color(0xFFE040FB), Color(0xFF00E5FF)]),
    'cosmic_dust': VisualEffectConfig(effectKey:'cosmic_dust', nameAr:'غبار كوني', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:.75, speed:.35, scale:1.0, particleCount:24, colors:[Color(0xFFB39DDB), Color(0xFF80DEEA), Color(0xFFFFFFFF)]),
    'solar_flare': VisualEffectConfig(effectKey:'solar_flare', nameAr:'توهج شمسي', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.0, speed:.38, scale:1.0, particleCount:10, colors:[Color(0xFFFFF176), Color(0xFFFF9800)]),
    'shadow_smoke': VisualEffectConfig(effectKey:'shadow_smoke', nameAr:'دخان ظل', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:.7, speed:.22, scale:1.0, particleCount:16, colors:[Color(0xFF90A4AE), Color(0xFF263238)]),
    'wind_blades': VisualEffectConfig(effectKey:'wind_blades', nameAr:'شفرات هواء', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.0, speed:1.25, scale:1.0, particleCount:8, colors:[Color(0xFFB2EBF2), Color(0xFF80CBC4)]),
    'electric_orbit': VisualEffectConfig(effectKey:'electric_orbit', nameAr:'مدار كهربائي', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.0, speed:1.0, scale:1.0, particleCount:12, colors:[Color(0xFF40C4FF), Color(0xFFFFF176)]),
    'golden_sparkle': VisualEffectConfig(effectKey:'golden_sparkle', nameAr:'لمعان ذهبي', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:.85, speed:.7, scale:1.0, particleCount:14, colors:[Color(0xFFFFD740), Color(0xFFFFF8E1)]),
    'diamond_shine': VisualEffectConfig(effectKey:'diamond_shine', nameAr:'بريق ألماسي', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:.9, speed:.58, scale:1.0, particleCount:7, colors:[Color(0xFFE1F5FE), Color(0xFFFFFFFF)]),
    'water_wave': VisualEffectConfig(effectKey:'water_wave', nameAr:'موجة مائية', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:.75, speed:.42, scale:1.0, particleCount:8, colors:[Color(0xFF29B6F6), Color(0xFF80DEEA)]),
    'rose_petal': VisualEffectConfig(effectKey:'rose_petal', nameAr:'بتلات ورد', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:.9, speed:.48, scale:1.0, particleCount:12, colors:[Color(0xFFF06292), Color(0xFFCE93D8)]),
    'phoenix': VisualEffectConfig(effectKey:'phoenix', nameAr:'طائر العنقاء', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.05, speed:.65, scale:1.0, particleCount:22, colors:[Color(0xFFFFD740), Color(0xFFFF6D00), Color(0xFFFF1744)]),
    'comet': VisualEffectConfig(effectKey:'comet', nameAr:'مذنب دوار', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.0, speed:.7, scale:1.0, particleCount:9, colors:[Color(0xFFE1F5FE), Color(0xFF69F0AE)]),
    'vortex': VisualEffectConfig(effectKey:'vortex', nameAr:'دوامة طاقة حقيقية 100%', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.15, speed:.7, scale:1.0, particleCount:34, colors:[Color(0xFF00E5FF), Color(0xFF7C4DFF), Color(0xFFE040FB)]),
    'aurora_ribbon': VisualEffectConfig(effectKey:'aurora_ribbon', nameAr:'شفق راقص', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.0, speed:0.42, scale:1.0, particleCount:18, colors:[Color(0xFF80D8FF), Color(0xFFB388FF), Color(0xFF69F0AE)]),
    'laser_sweep': VisualEffectConfig(effectKey:'laser_sweep', nameAr:'مسح ليزري', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.0, speed:0.8, scale:1.0, particleCount:6, colors:[Color(0xFFFF1744), Color(0xFF00E5FF), Color(0xFFFFFFFF)]),
    'hologram_scan': VisualEffectConfig(effectKey:'hologram_scan', nameAr:'مسح هولوغرافي', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:0.9, speed:0.55, scale:1.0, particleCount:10, colors:[Color(0xFF00E5FF), Color(0xFF7C4DFF)]),
    'galaxy_swirl': VisualEffectConfig(effectKey:'galaxy_swirl', nameAr:'مجرة دوارة', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.0, speed:0.38, scale:1.0, particleCount:22, colors:[Color(0xFF7C4DFF), Color(0xFFE040FB), Color(0xFF40C4FF)]),
    'orbiting_planets': VisualEffectConfig(effectKey:'orbiting_planets', nameAr:'كواكب مدارية', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.0, speed:0.46, scale:1.0, particleCount:5, colors:[Color(0xFF80DEEA), Color(0xFFFFD54F), Color(0xFFFF8A65)]),
    'electric_storm': VisualEffectConfig(effectKey:'electric_storm', nameAr:'عاصفة كهربائية', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.1, speed:0.9, scale:1.0, particleCount:16, colors:[Color(0xFFB388FF), Color(0xFF40C4FF), Color(0xFFFFFFFF)]),
    'crystal_shards': VisualEffectConfig(effectKey:'crystal_shards', nameAr:'شظايا كريستال', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.0, speed:0.7, scale:1.0, particleCount:14, colors:[Color(0xFFE1F5FE), Color(0xFFB39DDB), Color(0xFF80DEEA)]),
    'starfield': VisualEffectConfig(effectKey:'starfield', nameAr:'حقل نجوم', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.behind, intensity:0.8, speed:0.25, scale:1.0, particleCount:28, colors:[Color(0xFFFFFFFF), Color(0xFFFFF59D), Color(0xFFB3E5FC)]),
    'arcane_portal': VisualEffectConfig(effectKey:'arcane_portal', nameAr:'بوابة سحرية', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.05, speed:0.5, scale:1.0, particleCount:16, colors:[Color(0xFF7C4DFF), Color(0xFFEA80FC), Color(0xFF00E5FF)]),
    'celestial_wings': VisualEffectConfig(effectKey:'celestial_wings', nameAr:'أجنحة سماوية', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.0, speed:0.48, scale:1.0, particleCount:12, colors:[Color(0xFFE1F5FE), Color(0xFFFFFFFF), Color(0xFFB39DDB)]),
    'butterfly_swarm': VisualEffectConfig(effectKey:'butterfly_swarm', nameAr:'سرب فراشات', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:0.9, speed:0.34, scale:1.0, particleCount:10, colors:[Color(0xFFFF80AB), Color(0xFFB388FF), Color(0xFF69F0AE)]),
    'autumn_leaves': VisualEffectConfig(effectKey:'autumn_leaves', nameAr:'أوراق خريف', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:0.9, speed:0.36, scale:1.0, particleCount:14, colors:[Color(0xFFFFB74D), Color(0xFFFF7043), Color(0xFFD32F2F)]),
    'ember_rain': VisualEffectConfig(effectKey:'ember_rain', nameAr:'مطر جمر', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.0, speed:0.75, scale:1.0, particleCount:20, colors:[Color(0xFFFFD54F), Color(0xFFFF6D00), Color(0xFFFF1744)]),
    'lava_flow': VisualEffectConfig(effectKey:'lava_flow', nameAr:'تدفق حمم', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.0, speed:0.28, scale:1.0, particleCount:10, colors:[Color(0xFFFF9800), Color(0xFFFF5722), Color(0xFFD50000)]),
    'poison_bubbles': VisualEffectConfig(effectKey:'poison_bubbles', nameAr:'فقاعات سامة', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:0.85, speed:0.31, scale:1.0, particleCount:14, colors:[Color(0xFF76FF03), Color(0xFFB2FF59), Color(0xFFE040FB)]),
    'moon_dust': VisualEffectConfig(effectKey:'moon_dust', nameAr:'غبار قمري', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:0.7, speed:0.22, scale:1.0, particleCount:24, colors:[Color(0xFFCFD8DC), Color(0xFF90CAF9), Color(0xFFFFFFFF)]),
    'water_droplets': VisualEffectConfig(effectKey:'water_droplets', nameAr:'قطرات مائية', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:0.85, speed:0.6, scale:1.0, particleCount:18, colors:[Color(0xFF29B6F6), Color(0xFF81D4FA), Color(0xFFE1F5FE)]),
    'sonic_rings': VisualEffectConfig(effectKey:'sonic_rings', nameAr:'حلقات صوتية', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.around, intensity:1.0, speed:0.52, scale:1.0, particleCount:8, colors:[Color(0xFF00E5FF), Color(0xFFFFFFFF), Color(0xFFFF4081)]),
    'golden_crown': VisualEffectConfig(effectKey:'golden_crown', nameAr:'تاج ذهبي', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.front, intensity:1.0, speed:0.4, scale:1.0, particleCount:7, colors:[Color(0xFFFFD740), Color(0xFFFFF8E1), Color(0xFFFFAB00)]),
    'royal_aura': VisualEffectConfig(effectKey:'royal_aura', nameAr:'هالة ملكية', placement:VisualEffectPlacement.both, layer:VisualEffectLayer.behind, intensity:1.05, speed:0.33, scale:1.0, particleCount:12, colors:[Color(0xFFFFD740), Color(0xFF7C4DFF), Color(0xFFFFFFFF)]),
  };

  static VisualEffectConfig? get(String? effectKey) {
    final key = effectKey?.trim().toLowerCase();
    if (key == null || key.isEmpty || key == 'none') return null;
    return definitions[key];
  }
}
