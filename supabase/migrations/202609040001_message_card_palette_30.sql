-- Owner-managed 30-color palette for per-user chat message cards.
-- Existing message_color remains the authoritative user selection; this migration
-- only expands the catalog and makes the default card visually silver.
insert into public.profile_cosmetic_catalog
  (item_key, category, gender, name_ar, animation_mode, palette_key, mode_variant,
   color1, color2, price_points, price_gems, owner_free, is_active, sort_order, metadata)
select v.item_key, 'message_color', 'unisex', v.name_ar, 'solid', v.item_key, 'solid',
       v.color1, null, 0, 0, true, true, 70000 + v.ord,
       jsonb_build_object('tier','free','source','owner_managed_30_color_message_card_palette')
from (values
  (15,'msg_full_rose','وردي فاتح','#FB7185'),
  (16,'msg_full_coral','مرجاني','#F43F5E'),
  (17,'msg_full_peach','خوخي','#FDBA74'),
  (18,'msg_full_tangerine','يوسفي','#FB923C'),
  (19,'msg_full_gold','ذهبي','#FBBF24'),
  (20,'msg_full_olive','زيتوني','#A3A635'),
  (21,'msg_full_emerald','زمردي','#10B981'),
  (22,'msg_full_mint','نعناعي','#6EE7B7'),
  (23,'msg_full_aqua','أكوا','#22D3EE'),
  (24,'msg_full_sky','سماوي فاتح','#38BDF8'),
  (25,'msg_full_navy','كحلي','#1D4ED8'),
  (26,'msg_full_periwinkle','بنفسجي سماوي','#818CF8'),
  (27,'msg_full_lavender','لافندر','#A78BFA'),
  (28,'msg_full_magenta','أرجواني وردي','#E879F9'),
  (29,'msg_full_burgundy','عنابي','#9F1239'),
  (30,'msg_full_silver','فضي','#BFC5CE')
) as v(ord,item_key,name_ar,color1)
where not exists (select 1 from public.profile_cosmetic_catalog c where c.item_key=v.item_key);
