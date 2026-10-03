-- MASHAREENA: canonical 30 animated frame effects.
begin;

update public.avatar_frame_catalog
set palette_key = case lower(trim(coalesce(palette_key,'')))
  when 'pulse_glow' then 'pulse_glow'
  when 'lightning' then 'lightning'
  when 'fire' then 'fire'
  when 'flame' then 'flame'
  when 'crossed_swords' then 'crossed_swords'
  when 'ice_crystals' then 'ice_crystals'
  when 'orbiting_stars' then 'orbiting_stars'
  when 'meteor_shower' then 'meteor_shower'
  when 'neon_rainbow' then 'neon_rainbow'
  when 'rotating_ring' then 'rotating_ring'
  when 'spark_burst' then 'spark_burst'
  when 'bubbles' then 'bubbles'
  when 'snow' then 'snow'
  when 'petals' then 'petals'
  when 'hearts' then 'hearts'
  when 'coins' then 'coins'
  when 'magic_runes' then 'magic_runes'
  when 'plasma_arc' then 'plasma_arc'
  when 'cosmic_dust' then 'cosmic_dust'
  when 'solar_flare' then 'solar_flare'
  when 'shadow_smoke' then 'shadow_smoke'
  when 'wind_blades' then 'wind_blades'
  when 'electric_orbit' then 'electric_orbit'
  when 'golden_sparkle' then 'golden_sparkle'
  when 'diamond_shine' then 'diamond_shine'
  when 'water_wave' then 'water_wave'
  when 'rose_petal' then 'rose_petal'
  when 'phoenix' then 'phoenix'
  when 'comet' then 'comet'
  when 'vortex' then 'vortex'
  when 'برق' then 'lightning'
  when 'نار' then 'fire'
  when 'لهب' then 'flame'
  when 'سيوف' then 'crossed_swords'
  when 'swords' then 'crossed_swords'
  else 'pulse_glow'
end
where is_active = true;

update public.profile_cosmetic_catalog
set metadata = jsonb_set(
  coalesce(metadata,'{}'::jsonb),
  '{frame_effect}',
  to_jsonb(case lower(trim(coalesce(metadata->>'frame_effect', palette_key, 'pulse_glow')))
  when 'pulse_glow' then 'pulse_glow'
  when 'lightning' then 'lightning'
  when 'fire' then 'fire'
  when 'flame' then 'flame'
  when 'crossed_swords' then 'crossed_swords'
  when 'ice_crystals' then 'ice_crystals'
  when 'orbiting_stars' then 'orbiting_stars'
  when 'meteor_shower' then 'meteor_shower'
  when 'neon_rainbow' then 'neon_rainbow'
  when 'rotating_ring' then 'rotating_ring'
  when 'spark_burst' then 'spark_burst'
  when 'bubbles' then 'bubbles'
  when 'snow' then 'snow'
  when 'petals' then 'petals'
  when 'hearts' then 'hearts'
  when 'coins' then 'coins'
  when 'magic_runes' then 'magic_runes'
  when 'plasma_arc' then 'plasma_arc'
  when 'cosmic_dust' then 'cosmic_dust'
  when 'solar_flare' then 'solar_flare'
  when 'shadow_smoke' then 'shadow_smoke'
  when 'wind_blades' then 'wind_blades'
  when 'electric_orbit' then 'electric_orbit'
  when 'golden_sparkle' then 'golden_sparkle'
  when 'diamond_shine' then 'diamond_shine'
  when 'water_wave' then 'water_wave'
  when 'rose_petal' then 'rose_petal'
  when 'phoenix' then 'phoenix'
  when 'comet' then 'comet'
  when 'vortex' then 'vortex'
  when 'برق' then 'lightning'
  when 'نار' then 'fire'
  when 'لهب' then 'flame'
  when 'سيوف' then 'crossed_swords'
  when 'swords' then 'crossed_swords'
  else 'pulse_glow'
end),
  true
)
where category='frame';

commit;
