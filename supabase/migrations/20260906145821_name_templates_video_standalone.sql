-- MASHAREENA: 50 video-reference NAME TEMPLATES as an independent cosmetic category.
-- They do NOT use VisualEffectEngine, VisualEffectRegistry, UsernameEffect, or avatar effects.
-- The first 10 are direct crops from the supplied video reference; 11-50 are distinct structural variants in the same visual language.
begin;

alter table public.profile_cosmetic_catalog
  drop constraint if exists profile_cosmetic_catalog_category_check;
alter table public.profile_cosmetic_catalog
  add constraint profile_cosmetic_catalog_category_check
  check (category = any (array['frame','background','name_effect','message_color','visual_effect','name_template']::text[]));

alter table public.profiles add column if not exists username_template_key text;

insert into public.profile_cosmetic_catalog(
  item_key,category,gender,name_ar,animation_mode,palette_key,mode_variant,
  color1,color2,price_points,price_gems,owner_free,is_active,sort_order,metadata
) values
  ('name_template_01','name_template','unisex','قالب اسم الفيديو 01','loop','video_reference','standalone','#FFFFFF','#FFFFFF',5000,50,false,true,1,'{"template_key":"name_template_01","asset":"assets/name_templates/name_template_01.png","reference_video_index":1,"variant_group":0,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_02','name_template','unisex','قالب اسم الفيديو 02','loop','video_reference','standalone','#FFFFFF','#FFFFFF',6000,60,false,true,2,'{"template_key":"name_template_02","asset":"assets/name_templates/name_template_02.png","reference_video_index":2,"variant_group":0,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_03','name_template','unisex','قالب اسم الفيديو 03','loop','video_reference','standalone','#FFFFFF','#FFFFFF',7000,70,false,true,3,'{"template_key":"name_template_03","asset":"assets/name_templates/name_template_03.png","reference_video_index":3,"variant_group":0,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_04','name_template','unisex','قالب اسم الفيديو 04','loop','video_reference','standalone','#FFFFFF','#FFFFFF',8000,80,false,true,4,'{"template_key":"name_template_04","asset":"assets/name_templates/name_template_04.png","reference_video_index":4,"variant_group":0,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_05','name_template','unisex','قالب اسم الفيديو 05','loop','video_reference','standalone','#FFFFFF','#FFFFFF',9000,90,false,true,5,'{"template_key":"name_template_05","asset":"assets/name_templates/name_template_05.png","reference_video_index":5,"variant_group":0,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_06','name_template','unisex','قالب اسم الفيديو 06','loop','video_reference','standalone','#FFFFFF','#FFFFFF',10000,100,false,true,6,'{"template_key":"name_template_06","asset":"assets/name_templates/name_template_06.png","reference_video_index":6,"variant_group":0,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_07','name_template','unisex','قالب اسم الفيديو 07','loop','video_reference','standalone','#FFFFFF','#FFFFFF',11000,110,false,true,7,'{"template_key":"name_template_07","asset":"assets/name_templates/name_template_07.png","reference_video_index":7,"variant_group":0,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_08','name_template','unisex','قالب اسم الفيديو 08','loop','video_reference','standalone','#FFFFFF','#FFFFFF',12000,120,false,true,8,'{"template_key":"name_template_08","asset":"assets/name_templates/name_template_08.png","reference_video_index":8,"variant_group":0,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_09','name_template','unisex','قالب اسم الفيديو 09','loop','video_reference','standalone','#FFFFFF','#FFFFFF',13000,130,false,true,9,'{"template_key":"name_template_09","asset":"assets/name_templates/name_template_09.png","reference_video_index":9,"variant_group":0,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_10','name_template','unisex','قالب اسم الفيديو 10','loop','video_reference','standalone','#FFFFFF','#FFFFFF',14000,140,false,true,10,'{"template_key":"name_template_10","asset":"assets/name_templates/name_template_10.png","reference_video_index":10,"variant_group":0,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_11','name_template','unisex','قالب اسم الفيديو 11','loop','video_reference','standalone','#FFFFFF','#FFFFFF',5000,50,false,true,11,'{"template_key":"name_template_11","asset":"assets/name_templates/name_template_11.png","reference_video_index":1,"variant_group":1,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_12','name_template','unisex','قالب اسم الفيديو 12','loop','video_reference','standalone','#FFFFFF','#FFFFFF',6000,60,false,true,12,'{"template_key":"name_template_12","asset":"assets/name_templates/name_template_12.png","reference_video_index":2,"variant_group":1,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_13','name_template','unisex','قالب اسم الفيديو 13','loop','video_reference','standalone','#FFFFFF','#FFFFFF',7000,70,false,true,13,'{"template_key":"name_template_13","asset":"assets/name_templates/name_template_13.png","reference_video_index":3,"variant_group":1,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_14','name_template','unisex','قالب اسم الفيديو 14','loop','video_reference','standalone','#FFFFFF','#FFFFFF',8000,80,false,true,14,'{"template_key":"name_template_14","asset":"assets/name_templates/name_template_14.png","reference_video_index":4,"variant_group":1,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_15','name_template','unisex','قالب اسم الفيديو 15','loop','video_reference','standalone','#FFFFFF','#FFFFFF',9000,90,false,true,15,'{"template_key":"name_template_15","asset":"assets/name_templates/name_template_15.png","reference_video_index":5,"variant_group":1,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_16','name_template','unisex','قالب اسم الفيديو 16','loop','video_reference','standalone','#FFFFFF','#FFFFFF',10000,100,false,true,16,'{"template_key":"name_template_16","asset":"assets/name_templates/name_template_16.png","reference_video_index":6,"variant_group":1,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_17','name_template','unisex','قالب اسم الفيديو 17','loop','video_reference','standalone','#FFFFFF','#FFFFFF',11000,110,false,true,17,'{"template_key":"name_template_17","asset":"assets/name_templates/name_template_17.png","reference_video_index":7,"variant_group":1,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_18','name_template','unisex','قالب اسم الفيديو 18','loop','video_reference','standalone','#FFFFFF','#FFFFFF',12000,120,false,true,18,'{"template_key":"name_template_18","asset":"assets/name_templates/name_template_18.png","reference_video_index":8,"variant_group":1,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_19','name_template','unisex','قالب اسم الفيديو 19','loop','video_reference','standalone','#FFFFFF','#FFFFFF',13000,130,false,true,19,'{"template_key":"name_template_19","asset":"assets/name_templates/name_template_19.png","reference_video_index":9,"variant_group":1,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_20','name_template','unisex','قالب اسم الفيديو 20','loop','video_reference','standalone','#FFFFFF','#FFFFFF',14000,140,false,true,20,'{"template_key":"name_template_20","asset":"assets/name_templates/name_template_20.png","reference_video_index":10,"variant_group":1,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_21','name_template','unisex','قالب اسم الفيديو 21','loop','video_reference','standalone','#FFFFFF','#FFFFFF',5000,50,false,true,21,'{"template_key":"name_template_21","asset":"assets/name_templates/name_template_21.png","reference_video_index":1,"variant_group":2,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_22','name_template','unisex','قالب اسم الفيديو 22','loop','video_reference','standalone','#FFFFFF','#FFFFFF',6000,60,false,true,22,'{"template_key":"name_template_22","asset":"assets/name_templates/name_template_22.png","reference_video_index":2,"variant_group":2,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_23','name_template','unisex','قالب اسم الفيديو 23','loop','video_reference','standalone','#FFFFFF','#FFFFFF',7000,70,false,true,23,'{"template_key":"name_template_23","asset":"assets/name_templates/name_template_23.png","reference_video_index":3,"variant_group":2,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_24','name_template','unisex','قالب اسم الفيديو 24','loop','video_reference','standalone','#FFFFFF','#FFFFFF',8000,80,false,true,24,'{"template_key":"name_template_24","asset":"assets/name_templates/name_template_24.png","reference_video_index":4,"variant_group":2,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_25','name_template','unisex','قالب اسم الفيديو 25','loop','video_reference','standalone','#FFFFFF','#FFFFFF',9000,90,false,true,25,'{"template_key":"name_template_25","asset":"assets/name_templates/name_template_25.png","reference_video_index":5,"variant_group":2,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_26','name_template','unisex','قالب اسم الفيديو 26','loop','video_reference','standalone','#FFFFFF','#FFFFFF',10000,100,false,true,26,'{"template_key":"name_template_26","asset":"assets/name_templates/name_template_26.png","reference_video_index":6,"variant_group":2,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_27','name_template','unisex','قالب اسم الفيديو 27','loop','video_reference','standalone','#FFFFFF','#FFFFFF',11000,110,false,true,27,'{"template_key":"name_template_27","asset":"assets/name_templates/name_template_27.png","reference_video_index":7,"variant_group":2,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_28','name_template','unisex','قالب اسم الفيديو 28','loop','video_reference','standalone','#FFFFFF','#FFFFFF',12000,120,false,true,28,'{"template_key":"name_template_28","asset":"assets/name_templates/name_template_28.png","reference_video_index":8,"variant_group":2,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_29','name_template','unisex','قالب اسم الفيديو 29','loop','video_reference','standalone','#FFFFFF','#FFFFFF',13000,130,false,true,29,'{"template_key":"name_template_29","asset":"assets/name_templates/name_template_29.png","reference_video_index":9,"variant_group":2,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_30','name_template','unisex','قالب اسم الفيديو 30','loop','video_reference','standalone','#FFFFFF','#FFFFFF',14000,140,false,true,30,'{"template_key":"name_template_30","asset":"assets/name_templates/name_template_30.png","reference_video_index":10,"variant_group":2,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_31','name_template','unisex','قالب اسم الفيديو 31','loop','video_reference','standalone','#FFFFFF','#FFFFFF',5000,50,false,true,31,'{"template_key":"name_template_31","asset":"assets/name_templates/name_template_31.png","reference_video_index":1,"variant_group":3,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_32','name_template','unisex','قالب اسم الفيديو 32','loop','video_reference','standalone','#FFFFFF','#FFFFFF',6000,60,false,true,32,'{"template_key":"name_template_32","asset":"assets/name_templates/name_template_32.png","reference_video_index":2,"variant_group":3,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_33','name_template','unisex','قالب اسم الفيديو 33','loop','video_reference','standalone','#FFFFFF','#FFFFFF',7000,70,false,true,33,'{"template_key":"name_template_33","asset":"assets/name_templates/name_template_33.png","reference_video_index":3,"variant_group":3,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_34','name_template','unisex','قالب اسم الفيديو 34','loop','video_reference','standalone','#FFFFFF','#FFFFFF',8000,80,false,true,34,'{"template_key":"name_template_34","asset":"assets/name_templates/name_template_34.png","reference_video_index":4,"variant_group":3,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_35','name_template','unisex','قالب اسم الفيديو 35','loop','video_reference','standalone','#FFFFFF','#FFFFFF',9000,90,false,true,35,'{"template_key":"name_template_35","asset":"assets/name_templates/name_template_35.png","reference_video_index":5,"variant_group":3,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_36','name_template','unisex','قالب اسم الفيديو 36','loop','video_reference','standalone','#FFFFFF','#FFFFFF',10000,100,false,true,36,'{"template_key":"name_template_36","asset":"assets/name_templates/name_template_36.png","reference_video_index":6,"variant_group":3,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_37','name_template','unisex','قالب اسم الفيديو 37','loop','video_reference','standalone','#FFFFFF','#FFFFFF',11000,110,false,true,37,'{"template_key":"name_template_37","asset":"assets/name_templates/name_template_37.png","reference_video_index":7,"variant_group":3,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_38','name_template','unisex','قالب اسم الفيديو 38','loop','video_reference','standalone','#FFFFFF','#FFFFFF',12000,120,false,true,38,'{"template_key":"name_template_38","asset":"assets/name_templates/name_template_38.png","reference_video_index":8,"variant_group":3,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_39','name_template','unisex','قالب اسم الفيديو 39','loop','video_reference','standalone','#FFFFFF','#FFFFFF',13000,130,false,true,39,'{"template_key":"name_template_39","asset":"assets/name_templates/name_template_39.png","reference_video_index":9,"variant_group":3,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_40','name_template','unisex','قالب اسم الفيديو 40','loop','video_reference','standalone','#FFFFFF','#FFFFFF',14000,140,false,true,40,'{"template_key":"name_template_40","asset":"assets/name_templates/name_template_40.png","reference_video_index":10,"variant_group":3,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_41','name_template','unisex','قالب اسم الفيديو 41','loop','video_reference','standalone','#FFFFFF','#FFFFFF',5000,50,false,true,41,'{"template_key":"name_template_41","asset":"assets/name_templates/name_template_41.png","reference_video_index":1,"variant_group":4,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_42','name_template','unisex','قالب اسم الفيديو 42','loop','video_reference','standalone','#FFFFFF','#FFFFFF',6000,60,false,true,42,'{"template_key":"name_template_42","asset":"assets/name_templates/name_template_42.png","reference_video_index":2,"variant_group":4,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_43','name_template','unisex','قالب اسم الفيديو 43','loop','video_reference','standalone','#FFFFFF','#FFFFFF',7000,70,false,true,43,'{"template_key":"name_template_43","asset":"assets/name_templates/name_template_43.png","reference_video_index":3,"variant_group":4,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_44','name_template','unisex','قالب اسم الفيديو 44','loop','video_reference','standalone','#FFFFFF','#FFFFFF',8000,80,false,true,44,'{"template_key":"name_template_44","asset":"assets/name_templates/name_template_44.png","reference_video_index":4,"variant_group":4,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_45','name_template','unisex','قالب اسم الفيديو 45','loop','video_reference','standalone','#FFFFFF','#FFFFFF',9000,90,false,true,45,'{"template_key":"name_template_45","asset":"assets/name_templates/name_template_45.png","reference_video_index":5,"variant_group":4,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_46','name_template','unisex','قالب اسم الفيديو 46','loop','video_reference','standalone','#FFFFFF','#FFFFFF',10000,100,false,true,46,'{"template_key":"name_template_46","asset":"assets/name_templates/name_template_46.png","reference_video_index":6,"variant_group":4,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_47','name_template','unisex','قالب اسم الفيديو 47','loop','video_reference','standalone','#FFFFFF','#FFFFFF',11000,110,false,true,47,'{"template_key":"name_template_47","asset":"assets/name_templates/name_template_47.png","reference_video_index":7,"variant_group":4,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_48','name_template','unisex','قالب اسم الفيديو 48','loop','video_reference','standalone','#FFFFFF','#FFFFFF',12000,120,false,true,48,'{"template_key":"name_template_48","asset":"assets/name_templates/name_template_48.png","reference_video_index":8,"variant_group":4,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_49','name_template','unisex','قالب اسم الفيديو 49','loop','video_reference','standalone','#FFFFFF','#FFFFFF',13000,130,false,true,49,'{"template_key":"name_template_49","asset":"assets/name_templates/name_template_49.png","reference_video_index":9,"variant_group":4,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb),
  ('name_template_50','name_template','unisex','قالب اسم الفيديو 50','loop','video_reference','standalone','#FFFFFF','#FFFFFF',14000,140,false,true,50,'{"template_key":"name_template_50","asset":"assets/name_templates/name_template_50.png","reference_video_index":10,"variant_group":4,"renderer":"name_template_host","standalone":true,"placement":"username","video_reference":true,"animation":true,"quality":"high","version":1}}'::jsonb)
on conflict (item_key) do update set
  category=excluded.category,
  gender=excluded.gender,
  name_ar=excluded.name_ar,
  animation_mode=excluded.animation_mode,
  palette_key=excluded.palette_key,
  mode_variant=excluded.mode_variant,
  color1=excluded.color1,
  color2=excluded.color2,
  price_points=excluded.price_points,
  price_gems=excluded.price_gems,
  owner_free=excluded.owner_free,
  is_active=true,
  sort_order=excluded.sort_order,
  metadata=excluded.metadata,
  updated_at=now();

create or replace function public.set_username_template(p_template_key text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_key text := nullif(lower(trim(coalesce(p_template_key,''))), '');
  v_item public.profile_cosmetic_catalog%rowtype;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;

  -- Clear only the standalone template. Existing username/visual effects remain untouched.
  if v_key is null or v_key = 'none' then
    update public.profiles set username_template_key=null, updated_at=now() where id=v_uid;
    return;
  end if;

  select * into v_item
  from public.profile_cosmetic_catalog c
  where c.item_key=v_key
    and c.category='name_template'
    and c.is_active=true
  limit 1;
  if not found then raise exception 'NAME_TEMPLATE_NOT_AVAILABLE'; end if;

  if not coalesce(public.is_platform_owner(v_uid),false)
     and not exists (
       select 1
       from public.profile_cosmetic_purchases p
       where p.user_id=v_uid and p.item_key=v_item.item_key
     ) then
    raise exception 'ITEM_NOT_OWNED';
  end if;

  update public.profiles
  set username_template_key=v_item.item_key, updated_at=now()
  where id=v_uid;
end;
$$;

-- Preserve canonical chat identity while adding a separate template field.
drop function if exists public.get_user_chat_identity(uuid,uuid);
create function public.get_user_chat_identity(p_user_id uuid,p_room_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_profile record; v_stats record; v_global_role_code text; v_global_role_name text; v_global_role_priority integer:=0; v_room_role_code text; v_room_role_name text; v_room_role_priority integer:=0; v_role_code text; v_role_name text; v_role_priority integer:=0; v_rank_id text; v_rank_level integer:=1; v_manual_rank integer:=0; v_xp bigint:=0; v_rank_name text; v_rank_badge_key text; v_badges jsonb:='[]'::jsonb;
begin
  select p.id,p.username,p.display_name,p.avatar_url,p.animated_avatar_url,p.chat_badge_url,p.username_color,p.username_shine,p.username_font_size,p.username_font_family,p.message_color,p.message_font_family,p.status_text,p.status_color,p.status_font_size,p.status_bold,p.status_italic,p.username_background_key,p.username_background_mode,p.username_background_color1,p.username_background_color2,p.username_background_opacity,p.username_background_external_effect,p.avatar_frame_key,p.avatar_visual_effect_key,p.username_template_key into v_profile from public.profiles p where p.id=p_user_id and p.is_active=true and p.is_suspended=false;
  if p_user_id is null or v_profile.id is null then return jsonb_build_object('user_id',p_user_id,'username','عضو','display_name','عضو','role',jsonb_build_object('code','visitor','name','زائر','priority',0,'scope','fallback','room_id',p_room_id),'rank',jsonb_build_object('id','rookie','level',1,'xp',0,'manual_rank',0,'name','مبتدئ','badge_key','rank_rookie'),'chat_badge',null,'chat_badge_url',null,'achievement_badges','[]'::jsonb,'status_text','','status_color',null,'status_font_size',12.5,'status_bold',false,'status_italic',false,'username_color',null,'username_shine',false,'username_font_size',22,'username_effect','none','username_template_key',null,'username_font_family','noto_kufi_arabic','message_color',4294967295,'message_font_family','cairo','username_background_key',null,'username_background_mode',null,'username_background_color1',null,'username_background_color2',null,'username_background_opacity',0.82,'username_background_external_effect',null,'avatar_url',null,'animated_avatar_url',null,'avatar_frame_key',null,'avatar_visual_effect_key',null); end if;
  select gs.xp,gs.rank_level,gs.rank_id,gs.manual_rank,gs.badges,gs.username_effect into v_stats from public.gamification_stats gs where gs.user_id=p_user_id;
  v_xp:=coalesce(v_stats.xp,0); v_rank_level:=greatest(coalesce(v_stats.rank_level,1),1); v_rank_id:=lower(coalesce(nullif(trim(v_stats.rank_id),''),'rookie')); v_manual_rank:=greatest(coalesce(v_stats.manual_rank,0),0); v_badges:=case when jsonb_typeof(coalesce(v_stats.badges,'[]'::jsonb))='array' then coalesce(v_stats.badges,'[]'::jsonb) else '[]'::jsonb end;
  if public._is_platform_owner(p_user_id) then v_role_code:='dragon'; v_role_name:='مالك المنصة'; v_role_priority:=1000; else
    if p_room_id is not null then select r.role_key,r.name,coalesce(r.priority,0) into v_room_role_code,v_room_role_name,v_room_role_priority from public.chat_room_members m join public.chat_room_roles r on r.id=m.role_id where m.room_id=p_room_id and m.user_id=p_user_id order by coalesce(r.priority,0) desc limit 1; end if;
    select r.code,r.name,coalesce(r.priority,0) into v_global_role_code,v_global_role_name,v_global_role_priority from public.user_roles ur join public.roles r on r.id=ur.role_id where ur.user_id=p_user_id order by coalesce(r.priority,0) desc limit 1;
    if v_room_role_code is not null then v_role_code:=v_room_role_code; v_role_name:=v_room_role_name; v_role_priority:=v_room_role_priority; elsif v_global_role_code is not null then v_role_code:=v_global_role_code; v_role_name:=v_global_role_name; v_role_priority:=v_global_role_priority; else v_role_code:='user'; v_role_name:='عضو'; v_role_priority:=0; end if;
  end if;
  if v_rank_id not in ('rookie','bronze','silver','gold','platinum','diamond','legend') then v_rank_id:='rookie'; end if;
  v_rank_name:=case v_rank_id when 'bronze' then 'برونزي' when 'silver' then 'فضي' when 'gold' then 'ذهبي' when 'platinum' then 'بلاتيني' when 'diamond' then 'ماسي' when 'legend' then 'أسطورة' else 'مبتدئ' end; v_rank_badge_key:='rank_'||v_rank_id;
  return jsonb_build_object('user_id',p_user_id,'username',v_profile.username,'display_name',v_profile.display_name,'role',jsonb_build_object('code',v_role_code,'name',v_role_name,'priority',v_role_priority,'scope',case when v_room_role_code is not null and v_role_code<>'dragon' then 'room' else 'global' end,'room_id',p_room_id),'rank',jsonb_build_object('id',v_rank_id,'level',v_rank_level,'xp',v_xp,'manual_rank',v_manual_rank,'name',v_rank_name,'badge_key',v_rank_badge_key),'chat_badge',case when v_profile.chat_badge_url is null or trim(v_profile.chat_badge_url)='' then null else jsonb_build_object('url',v_profile.chat_badge_url) end,'chat_badge_url',v_profile.chat_badge_url,'achievement_badges',v_badges,'status_text',coalesce(v_profile.status_text,''),'status_color',v_profile.status_color,'status_font_size',coalesce(v_profile.status_font_size,12.5),'status_bold',coalesce(v_profile.status_bold,false),'status_italic',coalesce(v_profile.status_italic,false),'username_color',v_profile.username_color,'username_shine',coalesce(v_profile.username_shine,false),'username_font_size',coalesce(v_profile.username_font_size,22),'username_effect',coalesce(nullif(trim(v_stats.username_effect),''),'none'),'username_template_key',v_profile.username_template_key,'username_font_family',coalesce(nullif(trim(v_profile.username_font_family),''),'noto_kufi_arabic'),'message_color',coalesce(v_profile.message_color,4294967295),'message_font_family',coalesce(nullif(trim(v_profile.message_font_family),''),'cairo'),'username_background_key',v_profile.username_background_key,'username_background_mode',v_profile.username_background_mode,'username_background_color1',v_profile.username_background_color1,'username_background_color2',v_profile.username_background_color2,'username_background_opacity',coalesce(v_profile.username_background_opacity,.82),'username_background_external_effect',v_profile.username_background_external_effect,'avatar_url',v_profile.avatar_url,'animated_avatar_url',v_profile.animated_avatar_url,'avatar_frame_key',v_profile.avatar_frame_key,'avatar_visual_effect_key',v_profile.avatar_visual_effect_key);
end;
$$;

-- Preserve the public profile RPC contract and append the new field.
drop function if exists public.get_public_profile_cosmetics(uuid);
create function public.get_public_profile_cosmetics(p_user_id uuid)
returns table(
 id uuid,username text,display_name text,email text,bio text,avatar_url text,cover_url text,status_text text,
 profile_music_url text,profile_music_duration_ms integer,profile_music_size_bytes bigint,country text,city text,profession text,
 experiences jsonb,social_links jsonb,verified boolean,visibility text,account_type text,username_color bigint,username_shine boolean,
 username_font_size double precision,status_font_size double precision,status_bold boolean,status_italic boolean,status_color bigint,
 animated_avatar_url text,chat_badge_url text,avatar_frame_key text,username_effect text,username_background_key text,
 username_background_mode text,username_background_color1 text,username_background_color2 text,username_background_opacity double precision,
 username_background_external_effect text,role_code text,created_at timestamptz,updated_at timestamptz,avatar_visual_effect_key text,username_template_key text)
language sql stable security definer set search_path = ''
as $$
  select p.id,p.username,p.display_name,case when auth.uid()=p.id then coalesce(p.email,'') else '' end,p.bio,p.avatar_url,p.cover_url,p.status_text,
    p.profile_music_url,p.profile_music_duration_ms,p.profile_music_size_bytes,p.country,p.city,p.profession,coalesce(p.experiences,'[]'::jsonb),coalesce(p.social_links,'[]'::jsonb),
    coalesce(p.verified,false),coalesce(p.visibility,'public'),coalesce(p.account_type,'individual'),p.username_color,coalesce(p.username_shine,false),p.username_font_size,p.status_font_size,
    coalesce(p.status_bold,false),coalesce(p.status_italic,false),p.status_color,p.animated_avatar_url,p.chat_badge_url,p.avatar_frame_key,coalesce(gs.username_effect,'none'),
    p.username_background_key,p.username_background_mode,p.username_background_color1,p.username_background_color2,coalesce(p.username_background_opacity,.82),p.username_background_external_effect,
    coalesce((select r.code from public.user_roles ur join public.roles r on r.id=ur.role_id where ur.user_id=p.id order by r.priority desc,r.code asc limit 1),'user'),p.created_at,p.updated_at,p.avatar_visual_effect_key,p.username_template_key
  from public.profiles p left join public.gamification_stats gs on gs.user_id=p.id
  where p.id=p_user_id and p.is_active=true and p.is_suspended=false
    and (p.id=auth.uid() or private.has_permission('users.read') or public.is_platform_owner(auth.uid())
      or (coalesce(p.visibility,'public')='public' and not public.has_profile_service_for_user(p.id,'hide_profile')));
$$;

revoke all on function public.set_username_template(text) from public,anon;
grant execute on function public.set_username_template(text) to authenticated;
grant execute on function public.get_profile_cosmetic_catalog(text,text) to authenticated;
grant execute on function public.get_public_profile_cosmetics(uuid) to anon,authenticated;
grant execute on function public.get_user_chat_identity(uuid,uuid) to authenticated;

commit;
