-- MASHAREENA: Effects Engine contract completion (31..50) + authoritative economy hardening.
-- Generated from the execution contract; additive and idempotent.
begin;

alter table public.profile_cosmetic_catalog
  drop constraint if exists profile_cosmetic_catalog_category_check;
alter table public.profile_cosmetic_catalog
  add constraint profile_cosmetic_catalog_category_check
  check (category = any (array['frame','background','name_effect','message_color','visual_effect']::text[]));

alter table public.profiles add column if not exists avatar_visual_effect_key text;

insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_aurora_ribbon','visual_effect','unisex','شفق راقص','loop','aurora_ribbon','both','#80D8FF','#B388FF',10000,100,false,true,31,'{"effect_key":"aurora_ribbon","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.42,"particle_count":18,"duration_ms":2400,"loop":true,"primary_color":"#80D8FF","secondary_color":"#B388FF","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_laser_sweep','visual_effect','unisex','مسح ليزري','loop','laser_sweep','both','#FF1744','#00E5FF',10000,100,false,true,32,'{"effect_key":"laser_sweep","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.8,"particle_count":6,"duration_ms":2400,"loop":true,"primary_color":"#FF1744","secondary_color":"#00E5FF","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_hologram_scan','visual_effect','unisex','مسح هولوغرافي','loop','hologram_scan','both','#00E5FF','#7C4DFF',10000,100,false,true,33,'{"effect_key":"hologram_scan","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.55,"particle_count":10,"duration_ms":2400,"loop":true,"primary_color":"#00E5FF","secondary_color":"#7C4DFF","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_galaxy_swirl','visual_effect','unisex','مجرة دوارة','loop','galaxy_swirl','both','#7C4DFF','#E040FB',10000,100,false,true,34,'{"effect_key":"galaxy_swirl","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.38,"particle_count":22,"duration_ms":2400,"loop":true,"primary_color":"#7C4DFF","secondary_color":"#E040FB","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_orbiting_planets','visual_effect','unisex','كواكب مدارية','loop','orbiting_planets','both','#80DEEA','#FFD54F',10000,100,false,true,35,'{"effect_key":"orbiting_planets","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.46,"particle_count":5,"duration_ms":2400,"loop":true,"primary_color":"#80DEEA","secondary_color":"#FFD54F","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_electric_storm','visual_effect','unisex','عاصفة كهربائية','loop','electric_storm','both','#B388FF','#40C4FF',10000,100,false,true,36,'{"effect_key":"electric_storm","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.9,"particle_count":16,"duration_ms":2400,"loop":true,"primary_color":"#B388FF","secondary_color":"#40C4FF","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_crystal_shards','visual_effect','unisex','شظايا كريستال','loop','crystal_shards','both','#E1F5FE','#B39DDB',10000,100,false,true,37,'{"effect_key":"crystal_shards","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.7,"particle_count":14,"duration_ms":2400,"loop":true,"primary_color":"#E1F5FE","secondary_color":"#B39DDB","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_starfield','visual_effect','unisex','حقل نجوم','loop','starfield','both','#FFFFFF','#FFF59D',10000,100,false,true,38,'{"effect_key":"starfield","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.25,"particle_count":28,"duration_ms":2400,"loop":true,"primary_color":"#FFFFFF","secondary_color":"#FFF59D","layer":"behind","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_arcane_portal','visual_effect','unisex','بوابة سحرية','loop','arcane_portal','both','#7C4DFF','#EA80FC',10000,100,false,true,39,'{"effect_key":"arcane_portal","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.5,"particle_count":16,"duration_ms":2400,"loop":true,"primary_color":"#7C4DFF","secondary_color":"#EA80FC","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_celestial_wings','visual_effect','unisex','أجنحة سماوية','loop','celestial_wings','both','#E1F5FE','#FFFFFF',10000,100,false,true,40,'{"effect_key":"celestial_wings","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.48,"particle_count":12,"duration_ms":2400,"loop":true,"primary_color":"#E1F5FE","secondary_color":"#FFFFFF","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_butterfly_swarm','visual_effect','unisex','سرب فراشات','loop','butterfly_swarm','both','#FF80AB','#B388FF',10000,100,false,true,41,'{"effect_key":"butterfly_swarm","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.34,"particle_count":10,"duration_ms":2400,"loop":true,"primary_color":"#FF80AB","secondary_color":"#B388FF","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_autumn_leaves','visual_effect','unisex','أوراق خريف','loop','autumn_leaves','both','#FFB74D','#FF7043',10000,100,false,true,42,'{"effect_key":"autumn_leaves","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.36,"particle_count":14,"duration_ms":2400,"loop":true,"primary_color":"#FFB74D","secondary_color":"#FF7043","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_ember_rain','visual_effect','unisex','مطر جمر','loop','ember_rain','both','#FFD54F','#FF6D00',10000,100,false,true,43,'{"effect_key":"ember_rain","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.75,"particle_count":20,"duration_ms":2400,"loop":true,"primary_color":"#FFD54F","secondary_color":"#FF6D00","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_lava_flow','visual_effect','unisex','تدفق حمم','loop','lava_flow','both','#FF9800','#FF5722',10000,100,false,true,44,'{"effect_key":"lava_flow","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.28,"particle_count":10,"duration_ms":2400,"loop":true,"primary_color":"#FF9800","secondary_color":"#FF5722","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_poison_bubbles','visual_effect','unisex','فقاعات سامة','loop','poison_bubbles','both','#76FF03','#B2FF59',20000,200,false,true,45,'{"effect_key":"poison_bubbles","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.31,"particle_count":14,"duration_ms":2400,"loop":true,"primary_color":"#76FF03","secondary_color":"#B2FF59","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_moon_dust','visual_effect','unisex','غبار قمري','loop','moon_dust','both','#CFD8DC','#90CAF9',20000,200,false,true,46,'{"effect_key":"moon_dust","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.22,"particle_count":24,"duration_ms":2400,"loop":true,"primary_color":"#CFD8DC","secondary_color":"#90CAF9","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_water_droplets','visual_effect','unisex','قطرات مائية','loop','water_droplets','both','#29B6F6','#81D4FA',20000,200,false,true,47,'{"effect_key":"water_droplets","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.6,"particle_count":18,"duration_ms":2400,"loop":true,"primary_color":"#29B6F6","secondary_color":"#81D4FA","layer":"front","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_sonic_rings','visual_effect','unisex','حلقات صوتية','loop','sonic_rings','both','#00E5FF','#FFFFFF',20000,200,false,true,48,'{"effect_key":"sonic_rings","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.52,"particle_count":8,"duration_ms":2400,"loop":true,"primary_color":"#00E5FF","secondary_color":"#FFFFFF","layer":"around","version":1,"is_featured":false}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_golden_crown','visual_effect','unisex','تاج ذهبي','loop','golden_crown','both','#FFD740','#FFF8E1',20000,200,false,true,49,'{"effect_key":"golden_crown","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.4,"particle_count":7,"duration_ms":2400,"loop":true,"primary_color":"#FFD740","secondary_color":"#FFF8E1","layer":"front","version":1,"is_featured":true}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();
insert into public.profile_cosmetic_catalog(item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata) values ('visualfx_royal_aura','visual_effect','unisex','هالة ملكية','loop','royal_aura','both','#FFD740','#7C4DFF',20000,200,false,true,50,'{"effect_key":"royal_aura","effect_family":"visual","target":"both","placement":"both","supported_targets":["username","avatar","both"],"animation":true,"renderer":"custom_painter","engine":"custom_painter","intensity":1.0,"scale":1.0,"speed":0.33,"particle_count":12,"duration_ms":2400,"loop":true,"primary_color":"#FFD740","secondary_color":"#7C4DFF","layer":"behind","version":1,"is_featured":true}'::jsonb) on conflict (item_key) do update set category=excluded.category,gender=excluded.gender,name_ar=excluded.name_ar,animation_mode=excluded.animation_mode,palette_key=excluded.palette_key,mode_variant=excluded.mode_variant,color1=excluded.color1,color2=excluded.color2,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();


