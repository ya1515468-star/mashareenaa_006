-- ============================================================
-- مراهنات يدوية في الألعاب
--
-- كان الرهان محصورًا في قائمة ثابتة مكتوبة في **موضعين**: التطبيق
-- (`game_hub.dart`) والخادم (`send_game_challenge` و`trix_start_game`
-- كلتاهما فيهما `p_stake not in (0,10,50,100,500,1000)`). فتغيير
-- القائمة كان يستلزم إصدارًا جديدًا للتطبيق **وهجرة** معًا.
--
-- الآن: حدّان (أدنى وأقصى) يضبطهما المالك، والرهان أي عدد صحيح
-- بينهما. والتحقق من الرصيد كان قائمًا أصلًا ويبقى كما هو.
-- ============================================================

-- ── 1) حدود الرهان، يضبطها المالك ──
create table if not exists public.game_stake_settings (
  id            boolean primary key default true check (id),
  min_stake     bigint  not null default 0,
  max_stake     bigint  not null default 1000000,
  quick_stakes  bigint[] not null default array[0,10,50,100,500,1000]::bigint[],
  updated_at    timestamptz not null default now(),
  updated_by    uuid
);

insert into public.game_stake_settings (id) values (true)
on conflict (id) do nothing;

alter table public.game_stake_settings enable row level security;

drop policy if exists game_stake_settings_read on public.game_stake_settings;
create policy game_stake_settings_read
  on public.game_stake_settings for select to authenticated using (true);

comment on table public.game_stake_settings is
  'حدود رهان الألعاب. الصفّ واحد دائمًا (id = true).';

-- ── 2) التحقق من الرهان — مصدر واحد تستعمله كل الدوال ──
create or replace function public.validate_game_stake(p_stake bigint)
returns bigint
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_min bigint;
  v_max bigint;
  v_stake bigint := coalesce(p_stake, 0);
begin
  select min_stake, max_stake into v_min, v_max
    from public.game_stake_settings where id;

  v_min := coalesce(v_min, 0);
  v_max := coalesce(v_max, 1000000);

  if v_stake < 0 then raise exception 'INVALID_STAKE'; end if;
  -- الرهان الودّي (صفر) مسموح دائمًا مهما كان الحدّ الأدنى.
  if v_stake = 0 then return 0; end if;
  if v_stake < v_min then
    raise exception 'STAKE_BELOW_MIN: أقل رهان مسموح هو % نقطة.', v_min;
  end if;
  if v_stake > v_max then
    raise exception 'STAKE_ABOVE_MAX: أعلى رهان مسموح هو % نقطة.', v_max;
  end if;
  return v_stake;
end;
$function$;

-- ── 3) ما يحتاجه التطبيق لرسم الحقل ──
-- الحدود + رصيد النقاط الحالي، فيُعرض للمستخدم أقصى ما يستطيع
-- المراهنة به قبل أن يكتب لا بعد أن يُرفض.
create or replace function public.my_game_stake_limits()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select jsonb_build_object(
    'min', coalesce((select min_stake from public.game_stake_settings where id), 0),
    'max', coalesce((select max_stake from public.game_stake_settings where id), 1000000),
    'quick', coalesce((select to_jsonb(quick_stakes) from public.game_stake_settings where id),
                      '[0,10,50,100,500,1000]'::jsonb),
    'balance', coalesce(
      (select balance from public.points_wallets where user_id = auth.uid()), 0),
    'is_owner', public._is_platform_owner(auth.uid())
  );
$$;

grant execute on function public.my_game_stake_limits() to authenticated;
grant execute on function public.validate_game_stake(bigint) to authenticated;

