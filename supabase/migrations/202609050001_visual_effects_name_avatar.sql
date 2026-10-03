-- MASHAREENA: Visual effects for username/avatar
-- Additive migration only: reuse profile_cosmetic_catalog, profile_cosmetic_purchases and existing wallets.

begin;

alter table public.profile_cosmetic_catalog
  drop constraint if exists profile_cosmetic_catalog_category_check;
alter table public.profile_cosmetic_catalog
  add constraint profile_cosmetic_catalog_category_check
  check (category = any (array['frame','background','name_effect','message_color','visual_effect']::text[]));

alter table public.profiles
  add column if not exists avatar_visual_effect_key text;


-- Exact 30 catalog products from the execution contract.

insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_pulse_glow','visual_effect','unisex','وهج نابض','loop','pulse_glow','both','#00E5FF','#7C4DFF',5000,50,true,true,1,'{"effect_key":"pulse_glow","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":1.0,"particle_count":14,"duration_ms":2400,"loop":true,"primary_color":"#00E5FF","secondary_color":"#7C4DFF","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_lightning','visual_effect','unisex','برق','loop','lightning','both','#9BE7FF','#FFFFFF',5000,50,true,true,2,'{"effect_key":"lightning","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":1.35,"particle_count":10,"duration_ms":2400,"loop":true,"primary_color":"#9BE7FF","secondary_color":"#FFFFFF","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_fire','visual_effect','unisex','نار','loop','fire','both','#FFC107','#FF5722',5000,50,true,true,3,'{"effect_key":"fire","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":1.0,"scale":1.0,"speed":1.0,"particle_count":24,"duration_ms":2400,"loop":true,"primary_color":"#FFC107","secondary_color":"#FF5722","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_flame','visual_effect','unisex','لهب متحرك','loop','flame','both','#FFF176','#FF6D00',5000,50,true,true,4,'{"effect_key":"flame","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":1.05,"scale":1.0,"speed":0.9,"particle_count":20,"duration_ms":2400,"loop":true,"primary_color":"#FFF176","secondary_color":"#FF6D00","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_crossed_swords','visual_effect','unisex','سيوف متصارعة','loop','crossed_swords','both','#E0F7FA','#90CAF9',5000,50,true,true,5,'{"effect_key":"crossed_swords","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":1.0,"particle_count":8,"duration_ms":2400,"loop":true,"primary_color":"#E0F7FA","secondary_color":"#90CAF9","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_ice_crystals','visual_effect','unisex','بلورات جليد','loop','ice_crystals','both','#B3E5FC','#FFFFFF',5000,50,true,true,6,'{"effect_key":"ice_crystals","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":1.0,"scale":1.0,"speed":0.7,"particle_count":18,"duration_ms":2400,"loop":true,"primary_color":"#B3E5FC","secondary_color":"#FFFFFF","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_orbiting_stars','visual_effect','unisex','نجوم مدارية','loop','orbiting_stars','both','#FFF59D','#FFFFFF',5000,50,true,true,7,'{"effect_key":"orbiting_stars","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.75,"particle_count":10,"duration_ms":2400,"loop":true,"primary_color":"#FFF59D","secondary_color":"#FFFFFF","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_meteor_shower','visual_effect','unisex','شهب نيزكية','loop','meteor_shower','both','#FFCC80','#FFFFFF',5000,50,true,true,8,'{"effect_key":"meteor_shower","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":1.0,"scale":1.0,"speed":1.2,"particle_count":12,"duration_ms":2400,"loop":true,"primary_color":"#FFCC80","secondary_color":"#FFFFFF","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_neon_rainbow','visual_effect','unisex','نيون قوس قزح','loop','neon_rainbow','both','#FF3DFF','#00E5FF',5000,50,true,true,9,'{"effect_key":"neon_rainbow","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.55,"particle_count":8,"duration_ms":2400,"loop":true,"primary_color":"#FF3DFF","secondary_color":"#00E5FF","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_rotating_ring','visual_effect','unisex','حلقة دوارة','loop','rotating_ring','both','#00E5FF','#7C4DFF',5000,50,true,true,10,'{"effect_key":"rotating_ring","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.7,"particle_count":12,"duration_ms":2400,"loop":true,"primary_color":"#00E5FF","secondary_color":"#7C4DFF","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_spark_burst','visual_effect','unisex','انفجار شرر','loop','spark_burst','both','#FFF59D','#FF8A65',5000,50,true,true,11,'{"effect_key":"spark_burst","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":1.0,"scale":1.0,"speed":1.15,"particle_count":18,"duration_ms":2400,"loop":true,"primary_color":"#FFF59D","secondary_color":"#FF8A65","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_bubbles','visual_effect','unisex','فقاعات','loop','bubbles','both','#80DEEA','#FFFFFF',5000,50,true,true,12,'{"effect_key":"bubbles","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":0.9,"scale":1.0,"speed":0.65,"particle_count":16,"duration_ms":2400,"loop":true,"primary_color":"#80DEEA","secondary_color":"#FFFFFF","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_snow','visual_effect','unisex','تساقط ثلجي','loop','snow','both','#FFFFFF','#B3E5FC',10000,100,true,true,13,'{"effect_key":"snow","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":0.9,"scale":1.0,"speed":0.45,"particle_count":20,"duration_ms":2400,"loop":true,"primary_color":"#FFFFFF","secondary_color":"#B3E5FC","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_petals','visual_effect','unisex','بتلات متطايرة','loop','petals','both','#F48FB1','#FFCDD2',10000,100,true,true,14,'{"effect_key":"petals","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":0.9,"scale":1.0,"speed":0.5,"particle_count":14,"duration_ms":2400,"loop":true,"primary_color":"#F48FB1","secondary_color":"#FFCDD2","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_hearts','visual_effect','unisex','قلوب عائمة','loop','hearts','both','#FF4081','#FF8A80',10000,100,true,true,15,'{"effect_key":"hearts","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":0.9,"scale":1.0,"speed":0.55,"particle_count":12,"duration_ms":2400,"loop":true,"primary_color":"#FF4081","secondary_color":"#FF8A80","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_coins','visual_effect','unisex','عملات دوارة','loop','coins','both','#FFD54F','#FFA000',10000,100,true,true,16,'{"effect_key":"coins","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":0.95,"scale":1.0,"speed":0.75,"particle_count":10,"duration_ms":2400,"loop":true,"primary_color":"#FFD54F","secondary_color":"#FFA000","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_magic_runes','visual_effect','unisex','رموز سحرية','loop','magic_runes','both','#B388FF','#80CBC4',10000,100,true,true,17,'{"effect_key":"magic_runes","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.48,"particle_count":8,"duration_ms":2400,"loop":true,"primary_color":"#B388FF","secondary_color":"#80CBC4","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_plasma_arc','visual_effect','unisex','قوس بلازما','loop','plasma_arc','both','#E040FB','#00E5FF',10000,100,true,true,18,'{"effect_key":"plasma_arc","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.05,"scale":1.0,"speed":0.9,"particle_count":10,"duration_ms":2400,"loop":true,"primary_color":"#E040FB","secondary_color":"#00E5FF","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_cosmic_dust','visual_effect','unisex','غبار كوني','loop','cosmic_dust','both','#B39DDB','#80DEEA',10000,100,true,true,19,'{"effect_key":"cosmic_dust","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":0.75,"scale":1.0,"speed":0.35,"particle_count":24,"duration_ms":2400,"loop":true,"primary_color":"#B39DDB","secondary_color":"#80DEEA","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_solar_flare','visual_effect','unisex','توهج شمسي','loop','solar_flare','both','#FFF176','#FF9800',10000,100,true,true,20,'{"effect_key":"solar_flare","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.38,"particle_count":10,"duration_ms":2400,"loop":true,"primary_color":"#FFF176","secondary_color":"#FF9800","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_shadow_smoke','visual_effect','unisex','دخان ظل','loop','shadow_smoke','both','#90A4AE','#263238',10000,100,true,true,21,'{"effect_key":"shadow_smoke","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":0.7,"scale":1.0,"speed":0.22,"particle_count":16,"duration_ms":2400,"loop":true,"primary_color":"#90A4AE","secondary_color":"#263238","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_wind_blades','visual_effect','unisex','شفرات هواء','loop','wind_blades','both','#B2EBF2','#80CBC4',10000,100,true,true,22,'{"effect_key":"wind_blades","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":1.25,"particle_count":8,"duration_ms":2400,"loop":true,"primary_color":"#B2EBF2","secondary_color":"#80CBC4","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_electric_orbit','visual_effect','unisex','مدار كهربائي','loop','electric_orbit','both','#40C4FF','#FFF176',10000,100,true,true,23,'{"effect_key":"electric_orbit","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":1.0,"particle_count":12,"duration_ms":2400,"loop":true,"primary_color":"#40C4FF","secondary_color":"#FFF176","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_golden_sparkle','visual_effect','unisex','لمعان ذهبي','loop','golden_sparkle','both','#FFD740','#FFF8E1',10000,100,true,true,24,'{"effect_key":"golden_sparkle","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":0.85,"scale":1.0,"speed":0.7,"particle_count":14,"duration_ms":2400,"loop":true,"primary_color":"#FFD740","secondary_color":"#FFF8E1","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_diamond_shine','visual_effect','unisex','بريق ألماسي','loop','diamond_shine','both','#E1F5FE','#FFFFFF',20000,200,true,true,25,'{"effect_key":"diamond_shine","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":0.9,"scale":1.0,"speed":0.58,"particle_count":7,"duration_ms":2400,"loop":true,"primary_color":"#E1F5FE","secondary_color":"#FFFFFF","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_water_wave','visual_effect','unisex','موجة مائية','loop','water_wave','both','#29B6F6','#80DEEA',20000,200,true,true,26,'{"effect_key":"water_wave","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":0.75,"scale":1.0,"speed":0.42,"particle_count":8,"duration_ms":2400,"loop":true,"primary_color":"#29B6F6","secondary_color":"#80DEEA","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_rose_petal','visual_effect','unisex','بتلات ورد','loop','rose_petal','both','#F06292','#CE93D8',20000,200,true,true,27,'{"effect_key":"rose_petal","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"particle","engine":"particle","intensity":0.9,"scale":1.0,"speed":0.48,"particle_count":12,"duration_ms":2400,"loop":true,"primary_color":"#F06292","secondary_color":"#CE93D8","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_phoenix','visual_effect','unisex','طائر العنقاء','loop','phoenix','both','#FFD740','#FF6D00',20000,200,true,true,28,'{"effect_key":"phoenix","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.05,"scale":1.0,"speed":0.65,"particle_count":22,"duration_ms":2400,"loop":true,"primary_color":"#FFD740","secondary_color":"#FF6D00","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_comet','visual_effect','unisex','مذنب دوار','loop','comet','both','#E1F5FE','#69F0AE',20000,200,true,true,29,'{"effect_key":"comet","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.7,"particle_count":9,"duration_ms":2400,"loop":true,"primary_color":"#E1F5FE","secondary_color":"#69F0AE","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_vortex','visual_effect','unisex','دوامة طاقة حقيقية 100%','loop','vortex','both','#00E5FF','#7C4DFF',50000,500,true,true,30,'{"effect_key":"vortex","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.15,"scale":1.0,"speed":0.7,"particle_count":34,"duration_ms":2400,"loop":true,"primary_color":"#00E5FF","secondary_color":"#7C4DFF","layer":"around","version":1,"is_featured":true}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();