-- Server-authoritative visual-effect purchase. The platform owner is identified only by the existing
-- platform authority helper; client-supplied flags/balances/prices are never trusted.
create or replace function public.purchase_profile_cosmetic(
  p_item_key text,
  p_currency text,
  p_request_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_key text := lower(trim(coalesce(p_item_key,'')));
  v_currency text := lower(trim(coalesce(p_currency,'')));
  v_item public.profile_cosmetic_catalog%rowtype;
  v_price bigint := 0;
  v_before bigint := 0;
  v_after bigint := 0;
  v_owner boolean := false;
  v_existing public.idempotency_requests%rowtype;
  v_response jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
  if v_currency not in ('points','gems') then raise exception 'INVALID_CURRENCY'; end if;

  select * into v_existing from public.idempotency_requests where request_id=p_request_id for update;
  if found then
    if v_existing.user_id <> v_uid or v_existing.operation <> 'purchase_profile_cosmetic'
       or coalesce(v_existing.response->>'item_key','') <> v_key
       or coalesce(v_existing.response->>'currency','') not in (v_currency,'owner_free') then
      raise exception 'REQUEST_ID_REPLAY_FORBIDDEN';
    end if;
    return v_existing.response;
  end if;

  select * into v_item
  from public.profile_cosmetic_catalog
  where item_key=v_key and is_active=true
  for update;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;

  v_owner := coalesce(public.is_platform_owner(v_uid),false);
  v_price := case when v_currency='points' then coalesce(v_item.price_points,0) else coalesce(v_item.price_gems,0) end;
  if v_price < 0 then raise exception 'INVALID_PRICE'; end if;

  if exists(select 1 from public.profile_cosmetic_purchases p where p.user_id=v_uid and p.item_key=v_key) then
    v_response := jsonb_build_object('ok',true,'item_key',v_key,'currency',v_currency,'amount',0,'already_owned',true,'request_id',p_request_id,'owner',v_owner);
    insert into public.idempotency_requests(request_id,user_id,operation,response) values(p_request_id,v_uid,'purchase_profile_cosmetic',v_response);
    return v_response;
  end if;

  if v_owner or (coalesce(v_item.owner_free,false) and v_item.category <> 'visual_effect') then
    insert into public.profile_cosmetic_purchases(user_id,item_key,currency,amount)
    values(v_uid,v_key,'owner_free',0)
    on conflict(user_id,item_key) do nothing;
    v_response := jsonb_build_object('ok',true,'item_key',v_key,'currency','owner_free','amount',0,'owner',v_owner,'request_id',p_request_id);
    insert into public.idempotency_requests(request_id,user_id,operation,response) values(p_request_id,v_uid,'purchase_profile_cosmetic',v_response);
    return v_response;
  end if;

  if v_price <= 0 then raise exception 'PRICE_NOT_SET'; end if;

  if v_currency='points' then
    perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':cosmetic:points',0));
    insert into public.points_wallets(user_id,balance) values(v_uid,0) on conflict(user_id) do nothing;
    select balance into v_before from public.points_wallets where user_id=v_uid for update;
    if coalesce(v_before,0) < v_price then raise exception 'INSUFFICIENT_POINTS'; end if;
    v_after := v_before-v_price;
    update public.points_wallets set balance=v_after,lifetime_spent=lifetime_spent+v_price,version=version+1,updated_at=now() where user_id=v_uid;
  else
    perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':cosmetic:gems',0));
    insert into public.gems_wallets(user_id,balance) values(v_uid,0) on conflict(user_id) do nothing;
    select balance into v_before from public.gems_wallets where user_id=v_uid for update;
    if coalesce(v_before,0) < v_price then raise exception 'INSUFFICIENT_GEMS'; end if;
    v_after := v_before-v_price;
    update public.gems_wallets set balance=v_after,lifetime_spent=lifetime_spent+v_price,version=version+1,updated_at=now() where user_id=v_uid;
  end if;

  insert into public.profile_cosmetic_purchases(user_id,item_key,currency,amount)
  values(v_uid,v_key,v_currency,v_price);

  insert into public.wallet_transactions(user_id,currency,amount,balance_before,balance_after,transaction_type,reference_type,reference_id,idempotency_key,metadata,created_by)
  values(v_uid,v_currency,-v_price,v_before,v_after,'profile_cosmetic_purchase','profile_cosmetic',v_key,p_request_id,jsonb_build_object('item_key',v_key),v_uid);

  v_response := jsonb_build_object('ok',true,'item_key',v_key,'currency',v_currency,'amount',v_price,'owner',false,'request_id',p_request_id);
  insert into public.idempotency_requests(request_id,user_id,operation,response) values(p_request_id,v_uid,'purchase_profile_cosmetic',v_response);
  return v_response;
