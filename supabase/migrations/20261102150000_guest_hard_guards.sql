-- ============================================================
-- حساب الزائر — سدّ الثغرات على مستوى الجداول
--
-- المشكلة: مفاتيح guest_gifts و guest_purchases و guest_cosmetics
-- كانت في الجدول بلا حارس، فالزائر يستطيع الإهداء والشراء رغم أن
-- المفتاح يقول مغلق. وهذه ثغرة حقيقية لا تجميلية: حساب الزائر
-- مجّاني وفوري وغير محدود العدد.
--
-- لماذا تريجر لا تعديل الدوال: منافذ الشراء والإهداء أكثر من خمسين
-- دالة موزّعة على مخطّطَين (`private` و`private_rpc`)، وكلها
-- SECURITY DEFINER أي **تتجاوز RLS**. تعديلها واحدة واحدة يعني نسخ
-- خمسين جسمًا حرفيًا — خطر كبير ومسار قد يفوتني. التريجر يعمل عند
-- الكتابة نفسها مهما كان المسار، بما فيه ما لم أجده.
--
-- ولماذا لا يكسر شيئًا: الحارس يفحص **المنادي** لا صفّ الجدول. فعضو
-- يُهدي زائرًا يمرّ (المنادي عضو)، ومالك يمنح عنصرًا يمرّ، والعمليات
-- الخادمية بلا جلسة تمرّ (auth.uid() = null ⇒ ليس زائرًا). الزائر
-- وحده يُمنع، وفقط إن كان مفتاحه مغلقًا.
--
-- وتحققت أن `handle_new_user` لا تكتب في أيٍّ من هذه الجداول، فإنشاء
-- حساب الزائر نفسه لا يصطدم بالحارس.
-- ============================================================

-- ── 1) الحارس العام ──
create or replace function public.guard_guest_write()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_flag text := tg_argv[0];
begin
  if not public.guest_can(v_flag) then
    raise exception 'GUEST_FEATURE_LOCKED: %', public.guest_lock_message(v_flag);
  end if;
  return new;
end;
$function$;

comment on function public.guard_guest_write() is
  'يمنع كتابة الزائر في جدول ما إن كان مفتاحه مغلقًا. يفحص المنادي لا الصف.';

-- ── 2) تركيب الحارس على جداول الإهداء والشراء ──
do $$
declare
  v_map constant text[][] := array[
    -- الإهداء
    ['gift_transactions',            'guest_gifts'],
    -- الشراء بأنواعه
    ['purchases',                    'guest_purchases'],
    ['membership_transactions',      'guest_purchases'],
    ['commerce_orders',              'guest_purchases'],
    ['profile_mini_store_orders',    'guest_purchases'],
    ['profile_pattern_orders',       'guest_purchases'],
    ['profile_product_orders',       'guest_purchases'],
    ['profile_service_orders',       'guest_purchases'],
    ['platform_wall_product_orders', 'guest_purchases'],
    -- المظهر المدفوع
    ['profile_cosmetic_purchases',   'guest_cosmetics'],
    ['profile_pattern_purchases',    'guest_cosmetics']
  ];
  v_table text;
  v_flag text;
  i integer;
begin
  for i in 1 .. array_length(v_map, 1) loop
    v_table := v_map[i][1];
    v_flag  := v_map[i][2];

    -- الجدول قد لا يوجد في بيئة أخرى؛ التخطّي أسلم من الفشل.
    if not exists (
      select 1 from information_schema.tables
       where table_schema='public' and table_name=v_table
    ) then
      continue;
    end if;

    execute format(
      'drop trigger if exists trg_guest_guard_%1$s on public.%1$I', v_table);
    execute format(
      'create trigger trg_guest_guard_%1$s
         before insert on public.%1$I
         for each row execute function public.guard_guest_write(%2$L)',
      v_table, v_flag);
  end loop;
end $$;

-- ── 3) تحويل النقاط والجواهر ──
-- ثغرة منفصلة وأخطر: حساب زائر مجّاني يجمع نقاطًا ثم يحوّلها إلى
-- حساب دائم — مزرعة نقاط بلا كلفة. الدالتان غلافان رفيعان، فالحارس
-- يُضاف في أولهما والجسم محفوظ حرفيًا.
insert into public.feature_flags (flag_key, is_enabled, name_ar, disabled_message_ar)
values ('guest_transfers', false, 'الزائر: تحويل النقاط والجواهر',
        'تحويل النقاط والجواهر للأعضاء المسجَّلين. سجّل ببريدك لتفتحه.')
on conflict (flag_key) do nothing;

create or replace function public.transfer_points(
  p_to_user_id uuid, p_amount bigint, p_idempotency_key uuid, p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE v_res jsonb;
BEGIN
  IF NOT public.guest_can('guest_transfers') THEN
    RAISE EXCEPTION 'GUEST_FEATURE_LOCKED: %',
      public.guest_lock_message('guest_transfers');
  END IF;
  v_res := private_rpc.transfer_points(p_to_user_id, p_amount, p_idempotency_key, p_room_id);
  BEGIN
    PERFORM public.announce_transfer(auth.uid(), p_to_user_id, p_amount, 'points', p_room_id);
  EXCEPTION WHEN others THEN NULL; END;
  RETURN v_res;
END;$function$;

create or replace function public.transfer_gems_to_user(
  p_to_user_id uuid, p_amount bigint, p_idempotency_key uuid, p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE v_res jsonb;
BEGIN
  IF NOT public.guest_can('guest_transfers') THEN
    RAISE EXCEPTION 'GUEST_FEATURE_LOCKED: %',
      public.guest_lock_message('guest_transfers');
  END IF;
  v_res := private_rpc.transfer_gems_to_user(p_to_user_id, p_amount, p_idempotency_key, p_room_id);
  BEGIN
    PERFORM public.announce_transfer(auth.uid(), p_to_user_id, p_amount, 'gems', p_room_id);
  EXCEPTION WHEN others THEN NULL; END;
  RETURN v_res;
END;$function$;

-- ── 4) رفع الملفات على طبقة التخزين ──
-- المنع السابق كان عند **تسجيل** الرسالة لا عند رفع الملف، فالزائر
-- قد ينجح في وضع ملف في التخزين وإن عجز عن إرساله. هذه سياسة على
-- storage.objects تسدّ ذلك من جذره.
do $$
begin
  if exists (select 1 from information_schema.tables
              where table_schema='storage' and table_name='objects') then
    execute 'drop policy if exists guest_upload_block on storage.objects';
    execute $pol$
      create policy guest_upload_block
        on storage.objects
        as restrictive
        for insert
        to authenticated
        with check (public.guest_can('guest_uploads'))
    $pol$;
  end if;
end $$;

-- ── 5) عرض ما هو محروس فعلًا، للتحقق لا للتوثيق ──
create or replace function public.guest_guard_report()
returns table (guarded_object text, kind text, flag text)
language sql
stable
security definer
set search_path to ''
as $$
  select c.relname::text, 'table_trigger'::text,
         split_part(split_part(pg_get_triggerdef(t.oid), '''', 2), '''', 1)
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname='public' and t.tgname like 'trg_guest_guard_%'
  union all
  select p.proname::text, 'function_guard'::text, 'inline'::text
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname in ('public','private_rpc')
     and p.prosrc like '%GUEST_FEATURE_LOCKED%'
  order by 2, 1;
$$;

grant execute on function public.guest_guard_report() to authenticated;