-- Preserve the current catalog RPC but let the platform owner see inactive visual-effect rows for administration.
create or replace function public.get_profile_cosmetic_catalog(p_category text default null,p_gender text default null)
returns setof public.profile_cosmetic_catalog
language sql stable security definer set search_path = ''
as $$
  select c.* from public.profile_cosmetic_catalog c
  where (c.is_active=true or (c.category='visual_effect' and public.is_platform_owner(auth.uid())))
    and (p_category is null or c.category=p_category)
    and (p_gender is null or c.gender=p_gender)
  order by c.category,c.gender,c.sort_order;
$$;

create or replace function public.set_visual_effect(p_effect_key text,p_placement text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid:=auth.uid();
  v_effect text:=lower(trim(coalesce(p_effect_key,'')));
  v_placement text:=lower(trim(coalesce(p_placement,'')));
  v_item public.profile_cosmetic_catalog%rowtype;
  v_owner boolean:=false;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_placement not in ('username','avatar','both') then raise exception 'PLACEMENT_NOT_ALLOWED'; end if;

  if v_effect='' or v_effect='none' then
    if v_placement in ('username','both') then
      insert into public.gamification_stats(user_id,username_effect) values(v_uid,'none')
      on conflict(user_id) do update set username_effect='none',updated_at=now();
    end if;
    if v_placement in ('avatar','both') then
      update public.profiles set avatar_visual_effect_key=null,updated_at=now() where id=v_uid;
      if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
    else
      update public.profiles set updated_at=now() where id=v_uid;
    end if;
    return jsonb_build_object('status','cleared','effect_key','none','placement',v_placement);
  end if;

  select c.* into v_item from public.profile_cosmetic_catalog c
  where c.item_key='visualfx_'||v_effect and c.category='visual_effect' and c.is_active=true;
  if not found then raise exception 'EFFECT_NOT_AVAILABLE'; end if;
  if not (coalesce(v_item.metadata->'supported_targets','[]'::jsonb) ? v_placement)
     or (coalesce(v_item.metadata->>'placement','both')<>'both' and coalesce(v_item.metadata->>'placement','both')<>v_placement) then raise exception 'PLACEMENT_NOT_ALLOWED'; end if;

  v_owner:=coalesce(public.is_platform_owner(v_uid),false);
  if not v_owner and not exists(select 1 from public.profile_cosmetic_purchases p where p.user_id=v_uid and p.item_key=v_item.item_key) then
    raise exception 'ITEM_NOT_OWNED';
  end if;

  if v_placement in ('username','both') then
    insert into public.gamification_stats(user_id,username_effect) values(v_uid,v_effect)
    on conflict(user_id) do update set username_effect=excluded.username_effect,updated_at=now();
  end if;
  if v_placement in ('avatar','both') then
    update public.profiles set avatar_visual_effect_key=v_effect,updated_at=now() where id=v_uid;
    if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  else
    update public.profiles set updated_at=now() where id=v_uid;
  end if;
  return jsonb_build_object('status','equipped','effect_key',v_effect,'placement',v_placement,'item_key',v_item.item_key);
end;
$$;

-- Bridge existing username storage to the same visual-effect catalog without breaking legacy username_effect_catalog entries.
create or replace function public.set_username_effect(p_effect text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid:=auth.uid();
  v_owner boolean:=false;
  v_effect text:=trim(coalesce(p_effect,'none'));
  v_item_key text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_effect='none' then
    insert into public.gamification_stats(user_id,username_effect) values(v_uid,'none')
    on conflict(user_id) do update set username_effect='none',updated_at=now();
    update public.profiles set updated_at=now() where id=v_uid;
    return;
  end if;
  v_owner:=coalesce(public.is_platform_owner(v_uid),false);
  select c.item_key into v_item_key from public.profile_cosmetic_catalog c
  where c.category='visual_effect' and c.is_active=true and c.metadata->>'effect_key'=v_effect limit 1;
  if v_item_key is null then
    if not exists(select 1 from public.username_effect_catalog c where c.effect_key=v_effect and c.is_active=true) then raise exception 'EFFECT_NOT_AVAILABLE'; end if;
    if not v_owner and not exists(
      select 1 from public.profile_cosmetic_purchases p join public.profile_cosmetic_catalog c on c.item_key=p.item_key
      where p.user_id=v_uid and c.category='name_effect' and c.is_active=true and c.metadata->>'effect_key'=v_effect
    ) then raise exception 'ITEM_NOT_OWNED'; end if;
  elsif not v_owner and not exists(select 1 from public.profile_cosmetic_purchases p where p.user_id=v_uid and p.item_key=v_item_key) then
    raise exception 'ITEM_NOT_OWNED';
  end if;
  insert into public.gamification_stats(user_id,username_effect) values(v_uid,v_effect)
  on conflict(user_id) do update set username_effect=excluded.username_effect,updated_at=now();
  update public.profiles set updated_at=now() where id=v_uid;
end;
$$;

-- Existing chat identity JSON contract + independent avatar visual effect key.
create or replace function public.get_user_chat_identity(p_user_id uuid,p_room_id uuid default null)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_profile record;
  v_stats record;
  v_global_role_code text;
  v_global_role_name text;
  v_global_role_priority integer:=0;
  v_room_role_code text;
  v_room_role_name text;
  v_room_role_priority integer:=0;
  v_role_code text;
  v_role_name text;
  v_role_priority integer:=0;
  v_rank_id text;
  v_rank_level integer:=1;
  v_manual_rank integer:=0;
  v_xp bigint:=0;
  v_rank_name text;
  v_rank_badge_key text;
  v_badges jsonb:='[]'::jsonb;
begin
  select p.id,p.username,p.display_name,p.avatar_url,p.animated_avatar_url,p.chat_badge_url,
    p.username_color,p.username_shine,p.username_font_size,p.username_font_family,p.message_color,p.message_font_family,
    p.status_text,p.status_color,p.status_font_size,p.status_bold,p.status_italic,p.username_background_key,p.username_background_mode,
    p.username_background_color1,p.username_background_color2,p.username_background_opacity,p.username_background_external_effect,
    p.avatar_frame_key,p.avatar_visual_effect_key
  into v_profile from public.profiles p where p.id=p_user_id and p.is_active=true and p.is_suspended=false;
  if p_user_id is null or v_profile.id is null then
    return jsonb_build_object('user_id',p_user_id,'username','عضو','display_name','عضو',
      'role',jsonb_build_object('code','visitor','name','زائر','priority',0,'scope','fallback','room_id',p_room_id),
      'rank',jsonb_build_object('id','rookie','level',1,'xp',0,'manual_rank',0,'name','مبتدئ','badge_key','rank_rookie'),
      'chat_badge',null,'chat_badge_url',null,'achievement_badges','[]'::jsonb,'status_text','',
      'status_color',null,'status_font_size',12.5,'status_bold',false,'status_italic',false,'username_color',null,'username_shine',false,
      'username_font_size',22,'username_effect','none','username_font_family','noto_kufi_arabic','message_color',4294967295,'message_font_family','cairo',
      'username_background_key',null,'username_background_mode',null,'username_background_color1',null,'username_background_color2',null,
      'username_background_opacity',0.82,'username_background_external_effect',null,'avatar_url',null,'animated_avatar_url',null,
      'avatar_frame_key',null,'avatar_visual_effect_key',null);
  end if;

  select gs.xp,gs.rank_level,gs.rank_id,gs.manual_rank,gs.badges,gs.username_effect into v_stats
  from public.gamification_stats gs where gs.user_id=p_user_id;
  v_xp:=coalesce(v_stats.xp,0); v_rank_level:=greatest(coalesce(v_stats.rank_level,1),1);
  v_rank_id:=lower(coalesce(nullif(trim(v_stats.rank_id),''),'rookie')); v_manual_rank:=greatest(coalesce(v_stats.manual_rank,0),0);
  v_badges:=case when jsonb_typeof(coalesce(v_stats.badges,'[]'::jsonb))='array' then coalesce(v_stats.badges,'[]'::jsonb) else '[]'::jsonb end;

  if public._is_platform_owner(p_user_id) then
    v_role_code:='dragon'; v_role_name:='مالك المنصة'; v_role_priority:=1000;
  else
    if p_room_id is not null then
      select r.role_key,r.name,coalesce(r.priority,0) into v_room_role_code,v_room_role_name,v_room_role_priority
      from public.chat_room_members m join public.chat_room_roles r on r.id=m.role_id
      where m.room_id=p_room_id and m.user_id=p_user_id order by coalesce(r.priority,0) desc limit 1;
    end if;
    select r.code,r.name,coalesce(r.priority,0) into v_global_role_code,v_global_role_name,v_global_role_priority
    from public.user_roles ur join public.roles r on r.id=ur.role_id
    where ur.user_id=p_user_id order by coalesce(r.priority,0) desc limit 1;
    if v_room_role_code is not null then v_role_code:=v_room_role_code; v_role_name:=v_room_role_name; v_role_priority:=v_room_role_priority;
    elsif v_global_role_code is not null then v_role_code:=v_global_role_code; v_role_name:=v_global_role_name; v_role_priority:=v_global_role_priority;
    else v_role_code:='user'; v_role_name:='عضو'; v_role_priority:=0; end if;
  end if;

  if v_rank_id not in ('rookie','bronze','silver','gold','platinum','diamond','legend') then v_rank_id:='rookie'; end if;
  v_rank_name:=case v_rank_id when 'bronze' then 'برونزي' when 'silver' then 'فضي' when 'gold' then 'ذهبي' when 'platinum' then 'بلاتيني' when 'diamond' then 'ماسي' when 'legend' then 'أسطورة' else 'مبتدئ' end;
  v_rank_badge_key:='rank_'||v_rank_id;

  return jsonb_build_object('user_id',p_user_id,'username',v_profile.username,'display_name',v_profile.display_name,
    'role',jsonb_build_object('code',v_role_code,'name',v_role_name,'priority',v_role_priority,'scope',case when v_room_role_code is not null and v_role_code<>'dragon' then 'room' else 'global' end,'room_id',p_room_id),
    'rank',jsonb_build_object('id',v_rank_id,'level',v_rank_level,'xp',v_xp,'manual_rank',v_manual_rank,'name',v_rank_name,'badge_key',v_rank_badge_key),
    'chat_badge',case when v_profile.chat_badge_url is null or trim(v_profile.chat_badge_url)='' then null else jsonb_build_object('url',v_profile.chat_badge_url) end,
    'chat_badge_url',v_profile.chat_badge_url,'achievement_badges',v_badges,'status_text',coalesce(v_profile.status_text,''),'status_color',v_profile.status_color,
    'status_font_size',coalesce(v_profile.status_font_size,12.5),'status_bold',coalesce(v_profile.status_bold,false),'status_italic',coalesce(v_profile.status_italic,false),
    'username_color',v_profile.username_color,'username_shine',coalesce(v_profile.username_shine,false),'username_font_size',coalesce(v_profile.username_font_size,22),
    'username_effect',coalesce(nullif(trim(v_stats.username_effect),''),'none'),'username_font_family',coalesce(nullif(trim(v_profile.username_font_family),''),'noto_kufi_arabic'),
    'message_color',coalesce(v_profile.message_color,4294967295),'message_font_family',coalesce(nullif(trim(v_profile.message_font_family),''),'cairo'),
    'username_background_key',v_profile.username_background_key,'username_background_mode',v_profile.username_background_mode,
    'username_background_color1',v_profile.username_background_color1,'username_background_color2',v_profile.username_background_color2,
    'username_background_opacity',coalesce(v_profile.username_background_opacity,.82),'username_background_external_effect',v_profile.username_background_external_effect,
    'avatar_url',v_profile.avatar_url,'animated_avatar_url',v_profile.animated_avatar_url,'avatar_frame_key',v_profile.avatar_frame_key,
    'avatar_visual_effect_key',v_profile.avatar_visual_effect_key);
end;
$$;

drop function if exists public.get_public_profile_cosmetics(uuid);
create function public.get_public_profile_cosmetics(p_user_id uuid)
returns table(
 id uuid,username text,display_name text,email text,bio text,avatar_url text,cover_url text,status_text text,
 profile_music_url text,profile_music_duration_ms integer,profile_music_size_bytes bigint,country text,city text,profession text,
 experiences jsonb,social_links jsonb,verified boolean,visibility text,account_type text,username_color bigint,username_shine boolean,
 username_font_size double precision,status_font_size double precision,status_bold boolean,status_italic boolean,status_color bigint,
 animated_avatar_url text,chat_badge_url text,avatar_frame_key text,username_effect text,username_background_key text,
 username_background_mode text,username_background_color1 text,username_background_color2 text,username_background_opacity double precision,
 username_background_external_effect text,role_code text,created_at timestamptz,updated_at timestamptz,avatar_visual_effect_key text)
language sql stable security definer set search_path = ''
as $$
  select p.id,p.username,p.display_name,case when auth.uid()=p.id then coalesce(p.email,'') else '' end,p.bio,p.avatar_url,p.cover_url,p.status_text,
    p.profile_music_url,p.profile_music_duration_ms,p.profile_music_size_bytes,p.country,p.city,p.profession,coalesce(p.experiences,'[]'::jsonb),coalesce(p.social_links,'[]'::jsonb),
    coalesce(p.verified,false),coalesce(p.visibility,'public'),coalesce(p.account_type,'individual'),p.username_color,coalesce(p.username_shine,false),p.username_font_size,p.status_font_size,
    coalesce(p.status_bold,false),coalesce(p.status_italic,false),p.status_color,p.animated_avatar_url,p.chat_badge_url,p.avatar_frame_key,coalesce(gs.username_effect,'none'),
    p.username_background_key,p.username_background_mode,p.username_background_color1,p.username_background_color2,coalesce(p.username_background_opacity,.82),p.username_background_external_effect,
    coalesce((select r.code from public.user_roles ur join public.roles r on r.id=ur.role_id where ur.user_id=p.id order by r.priority desc,r.code asc limit 1),'user'),p.created_at,p.updated_at,p.avatar_visual_effect_key
  from public.profiles p left join public.gamification_stats gs on gs.user_id=p.id
  where p.id=p_user_id and p.is_active=true and p.is_suspended=false
    and (p.id=auth.uid() or private.has_permission('users.read') or public.is_platform_owner(auth.uid())
      or (coalesce(p.visibility,'public')='public' and not public.has_profile_service_for_user(p.id,'hide_profile')));
$$;

create or replace function public.update_profile_visual_effect(
 p_effect_key text,p_price_points bigint,p_price_gems bigint,p_is_active boolean,p_sort_order integer,p_placement text default 'both',p_is_featured boolean default false)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid:=auth.uid(); v_item public.profile_cosmetic_catalog%rowtype; v_swap_key text; v_old_sort integer;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not coalesce(public.is_platform_owner(v_uid),false) then raise exception 'FORBIDDEN'; end if;
  if nullif(trim(p_effect_key),'') is null then raise exception 'ITEM_REQUIRED'; end if;
  if p_price_points is null or p_price_gems is null or p_price_points<0 or p_price_gems<0 then raise exception 'INVALID_PRICE'; end if;
  if p_sort_order is null or p_sort_order<1 then raise exception 'INVALID_SORT_ORDER'; end if;
  if lower(trim(coalesce(p_placement,''))) not in ('username','avatar','both') then raise exception 'PLACEMENT_NOT_ALLOWED'; end if;
  select * into v_item from public.profile_cosmetic_catalog where item_key=trim(p_effect_key) and category='visual_effect' for update;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;
  v_old_sort:=v_item.sort_order;
  if p_sort_order<>v_old_sort then
    select item_key into v_swap_key from public.profile_cosmetic_catalog
    where category='visual_effect' and gender='unisex' and sort_order=p_sort_order and item_key<>v_item.item_key limit 1 for update;
    if v_swap_key is not null then update public.profile_cosmetic_catalog set sort_order=-(p_sort_order+100000),updated_at=now() where item_key=v_swap_key; end if;
  end if;
  update public.profile_cosmetic_catalog set price_points=p_price_points,price_gems=p_price_gems,is_active=coalesce(p_is_active,true),sort_order=p_sort_order,
    metadata=jsonb_set(jsonb_set(jsonb_set(coalesce(metadata,'{}'::jsonb),'{placement}',to_jsonb(lower(trim(p_placement)))), '{target}',to_jsonb(lower(trim(p_placement)))), '{is_featured}',to_jsonb(coalesce(p_is_featured,false))),updated_at=now()
  where item_key=v_item.item_key;
  if v_swap_key is not null then update public.profile_cosmetic_catalog set sort_order=v_old_sort,updated_at=now() where item_key=v_swap_key; end if;
end;
$$;

revoke all on function public.set_visual_effect(text,text) from public;
grant execute on function public.set_visual_effect(text,text) to authenticated;
revoke all on function public.update_profile_visual_effect(text,bigint,bigint,boolean,integer,text,boolean) from public;
grant execute on function public.update_profile_visual_effect(text,bigint,bigint,boolean,integer,text,boolean) to authenticated;
grant execute on function public.get_profile_cosmetic_catalog(text,text) to authenticated;
grant execute on function public.get_public_profile_cosmetics(uuid) to anon,authenticated;
grant execute on function public.get_user_chat_identity(uuid,uuid) to authenticated;
grant execute on function public.set_username_effect(text) to authenticated;

commit;
