-- تسعير موحّد خادمي بثلاث فئات لكل قسم (عادي/مميز/نادر).
-- المرساة: 500 نقطة = 0.99$ و 5 جواهر = 0.99$ ⇒ الجوهرة ≈ 100 نقطة.
-- أسعار منخفضة لمرحلة جذب المستخدمين. المالك يعدّل سعر أي فئة من لوحة
-- الأسعار داخل متجر الشات فيُطبَّق فورًا على كل عناصرها، أو ينقل عنصرًا
-- بعينه إلى فئة أخرى.

create table if not exists public.store_price_tiers (
  section text not null,
  tier text not null check (tier in ('normal','premium','rare')),
  price_points bigint not null check (price_points >= 0),
  price_gems bigint not null check (price_gems >= 0),
  updated_at timestamptz not null default now(),
  primary key (section, tier)
);
alter table public.store_price_tiers enable row level security;
create policy store_price_tiers_read on public.store_price_tiers for select using (true);

insert into public.store_price_tiers (section, tier, price_points, price_gems) values
 ('frame','normal',400,4),('frame','premium',900,9),('frame','rare',1800,18),
 ('simple_frame','normal',150,2),('simple_frame','premium',300,3),('simple_frame','rare',600,6),
 ('background','normal',200,2),('background','premium',400,4),('background','rare',800,8),
 ('message_color','normal',100,1),('message_color','premium',250,3),('message_color','rare',500,5),
 ('role_color','normal',100,1),('role_color','premium',250,3),('role_color','rare',500,5),
 ('name_effect','normal',300,3),('name_effect','premium',600,6),('name_effect','rare',1200,12),
 ('name_template','normal',500,5),('name_template','premium',1000,10),('name_template','rare',2000,20),
 ('name_animation','normal',500,5),('name_animation','premium',1000,10),('name_animation','rare',2000,20),
 ('profile_service','normal',1000,10),('profile_service','premium',2500,25),('profile_service','rare',5000,50)
on conflict (section, tier) do update
  set price_points = excluded.price_points, price_gems = excluded.price_gems, updated_at = now();

alter table public.profile_cosmetic_catalog add column if not exists price_tier text
  check (price_tier is null or price_tier in ('normal','premium','rare'));
alter table public.name_animation_catalog add column if not exists price_tier text
  check (price_tier is null or price_tier in ('normal','premium','rare'));
alter table public.profile_service_catalog add column if not exists price_tier text
  check (price_tier is null or price_tier in ('normal','premium','rare'));
alter table public.store_items add column if not exists price_tier text
  check (price_tier is null or price_tier in ('normal','premium','rare'));

-- ===== التصنيف الأولي =====
-- الإطارات: المقيّدة بالرتبة (تأثير نبض) نادرة؛ عائلات ملكي/عنقاء/كوني/برق مميزة؛ الباقي عادي.
update public.profile_cosmetic_catalog set price_tier = case
    when coalesce(animation_mode, metadata->>'animation_mode') = 'static_effect' then 'rare'
    when coalesce(animation_mode, metadata->>'animation_mode') in ('royal','phoenix','cosmic','lightning') then 'premium'
    else 'normal' end
 where category = 'frame';
-- خلفية إطار الاسم: لون واحد/فارغ عادي، لونان مميز، بتأثير خارجي نادر.
update public.profile_cosmetic_catalog set price_tier = case
    when coalesce(metadata->>'outer_effect','none') <> 'none' then 'rare'
    when metadata->>'variant' = 'dual' then 'premium'
    else 'normal' end
 where category = 'background';
-- ألوان الرسائل والرتبة: المتدرج نادر؛ المميز/النيون/الممزوج مميز؛ الباقي عادي.
update public.profile_cosmetic_catalog set price_tier = case
    when (metadata->>'gradient')::boolean is true then 'rare'
    when metadata->>'tier' = 'premium' or (metadata->>'neon')::boolean is true
         or metadata->>'source' = 'owner_managed_blended_message_palette'
         or (metadata->>'tier' is null and price_points >= 1500) then 'premium'
    else 'normal' end
 where category in ('message_color','role_color');
-- تأثيرات الاسم: أثلاث حسب ترتيبها في الكتالوج (الأوائل أبسط، الأواخر أعقد حركةً).
update public.profile_cosmetic_catalog set price_tier = case
    when sort_order <= 33 then 'normal' when sort_order <= 66 then 'premium' else 'rare' end
 where category = 'name_effect';
