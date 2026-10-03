-- Requested 2026-09-03 fixes:
-- 1) Fix pattern purchase/storage 403 by granting authenticated SELECT and
--    keeping RLS restricted to the caller's own purchase rows.
-- 2) Seed 30 owner-managed normal colored avatar frames in the existing
--    store_items catalog so the current purchase/equip pipeline is reused.
-- 3) Keep chat badge storage compatible with static and animated images.

begin;

grant select on public.profile_pattern_purchases to authenticated;

drop policy if exists profile_pattern_purchase_owner_select on public.profile_pattern_purchases;
create policy profile_pattern_purchase_owner_select
on public.profile_pattern_purchases
for select
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists chat_badges_public_read on storage.objects;
create policy chat_badges_public_read
on storage.objects
for select
to public
using (bucket_id = 'chat-badges');

drop policy if exists chat_badges_owner_insert on storage.objects;
create policy chat_badges_owner_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'chat-badges'
  and split_part(name,'/',1) = 'catalog'
  and lower(storage.extension(name)) in ('gif','png','jpg','jpeg','webp')
  and private.is_platform_owner_storage()
);

update storage.buckets
set file_size_limit = 8388608,
    allowed_mime_types = array['image/gif','image/png','image/jpeg','image/webp']::text[]
where id = 'chat-badges';

drop policy if exists chat_badges_owner_delete on storage.objects;
create policy chat_badges_owner_delete
on storage.objects
for delete
to authenticated
using (bucket_id = 'chat-badges' and private.is_platform_owner_storage());

drop policy if exists chat_badges_owner_update on storage.objects;
create policy chat_badges_owner_update
on storage.objects
for update
to authenticated
using (bucket_id = 'chat-badges' and private.is_platform_owner_storage())
with check (
  bucket_id = 'chat-badges'
  and private.is_platform_owner_storage()
  and lower(storage.extension(name)) in ('gif','png','jpg','jpeg','webp')
);

