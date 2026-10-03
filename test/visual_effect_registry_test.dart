import 'package:flutter_test/flutter_test.dart';
import 'package:mashareena/features/store/presentation/widgets/visual_effect_config.dart';

void main() {
  test('visual registry contains exactly the 50 contracted effect keys', () {
    const expected = [
      'pulse_glow','lightning','fire','flame','crossed_swords','ice_crystals','orbiting_stars','meteor_shower','neon_rainbow','rotating_ring',
      'spark_burst','bubbles','snow','petals','hearts','coins','magic_runes','plasma_arc','cosmic_dust','solar_flare',
      'shadow_smoke','wind_blades','electric_orbit','golden_sparkle','diamond_shine','water_wave','rose_petal','phoenix','comet','vortex',
      'aurora_ribbon','laser_sweep','hologram_scan','galaxy_swirl','orbiting_planets','electric_storm','crystal_shards','starfield','arcane_portal','celestial_wings',
      'butterfly_swarm','autumn_leaves','ember_rain','lava_flow','poison_bubbles','moon_dust','water_droplets','sonic_rings','golden_crown','royal_aura',
    ];
    expect(VisualEffectRegistry.definitions.length, 50);
    expect(VisualEffectRegistry.definitions.keys.toList(), expected);
    expect(VisualEffectRegistry.definitions.keys.toSet().length, 50);
  });

  test('quality contract supports low/medium/high/ultra', () {
    for (final quality in VisualEffectQuality.values) {
      for (final config in VisualEffectRegistry.definitions.values) {
        final scaled = config.forQuality(quality);
        expect(scaled.particleCount, greaterThanOrEqualTo(4));
      }
    }
  });

  test('contracted effects are animatable and support all placements', () {
    for (final config in VisualEffectRegistry.definitions.values) {
      expect(config.effectKey, isNotEmpty);
      expect(config.placement, VisualEffectPlacement.both);
      expect(config.particleCount, greaterThanOrEqualTo(4));
      expect(config.speed, greaterThan(0));
      expect(config.scale, greaterThan(0));
    }
  });

  test('unknown and none keys safely disable rendering', () {
    expect(VisualEffectRegistry.get(null), isNull);
    expect(VisualEffectRegistry.get('none'), isNull);
    expect(VisualEffectRegistry.get('not_real'), isNull);
    expect(VisualEffectRegistry.get('VORTEX')!.effectKey, 'vortex');
  });
}
