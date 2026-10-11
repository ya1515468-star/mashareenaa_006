-- تطبيق التسعير المقترح (3 فئات) بضغطة من المالك داخل لوحة الأسعار في متجر
-- الشات، مع رسالة تأكيد. أداة الترحيل الآلية رفضت تنفيذ تغيير الأسعار
-- الجماعي دون تأكيد بشري، فصار التنفيذ قرارًا صريحًا من المالك نفسه.
create or replace function private_rpc.admin_apply_default_store_pricing()
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare r record; v_total integer := 0;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public._is_platform_owner(auth.uid()) then raise exception 'FORBIDDEN'; end if;

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

  update public.profile_cosmetic_catalog set price_tier = case
      when coalesce(animation_mode, metadata->>'animation_mode') = 'static_effect' then 'rare'
      when coalesce(animation_mode, metadata->>'animation_mode') in ('royal','phoenix','cosmic','lightning') then 'premium'
      else 'normal' end
   where category = 'frame' and price_tier is null;
  update public.profile_cosmetic_catalog set price_tier = case
      when coalesce(metadata->>'outer_effect','none') <> 'none' then 'rare'
      when metadata->>'variant' = 'dual' then 'premium'
      else 'normal' end
   where category = 'background' and price_tier is null;
  update public.profile_cosmetic_catalog set price_tier = case
      when (metadata->>'gradient')::boolean is true then 'rare'
      when metadata->>'tier' = 'premium' or (metadata->>'neon')::boolean is true
           or metadata->>'source' = 'owner_managed_blended_message_palette'
           or (metadata->>'tier' is null and price_points >= 1500) then 'premium'
      else 'normal' end
   where category in ('message_color','role_color') and price_tier is null;
  update public.profile_cosmetic_catalog set price_tier = case
      when sort_order <= 33 then 'normal' when sort_order <= 66 then 'premium' else 'rare' end
   where category = 'name_effect' and price_tier is null;
  update public.profile_cosmetic_catalog set price_tier = case
      when price_points <= 7000 then 'normal' when price_points <= 10000 then 'premium' else 'rare' end
   where category = 'name_template' and price_tier is null;
  update public.name_animation_catalog set price_tier = case
      when name_ar like '%التنين%' then 'rare'
      when name_ar like '%الأس%د%' or name_ar like '%النسر%' then 'premium'
      else 'normal' end
   where price_tier is null;
  update public.profile_service_catalog set price_tier = case
      when price_points <= 60000 then 'normal' when price_points <= 110000 then 'premium' else 'rare' end
   where price_tier is null;
  update public.store_items set price_tier = 'normal'
   where item_type = 'simple_frame' and price_tier is null;

  for r in select section, tier from public.store_price_tiers loop
    v_total := v_total + private.apply_store_price_tier(r.section, r.tier);
  end loop;

  -- العضويات الشهرية: سلّم 8 مستويات، ومنحة الشراء 25% من السعر بالنقاط فقط
  -- (كانت المنحة تساوي السعر أو تزيد — ثغرة تجعل الشراء مربحًا).
  update public.app_documents d set data = d.data || jsonb_build_object(
      'pricePoints', v.pp, 'priceGems', v.pp / 100,
      'pointsGranted', v.pp / 4, 'gemsGranted', 0), updated_at = now()
    from (values ('bronze',1500),('silver',2500),('gold',4000),('diamond',6000),
                 ('royal',8000),('vip',10000),('legendary',13000),('ultimate',16000)) as v(id, pp)
   where d.collection_path = 'subscription_tiers' and d.doc_id = v.id;

  return jsonb_build_object('ok', true, 'items_priced', v_total);
end; $function$;

create or replace function public.admin_apply_default_store_pricing()
returns jsonb language sql set search_path to 'public','private_rpc' as $$ select private_rpc.admin_apply_default_store_pricing(); $$;
revoke all on function public.admin_apply_default_store_pricing() from anon;
grant execute on function public.admin_apply_default_store_pricing() to authenticated;