end;
$$;

revoke all on function public.purchase_profile_cosmetic(text,text,uuid) from public, anon;
grant execute on function public.purchase_profile_cosmetic(text,text,uuid) to authenticated;

-- Gifts: owner may send any enabled gift without debiting a limited points wallet.
-- Normal accounts remain balance-limited. Receiver payout stays server-side and replay-safe.
create or replace function public.send_gift_atomic(
  p_to_uid uuid,
  p_gift_id text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_gift public.gift_catalog%rowtype;
  v_owner boolean := false;
  v_before bigint := 0;
  v_after bigint := 0;
  v_receiver_gems bigint := 0;
  v_tx public.gift_transactions%rowtype;
  v_existing public.gift_transactions%rowtype;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
  if p_to_uid is null or p_to_uid=v_uid then raise exception 'INVALID_PARTICIPANT'; end if;

  select * into v_existing from public.gift_transactions where idempotency_key=p_request_id;
  if found then
    if v_existing.from_uid<>v_uid or v_existing.to_uid<>p_to_uid or v_existing.gift_id<>p_gift_id then raise exception 'REQUEST_ID_REPLAY_FORBIDDEN'; end if;
    return jsonb_build_object('transactionId',v_existing.id,'giftId',v_existing.gift_id,'fromUid',v_existing.from_uid,'toUid',v_existing.to_uid,'pricePaid',v_existing.price_points,'idempotent',true);
  end if;

  if not exists(select 1 from public.profiles where id=p_to_uid and is_active=true and is_suspended=false) then raise exception 'INVALID_PARTICIPANT'; end if;
  select * into v_gift from public.gift_catalog where id=p_gift_id and enabled=true;
  if not found then raise exception 'GIFT_NOT_FOUND'; end if;
  if coalesce(v_gift.price_points,0) < 0 then raise exception 'INVALID_GIFT_PRICE'; end if;

  v_owner := coalesce(public.is_platform_owner(v_uid),false);
  if not v_owner then
    perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':gift:points',0));
    insert into public.points_wallets(user_id,balance) values(v_uid,0) on conflict(user_id) do nothing;
    select balance into v_before from public.points_wallets where user_id=v_uid for update;
    if coalesce(v_before,0) < v_gift.price_points then raise exception 'INSUFFICIENT_POINTS'; end if;
    v_after := v_before-v_gift.price_points;
    update public.points_wallets set balance=v_after,lifetime_spent=lifetime_spent+v_gift.price_points,version=version+1,updated_at=now() where user_id=v_uid;
  end if;

  v_receiver_gems := floor(coalesce(v_gift.price_points,0) * 0.70);
  insert into public.gift_transactions(gift_id,from_uid,to_uid,price_points,idempotency_key,metadata)
  values(v_gift.id,v_uid,p_to_uid,v_gift.price_points,p_request_id,jsonb_build_object('owner_free',v_owner,'receiver_gems',v_receiver_gems))
  returning * into v_tx;

  if not v_owner then
    insert into public.wallet_transactions(user_id,currency,amount,balance_before,balance_after,transaction_type,reference_type,reference_id,idempotency_key,metadata,created_by)
    values(v_uid,'points',-v_gift.price_points,v_before,v_after,'gift_sent','gift',v_gift.id,p_request_id,jsonb_build_object('to_uid',p_to_uid),v_uid);
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_to_uid::text || ':gift:gems',0));
  insert into public.gems_wallets(user_id,balance) values(p_to_uid,0) on conflict(user_id) do nothing;
  if v_receiver_gems>0 then
    update public.gems_wallets set balance=balance+v_receiver_gems,lifetime_earned=lifetime_earned+v_receiver_gems,version=version+1,updated_at=now() where user_id=p_to_uid;
    insert into public.wallet_transactions(user_id,currency,amount,balance_before,balance_after,transaction_type,reference_type,reference_id,idempotency_key,metadata,created_by)
    select p_to_uid,'gems',v_receiver_gems,balance-v_receiver_gems,balance,'gift_received','gift',v_gift.id,p_request_id,jsonb_build_object('from_uid',v_uid),v_uid
    from public.gems_wallets where user_id=p_to_uid;
  end if;

  return jsonb_build_object('transactionId',v_tx.id,'giftId',v_tx.gift_id,'fromUid',v_tx.from_uid,'toUid',v_tx.to_uid,'pricePaid',v_tx.price_points,'ownerFree',v_owner,'receiverGems',v_receiver_gems,'idempotent',false);
end;
$$;

revoke all on function public.send_gift_atomic(uuid,text,uuid) from public, anon;
grant execute on function public.send_gift_atomic(uuid,text,uuid) to authenticated;

commit;