-- ── 4) ضبط الحدود — للمالك أو السوبر أدمن ──
create or replace function public.owner_set_game_stake_limits(
  p_min bigint default null,
  p_max bigint default null,
  p_quick bigint[] default null
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.can_manage_guest_settings() then raise exception 'FORBIDDEN'; end if;
  if p_min is not null and p_min < 0 then raise exception 'INVALID_MIN'; end if;
  if p_max is not null and p_max <= 0 then raise exception 'INVALID_MAX'; end if;
  if p_min is not null and p_max is not null and p_min > p_max then
    raise exception 'MIN_ABOVE_MAX';
  end if;

  update public.game_stake_settings
     set min_stake    = coalesce(p_min, min_stake),
         max_stake    = coalesce(p_max, max_stake),
         quick_stakes = coalesce(p_quick, quick_stakes),
         updated_at   = now(),
         updated_by   = v_uid
   where id;

  insert into public.audit_logs(
    actor_user_id, actor_id, action, resource_type, resource_id,
    target_id, result, metadata)
  values (v_uid, v_uid, 'GAME_STAKE_LIMITS_UPDATED', 'game_stake_settings',
          'singleton', 'singleton', 'success',
          jsonb_build_object('min', p_min, 'max', p_max));

  return public.my_game_stake_limits();
end;
$function$;

grant execute on function public.owner_set_game_stake_limits(bigint, bigint, bigint[])
  to authenticated;

-- ── 5) استبدال القائمة الثابتة في الدالتين ──
-- الجسمان منسوخان حرفيًا من النسخة المنشورة، والتغيير سطر واحد في
-- كلٍّ منهما: `not in (…)` ← `validate_game_stake`.
create or replace function public.send_game_challenge(
  p_to_uid uuid, p_game_type text, p_stake bigint default 0,
  p_room_id uuid default null, p_side text default null)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_uid uuid:=auth.uid(); v_id uuid; v_label text; v_bal bigint;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_to_uid is null or p_to_uid=v_uid then raise exception 'INVALID_PARTICIPANT'; end if;
 if p_game_type not in ('connect4','rps','coin','trix_solo','trix_partner') then raise exception 'INVALID_GAME'; end if;
 perform public.validate_game_stake(p_stake);
 if p_side is not null and p_side not in ('heads','tails') then raise exception 'INVALID_SIDE'; end if;
 if public._users_blocked(v_uid,p_to_uid) then raise exception 'BLOCKED'; end if;
 if not exists(select 1 from public.profiles where id=p_to_uid and is_active=true) then raise exception 'TARGET_NOT_FOUND'; end if;
 if p_stake>0 and not public._is_platform_owner(v_uid) then
   select balance into v_bal from public.points_wallets where user_id=v_uid;
   if coalesce(v_bal,0)<p_stake then raise exception 'INSUFFICIENT_POINTS'; end if;
 end if;
 update public.game_requests set status='expired', updated_at=now() where status='pending' and created_at<now()-interval '10 minutes';
 if exists(select 1 from public.game_requests where from_uid=v_uid and to_uid=p_to_uid and status='pending') then raise exception 'REQUEST_ALREADY_PENDING'; end if;
 insert into public.game_requests(from_uid,to_uid,game_type,stake_points,room_id,pick) values(v_uid,p_to_uid,p_game_type,p_stake,p_room_id,case when p_game_type='coin' then coalesce(p_side,'heads') else null end) returning id into v_id;
 v_label:=case p_game_type when 'connect4' then 'أربعة في صف' when 'rps' then 'حجر ورقة مقص' when 'trix_solo' then 'تركس سوري (فردي)' when 'trix_partner' then 'تركس سوري (شراكة معك)' else 'العملة — اختار '||case when coalesce(p_side,'heads')='heads' then 'صورة' else 'كتابة' end end;
 insert into public.notifications(uid,type,title,body,related_id,actor_uid,is_read,created_at)
 values(p_to_uid,'system','طلب لعبة','تحداك '||v_label||case when p_stake>0 then ' على '||p_stake||' نقطة' else ' (ودّي)' end,v_id::text,v_uid,false,now());
 return v_id;
end$function$;

create or replace function public.trix_start_game(
  p_mode text, p_variant text default 'classic',
  p_stake bigint default 0, p_room_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v uuid:=auth.uid(); bal bigint;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_mode not in ('solo','partner') then raise exception 'INVALID_GAME'; end if;
 perform public.validate_game_stake(p_stake);
 perform public.trix_my_active();
 if private.trix_user_busy(v) then raise exception 'ALREADY_IN_GAME'; end if;
 if p_stake>0 and not public._is_platform_owner(v) then select balance into bal from public.points_wallets where user_id=v; if coalesce(bal,0)<p_stake then raise exception 'INSUFFICIENT_POINTS'; end if; end if;
 return private.trix_create2(p_mode,p_variant,array[v,null,null,null]::uuid[],p_stake,p_room_id,null,null);
end$function$;