-- قوالب الاسم: حسب ترتيب سعرها السابق (الأرخص عادي، الأغلى نادر).
update public.profile_cosmetic_catalog set price_tier = case
    when price_points <= 7000 then 'normal' when price_points <= 10000 then 'premium' else 'rare' end
 where category = 'name_template';
-- حيوانات فوق الاسم.
update public.name_animation_catalog set price_tier = case
    when name_ar like '%التنين%' then 'rare'
    when name_ar like '%الأس%د%' or name_ar like '%النسر%' then 'premium'
    else 'normal' end;
-- خدمات VIP: حسب سعرها السابق النسبي.
update public.profile_service_catalog set price_tier = case
    when price_points <= 60000 then 'normal' when price_points <= 110000 then 'premium' else 'rare' end;
-- الإطارات الملوّنة البسيطة (لون واحد) كلها عادية.
update public.store_items set price_tier = 'normal' where item_type = 'simple_frame';

-- ===== التطبيق =====
create or replace function private.apply_store_price_tier(p_section text, p_tier text)
returns integer language plpgsql security definer set search_path to '' as $function$
declare v_p bigint; v_g bigint; v_n integer := 0;
begin
  select price_points, price_gems into v_p, v_g from public.store_price_tiers
   where section = p_section and tier = p_tier;
  if not found then raise exception 'TIER_NOT_FOUND'; end if;
  if p_section in ('frame','background','message_color','role_color','name_effect','name_template') then
    update public.profile_cosmetic_catalog set price_points = v_p, price_gems = v_g, updated_at = now()
     where category = p_section and price_tier = p_tier;
    get diagnostics v_n = row_count;
  elsif p_section = 'name_animation' then
    update public.name_animation_catalog set price_points = v_p, price_gems = v_g, updated_at = now()
     where price_tier = p_tier;
    get diagnostics v_n = row_count;
  elsif p_section = 'profile_service' then
    update public.profile_service_catalog set price_points = v_p, price_gems = v_g, updated_at = now()
     where price_tier = p_tier;
    get diagnostics v_n = row_count;
  elsif p_section = 'simple_frame' then
    update public.store_item_prices sp set amount = v_p
      from public.store_items si
     where sp.item_id = si.id and si.item_type = 'simple_frame' and si.price_tier = p_tier
       and sp.currency = 'points' and sp.is_active;
    get diagnostics v_n = row_count;
  else
    raise exception 'INVALID_SECTION';
  end if;
  return v_n;
end; $function$;
revoke all on function private.apply_store_price_tier(text, text) from public, anon, authenticated;

do $$
declare r record;
begin
  for r in select section, tier from public.store_price_tiers loop
    perform private.apply_store_price_tier(r.section, r.tier);
  end loop;
end $$;

-- ===== العضويات الشهرية (8 مستويات) =====
-- منحة الشراء كانت تساوي السعر أو تزيد عليه (البرونزية: سعر 100000 نقطة
-- وتمنح 100000 نقطة + 100 جوهرة) — ثغرة. المنحة الآن 25% من السعر بالنقاط فقط.
update public.app_documents d set data = d.data || jsonb_build_object(
    'pricePoints', v.pp, 'priceGems', v.pp / 100,
    'pointsGranted', v.pp / 4, 'gemsGranted', 0), updated_at = now()
  from (values ('bronze',1500),('silver',2500),('gold',4000),('diamond',6000),
               ('royal',8000),('vip',10000),('legendary',13000),('ultimate',16000)) as v(id, pp)
 where d.collection_path = 'subscription_tiers' and d.doc_id = v.id;

