-- 50 video name templates: explicit visual-family + finish-variant metadata.
update public.profile_cosmetic_catalog
set metadata = metadata || jsonb_build_object(
  'visual_family', case (((sort_order - 1) / 5) + 1)
    when 1 then 'stag_emerald_gold'
    when 2 then 'wolf_silver_ice'
    when 3 then 'tiger_molten_gold'
    when 4 then 'phoenix_ember'
    when 5 then 'lion_royal_sun'
    when 6 then 'wolf_amethyst_frost'
    when 7 then 'unicorn_prism'
    when 8 then 'dragon_sapphire_storm'
    when 9 then 'pegasus_celestial'
    else 'winged_reference_derivative'
  end,
  'finish_variant', ((sort_order - 1) % 5),
  'visual_variation', true,
  'asset_version', 2
)
where category = 'name_template'
  and sort_order between 1 and 50;