do $$
declare v_section bigint;
begin
  select id into v_section from public.store_sections where lower(code) = 'frames' limit 1;

  insert into public.store_items
    (section_id, code, name, description, item_type, asset_url, metadata,
     is_active, is_limited, stock_quantity, sort_order, owner_id)
  values
    ((v_section), 'simple-frame-01', 'إطار أحمر', 'إطار دائري ملون أحمر', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-01',
        'colors',jsonb_build_array(4294198070),
        'asset_type','simple_frame',
        'simple_frame_color','#F44336',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10001, NULL),
    ((v_section), 'simple-frame-02', 'إطار وردي', 'إطار دائري ملون وردي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-02',
        'colors',jsonb_build_array(4293467747),
        'asset_type','simple_frame',
        'simple_frame_color','#E91E63',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10002, NULL),
    ((v_section), 'simple-frame-03', 'إطار بنفسجي', 'إطار دائري ملون بنفسجي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-03',
        'colors',jsonb_build_array(4288423856),
        'asset_type','simple_frame',
        'simple_frame_color','#9C27B0',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10003, NULL),
    ((v_section), 'simple-frame-04', 'إطار أرجواني', 'إطار دائري ملون أرجواني', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-04',
        'colors',jsonb_build_array(4284955319),
        'asset_type','simple_frame',
        'simple_frame_color','#673AB7',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10004, NULL),
    ((v_section), 'simple-frame-05', 'إطار أزرق ملكي', 'إطار دائري ملون أزرق ملكي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-05',
        'colors',jsonb_build_array(4282339765),
        'asset_type','simple_frame',
        'simple_frame_color','#3F51B5',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10005, NULL),
    ((v_section), 'simple-frame-06', 'إطار أزرق', 'إطار دائري ملون أزرق', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-06',
        'colors',jsonb_build_array(4280391411),
        'asset_type','simple_frame',
        'simple_frame_color','#2196F3',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10006, NULL),
    ((v_section), 'simple-frame-07', 'إطار سماوي', 'إطار دائري ملون سماوي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-07',
        'colors',jsonb_build_array(4278430196),
        'asset_type','simple_frame',
        'simple_frame_color','#03A9F4',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10007, NULL),
    ((v_section), 'simple-frame-08', 'إطار فيروزي', 'إطار دائري ملون فيروزي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-08',
        'colors',jsonb_build_array(4278238420),
        'asset_type','simple_frame',
        'simple_frame_color','#00BCD4',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10008, NULL),
    ((v_section), 'simple-frame-09', 'إطار أخضر', 'إطار دائري ملون أخضر', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-09',
        'colors',jsonb_build_array(4283215696),
        'asset_type','simple_frame',
        'simple_frame_color','#009688',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10009, NULL),
    ((v_section), 'simple-frame-10', 'إطار أخضر زمردي', 'إطار دائري ملون أخضر زمردي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-10',
        'colors',jsonb_build_array(4278228616),
        'asset_type','simple_frame',
        'simple_frame_color','#4CAF50',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10010, NULL),
    ((v_section), 'simple-frame-11', 'إطار أخضر ليموني', 'إطار دائري ملون أخضر ليموني', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-11',
        'colors',jsonb_build_array(4287349578),
        'asset_type','simple_frame',
        'simple_frame_color','#8BC34A',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10011, NULL),
    ((v_section), 'simple-frame-12', 'إطار ليموني', 'إطار دائري ملون ليموني', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-12',
        'colors',jsonb_build_array(4291681337),
        'asset_type','simple_frame',
        'simple_frame_color','#CDDC39',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10012, NULL),
    ((v_section), 'simple-frame-13', 'إطار أصفر', 'إطار دائري ملون أصفر', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-13',
        'colors',jsonb_build_array(4294961979),
        'asset_type','simple_frame',
        'simple_frame_color','#FFEB3B',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10013, NULL),
    ((v_section), 'simple-frame-14', 'إطار ذهبي', 'إطار دائري ملون ذهبي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-14',
        'colors',jsonb_build_array(4294951175),
        'asset_type','simple_frame',
        'simple_frame_color','#FFC107',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10014, NULL),
    ((v_section), 'simple-frame-15', 'إطار كهرماني', 'إطار دائري ملون كهرماني', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-15',
        'colors',jsonb_build_array(4294940672),
        'asset_type','simple_frame',
        'simple_frame_color','#FF9800',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10015, NULL),
    ((v_section), 'simple-frame-16', 'إطار برتقالي', 'إطار دائري ملون برتقالي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-16',
        'colors',jsonb_build_array(4294924066),
        'asset_type','simple_frame',
        'simple_frame_color','#FF5722',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10016, NULL),
    ((v_section), 'simple-frame-17', 'إطار بني', 'إطار دائري ملون بني', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-17',
        'colors',jsonb_build_array(4286141768),
        'asset_type','simple_frame',
        'simple_frame_color','#795548',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10017, NULL),
    ((v_section), 'simple-frame-18', 'إطار رمادي', 'إطار دائري ملون رمادي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-18',
        'colors',jsonb_build_array(4284513675),
        'asset_type','simple_frame',
        'simple_frame_color','#607D8B',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10018, NULL),
    ((v_section), 'simple-frame-19', 'إطار فضي', 'إطار دائري ملون فضي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-19',
        'colors',jsonb_build_array(4289773253),
        'asset_type','simple_frame',
        'simple_frame_color','#EF5350',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10019, NULL),
    ((v_section), 'simple-frame-20', 'إطار أبيض لؤلؤي', 'إطار دائري ملون أبيض لؤلؤي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-20',
        'colors',jsonb_build_array(4294309365),
        'asset_type','simple_frame',
        'simple_frame_color','#EC407A',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10020, NULL),
    ((v_section), 'simple-frame-21', 'إطار أسود', 'إطار دائري ملون أسود', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-21',
        'colors',jsonb_build_array(4279308561),
        'asset_type','simple_frame',
        'simple_frame_color','#AB47BC',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10021, NULL),
    ((v_section), 'simple-frame-22', 'إطار قرمزي', 'إطار دائري ملون قرمزي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-22',
        'colors',jsonb_build_array(4290190364),
        'asset_type','simple_frame',
        'simple_frame_color','#7E57C2',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10022, NULL),
    ((v_section), 'simple-frame-23', 'إطار مرجاني', 'إطار دائري ملون مرجاني', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-23',
        'colors',jsonb_build_array(4294930499),
        'asset_type','simple_frame',
        'simple_frame_color','#5C6BC0',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10023, NULL),
    ((v_section), 'simple-frame-24', 'إطار سلموني', 'إطار دائري ملون سلموني', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-24',
        'colors',jsonb_build_array(4294937189),
        'asset_type','simple_frame',
        'simple_frame_color','#42A5F5',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10024, NULL),
    ((v_section), 'simple-frame-25', 'إطار لافندر', 'إطار دائري ملون لافندر', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-25',
        'colors',jsonb_build_array(4289961435),
        'asset_type','simple_frame',
        'simple_frame_color','#26C6DA',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10025, NULL),
    ((v_section), 'simple-frame-26', 'إطار نيلي', 'إطار دائري ملون نيلي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-26',
        'colors',jsonb_build_array(4284246976),
        'asset_type','simple_frame',
        'simple_frame_color','#26A69A',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10026, NULL),
    ((v_section), 'simple-frame-27', 'إطار أزرق جليدي', 'إطار دائري ملون أزرق جليدي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-27',
        'colors',jsonb_build_array(4287679225),
        'asset_type','simple_frame',
        'simple_frame_color','#66BB6A',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10027, NULL),
    ((v_section), 'simple-frame-28', 'إطار نعناعي', 'إطار دائري ملون نعناعي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-28',
        'colors',jsonb_build_array(4286630852),
        'asset_type','simple_frame',
        'simple_frame_color','#9CCC65',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10028, NULL),
    ((v_section), 'simple-frame-29', 'إطار أخضر غابي', 'إطار دائري ملون أخضر غابي', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-29',
        'colors',jsonb_build_array(4281896508),
        'asset_type','simple_frame',
        'simple_frame_color','#FFCA28',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10029, NULL),
    ((v_section), 'simple-frame-30', 'إطار أزرق بحري', 'إطار دائري ملون أزرق بحري', 'simple_frame', NULL,
      jsonb_build_object(
        'category','avatarFrame',
        'domain','profileFrames',
        'sku','simple-frame-30',
        'colors',jsonb_build_array(4279592384),
        'asset_type','simple_frame',
        'simple_frame_color','#FFA726',
        'owner_managed',true,
        'normal_colored_frame',true
      ),
      true, false, NULL, 10030, NULL)
  on conflict (code) do update set
    name = excluded.name,
    description = excluded.description,
    item_type = excluded.item_type,
    metadata = excluded.metadata,
    is_active = true,
    sort_order = excluded.sort_order,
    updated_at = now();

  insert into public.store_item_prices
    (item_id, currency, amount, is_active, effective_from, created_by)
  select si.id, 'points', 500, true, now(), null
  from public.store_items si
  where si.code like 'simple-frame-%'
    and not exists (
      select 1 from public.store_item_prices sip
      where sip.item_id = si.id and sip.currency = 'points' and sip.is_active = true
    );
  -- Expand the existing message-color catalog to 30 distinct colors.
  insert into public.profile_cosmetic_catalog
    (item_key, category, gender, name_ar, animation_mode, palette_key, mode_variant,
     color1, color2, price_points, price_gems, owner_free, is_active, sort_order, metadata)
  select v.item_key, 'message_color', 'unisex', v.name_ar, 'solid', v.item_key, 'solid',
         v.color1, null, 0, 0, true, true, 70000 + v.ord,
         jsonb_build_object('tier','free','source','requested_full_color_palette')
  from (values
    (1,'msg_full_red','أحمر','#EF4444'),
    (2,'msg_full_orange','برتقالي','#F97316'),
    (3,'msg_full_amber','كهرماني','#F59E0B'),
    (4,'msg_full_yellow','أصفر','#EAB308'),
    (5,'msg_full_lime','ليموني','#84CC16'),
    (6,'msg_full_green','أخضر','#22C55E'),
    (7,'msg_full_teal','أخضر مزرق','#14B8A6'),
    (8,'msg_full_cyan','سماوي','#06B6D4'),
    (9,'msg_full_blue','أزرق','#3B82F6'),
    (10,'msg_full_indigo','نيلي','#6366F1'),
    (11,'msg_full_violet','بنفسجي','#8B5CF6'),
    (12,'msg_full_pink','وردي','#EC4899'),
    (13,'msg_full_fuchsia','فوشيا','#D946EF'),
    (14,'msg_full_slate','رصاصي','#64748B')
  ) as v(ord,item_key,name_ar,color1)
  where not exists (
    select 1 from public.profile_cosmetic_catalog c where c.item_key = v.item_key
  );

end $$;

commit;