-- ===== RPC للمالك =====
create or replace function private_rpc.admin_get_store_pricing()
returns jsonb language plpgsql security definer set search_path to '' as $function$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public._is_platform_owner(auth.uid()) then raise exception 'FORBIDDEN'; end if;
  return jsonb_build_object(
    'tiers', coalesce((select jsonb_agg(jsonb_build_object(
        'section', t.section, 'tier', t.tier, 'price_points', t.price_points, 'price_gems', t.price_gems,
        'items', case
          when t.section in ('frame','background','message_color','role_color','name_effect','name_template')
            then (select count(*) from public.profile_cosmetic_catalog c where c.category = t.section and c.price_tier = t.tier and c.is_active)
          when t.section = 'name_animation' then (select count(*) from public.name_animation_catalog c where c.price_tier = t.tier and c.is_active)
          when t.section = 'profile_service' then (select count(*) from public.profile_service_catalog c where c.price_tier = t.tier and c.is_active)
          when t.section = 'simple_frame' then (select count(*) from public.store_items c where c.item_type = 'simple_frame' and c.price_tier = t.tier and c.is_active)
        end) order by t.section, case t.tier when 'normal' then 1 when 'premium' then 2 else 3 end)
      from public.store_price_tiers t), '[]'::jsonb),
    'memberships', coalesce((select jsonb_agg(jsonb_build_object(
        'id', d.doc_id, 'name', coalesce(d.data->>'name', d.doc_id),
        'level', (d.data->>'level')::int,
        'price_points', coalesce((d.data->>'pricePoints')::bigint, 0),
        'price_gems', coalesce((d.data->>'priceGems')::bigint, 0),
        'points_granted', coalesce((d.data->>'pointsGranted')::bigint, 0))
        order by (d.data->>'level')::int)
      from public.app_documents d where d.collection_path = 'subscription_tiers'), '[]'::jsonb));
end; $function$;

create or replace function private_rpc.admin_set_store_price_tier(p_section text, p_tier text, p_price_points bigint, p_price_gems bigint)
returns integer language plpgsql security definer set search_path to '' as $function$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public._is_platform_owner(auth.uid()) then raise exception 'FORBIDDEN'; end if;
  if coalesce(p_price_points, -1) < 0 or coalesce(p_price_gems, -1) < 0 then raise exception 'INVALID_PRICE'; end if;
  update public.store_price_tiers set price_points = p_price_points, price_gems = p_price_gems, updated_at = now()
   where section = p_section and tier = p_tier;
  if not found then raise exception 'TIER_NOT_FOUND'; end if;
  return private.apply_store_price_tier(p_section, p_tier);
end; $function$;

create or replace function private_rpc.admin_set_item_price_tier(p_section text, p_item_key text, p_tier text)
returns void language plpgsql security definer set search_path to '' as $function$
declare v_p bigint; v_g bigint;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public._is_platform_owner(auth.uid()) then raise exception 'FORBIDDEN'; end if;
  select price_points, price_gems into v_p, v_g from public.store_price_tiers where section = p_section and tier = p_tier;
  if not found then raise exception 'TIER_NOT_FOUND'; end if;
  if p_section in ('frame','background','message_color','role_color','name_effect','name_template') then
    update public.profile_cosmetic_catalog set price_tier = p_tier, price_points = v_p, price_gems = v_g, updated_at = now()
     where category = p_section and item_key = p_item_key;
  elsif p_section = 'name_animation' then
    update public.name_animation_catalog set price_tier = p_tier, price_points = v_p, price_gems = v_g, updated_at = now()
     where effect_key = p_item_key;
  elsif p_section = 'profile_service' then
    update public.profile_service_catalog set price_tier = p_tier, price_points = v_p, price_gems = v_g, updated_at = now()
     where feature_key = p_item_key;
  elsif p_section = 'simple_frame' then
    update public.store_items set price_tier = p_tier, updated_at = now() where code = p_item_key and item_type = 'simple_frame';
    if found then
      update public.store_item_prices sp set amount = v_p from public.store_items si
       where sp.item_id = si.id and si.code = p_item_key and sp.currency = 'points' and sp.is_active;
    end if;
  else
    raise exception 'INVALID_SECTION';
  end if;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;
end; $function$;

create or replace function public.admin_get_store_pricing()
returns jsonb language sql set search_path to 'public','private_rpc' as $$ select private_rpc.admin_get_store_pricing(); $$;
create or replace function public.admin_set_store_price_tier(p_section text, p_tier text, p_price_points bigint, p_price_gems bigint)
returns integer language sql set search_path to 'public','private_rpc' as $$ select private_rpc.admin_set_store_price_tier($1,$2,$3,$4); $$;
create or replace function public.admin_set_item_price_tier(p_section text, p_item_key text, p_tier text)
returns void language sql set search_path to 'public','private_rpc' as $$ select private_rpc.admin_set_item_price_tier($1,$2,$3); $$;
revoke all on function public.admin_get_store_pricing() from anon;
revoke all on function public.admin_set_store_price_tier(text,text,bigint,bigint) from anon;
revoke all on function public.admin_set_item_price_tier(text,text,text) from anon;
grant execute on function public.admin_get_store_pricing() to authenticated;
grant execute on function public.admin_set_store_price_tier(text,text,bigint,bigint) to authenticated;
grant execute on function public.admin_set_item_price_tier(text,text,text) to authenticated;
