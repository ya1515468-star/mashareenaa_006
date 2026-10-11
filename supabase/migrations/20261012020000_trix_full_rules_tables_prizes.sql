-- ════════════════════════════════════════════════════════════════════
-- تركس — القواعد العالمية (مرجع Jawaker) + طاولات 4 لاعبين حقيقيين 2×2
-- + المضاعفة (الدبل) + كومبلكس + تسريع + جوائز نقاط وجواهر + تصاميم الورق.
-- متوافق مع المباريات الجارية: كل الأعمدة الجديدة لها قيم افتراضية تُبقي
-- السلوك القديم كما هو (classic، بلا دبل، مالك المملكة الأولى = المقعد 0).
-- ════════════════════════════════════════════════════════════════════

-- ───── الأعمدة الجديدة ─────
alter table public.trix_games add column if not exists variant text not null default 'classic';
alter table public.trix_games add column if not exists doubles jsonb not null default '{}'::jsonb;
alter table public.trix_games add column if not exists double_pending jsonb not null default '[]'::jsonb;
alter table public.trix_games add column if not exists phase_deadline timestamptz;
alter table public.trix_games add column if not exists kingdom_start int not null default 0;
alter table public.trix_games add column if not exists table_id uuid;

-- ───── طاولات اللعب الجماعي ─────
create table if not exists public.trix_tables (
  id uuid primary key default gen_random_uuid(),
  host uuid not null references public.profiles(id),
  mode text not null check (mode in ('solo','partner')),
  variant text not null default 'classic' check (variant in ('classic','complex')),
  stake bigint not null default 0 check (stake in (0,10,50,100,500,1000)),
  room_id uuid,
  seats uuid[] not null default array[null,null,null,null]::uuid[],
  escrow jsonb not null default '{}'::jsonb,
  status text not null default 'open' check (status in ('open','started','cancelled')),
  game_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '20 minutes'
);
create index if not exists trix_tables_room_open on public.trix_tables(room_id) where status = 'open';

create table if not exists public.trix_table_invites (
  id uuid primary key default gen_random_uuid(),
  table_id uuid not null references public.trix_tables(id),
  from_uid uuid not null references public.profiles(id),
  to_uid uuid not null references public.profiles(id),
  seat int not null check (seat between 1 and 3),
  status text not null default 'pending' check (status in ('pending','accepted','declined','expired','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists trix_table_invites_to on public.trix_table_invites(to_uid) where status = 'pending';

-- تصميم وجه الورق لكل مستخدم
create table if not exists public.user_card_face (
  user_id uuid primary key references public.profiles(id),
  face_key text not null default 'classic',
  updated_at timestamptz not null default now()
);

-- جوائز بالجواهر + سجل
alter table public.game_prizes add column if not exists gems bigint not null default 0;
alter table public.game_prize_log add column if not exists gems bigint not null default 0;
insert into public.game_prizes(game, amount, gems) values
  ('trix_human', 200, 2),
  ('trix_bot', 50, 0)
on conflict (game) do update set amount = excluded.amount, gems = excluded.gems;

-- ───── RLS + Realtime ─────
alter table public.trix_tables enable row level security;
alter table public.trix_table_invites enable row level security;
alter table public.user_card_face enable row level security;
create policy trix_games_participants_read on public.trix_games
  for select to authenticated using ((select auth.uid()) = any(seats));
create policy trix_tables_read on public.trix_tables
  for select to authenticated using (status = 'open' or (select auth.uid()) = any(seats) or host = (select auth.uid()));
create policy trix_table_invites_read on public.trix_table_invites
  for select to authenticated using (to_uid = (select auth.uid()) or from_uid = (select auth.uid()));
create policy user_card_face_own on public.user_card_face
  for select to authenticated using (user_id = (select auth.uid()));
alter publication supabase_realtime add table public.trix_games;
alter publication supabase_realtime add table public.trix_tables;
alter publication supabase_realtime add table public.trix_table_invites;

-- ════════════════════ المحرّك ════════════════════

create or replace function private.trix_owner(p_game uuid)
returns int language sql stable security definer set search_path to 'public' as $$
  select ((kingdom_start + kingdom) % 4) from public.trix_games where id = p_game $$;

create or replace function private.trix_contracts(p_variant text)
returns text[] language sql immutable set search_path to 'public' as $$
  select case when p_variant = 'complex' then array['complex','trix']
              else array['king','queens','diamonds','slaps','trix'] end $$;

-- الأوراق القابلة للدبل في يد معيّنة لعقد معيّن.
create or replace function private.trix_doublable(p_contract text, p_hand jsonb)
returns text[] language sql immutable set search_path to 'public' as $$
  select coalesce(array_agg(c order by c), '{}') from jsonb_array_elements_text(p_hand) c
   where (p_contract in ('king','complex') and c = 'H13')
      or (p_contract in ('queens','complex') and substr(c,2)::int = 12) $$;

-- قرار الكمبيوتر بالدبل: يدبل الورقة إن كان يملك في نوعها 4 أوراق على
-- الأقل منها اثنتان صغيرتان (< 9) يستطيع التهرّب بهما.
create or replace function private.trix_bot_doubles(p_contract text, p_hand jsonb)
returns text[] language sql immutable set search_path to 'public' as $$
  select coalesce(array_agg(d), '{}') from unnest(private.trix_doublable(p_contract, p_hand)) d
   where (select count(*) from jsonb_array_elements_text(p_hand) x where left(x,1) = left(d,1)) >= 4
     and (select count(*) from jsonb_array_elements_text(p_hand) x where left(x,1) = left(d,1) and substr(x,2)::int < 9) >= 2 $$;

-- التوزيع: مالك المملكة الأولى = حامل 7♥ في أول توزيعة (قاعدة Jawaker).
create or replace function private.trix_deal(p_game uuid)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare g public.trix_games; deck text[]; hands jsonb:='[]'; i int; part text[]; v_start int; v_owner int;
begin
 select * into g from public.trix_games where id=p_game for update;
 select array_agg(su.suit||gr.rnk order by random()) into deck from unnest(array['S','H','D','C']) as su(suit), generate_series(2,14) as gr(rnk);
 for i in 0..3 loop
  select array_agg(c order by case left(c,1) when 'S' then 1 when 'H' then 2 when 'D' then 3 else 4 end, substr(c,2)::int)
   into part from unnest(deck[(i*13+1):(i*13+13)]) c;
  hands:=hands||jsonb_build_array(to_jsonb(part));
 end loop;
 insert into public.trix_secrets(game_id,hands) values(p_game,hands) on conflict (game_id) do update set hands=excluded.hands;
 v_start := g.kingdom_start;
 if g.kingdom = 0 and jsonb_array_length(g.history) = 0
    and array_length(g.remaining,1) = array_length(private.trix_contracts(g.variant),1) then
   for i in 0..3 loop
     if (hands->i) ? 'H7' then v_start := i; exit; end if;
   end loop;
 end if;
 v_owner := (v_start + g.kingdom) % 4;
 update public.trix_games set kingdom_start=v_start, phase='choose', contract=null, turn=v_owner, leader=v_owner, trick='[]', last_trick=null,
   layout='{}', finish_order='[]', counts='[0,0,0,0]', taken='[[],[],[],[]]', hand_delta=null, doubles='{}', double_pending='[]',
   phase_deadline=null,
   hand_no=array_length(private.trix_contracts(g.variant),1)-array_length(remaining,1), seq=seq+1, updated_at=now() where id=p_game;
end$function$;

create or replace function private.trix_advance(p_game uuid)
returns boolean language plpgsql security definer set search_path to 'public' as $function$
declare g public.trix_games;
begin
 select * into g from public.trix_games where id=p_game for update;
 if g.status<>'active' or g.phase<>'handover' then return false; end if;
 if g.updated_at>now()-interval '2 seconds' then return false; end if;
 if array_length(g.remaining,1) is null then
  if g.kingdom>=3 then perform private.trix_settle(p_game,null); return true; end if;
  update public.trix_games set kingdom=kingdom+1, remaining=private.trix_contracts(g.variant) where id=p_game;
 end if;
 perform private.trix_deal(p_game);
 return true;
end$function$;

create or replace function private.trix_choose_core(p_game uuid, p_contract text)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare g public.trix_games; h jsonb; i int; k int; st int; v_owner int; pend jsonb:='[]'; dbl jsonb:='{}'; c text;
begin
 select * into g from public.trix_games where id=p_game for update;
 if g.status<>'active' or g.phase<>'choose' then raise exception 'NOT_CHOOSING'; end if;
 if not (p_contract = any(g.remaining)) then raise exception 'CONTRACT_USED'; end if;
 v_owner := (g.kingdom_start + g.kingdom) % 4;
 st:=v_owner;
 select hands into h from public.trix_secrets where game_id=p_game;
 if p_contract='trix' then
  st:=null;
  for i in 0..3 loop
   k:=(v_owner+i)%4;
   if array_length(private.trix_legal('trix',h->k,'[]','{}'),1) is not null then st:=k; exit; end if;
  end loop;
  st:=coalesce(st,v_owner);
 end if;
 -- نافذة الدبل: الكمبيوتر يقرّر فورًا، والإنسان الذي يملك ورقة قابلة للدبل
 -- يُعطى 12 ثانية (أو حتى يضغط تم). اللعب ممنوع ما دامت القائمة غير فارغة.
 if p_contract in ('king','queens','complex') then
  for i in 0..3 loop
   if array_length(private.trix_doublable(p_contract, h->i),1) is null then continue; end if;
   if g.seats[i+1] is null then
     foreach c in array private.trix_bot_doubles(p_contract, h->i) loop
       dbl := dbl || jsonb_build_object(c, i);
     end loop;
   else
     pend := pend || to_jsonb(i);
   end if;
  end loop;
 end if;
 update public.trix_games set contract=p_contract, remaining=array_remove(remaining,p_contract), phase='play',
   turn=st, leader=st, trick='[]', doubles=dbl, double_pending=pend,
   phase_deadline=case when jsonb_array_length(pend)>0 then now()+interval '12 seconds' else null end,
   seq=seq+1, updated_at=now() where id=p_game;
end$function$;

create or replace function public.trix_double(p_game uuid, p_cards text[])
returns void language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); g public.trix_games; me int; h jsonb; ok text[]; c text; dbl jsonb; pend jsonb;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into g from public.trix_games where id=p_game for update;
 if not found or array_position(g.seats,v) is null then raise exception 'GAME_NOT_FOUND'; end if;
 me := array_position(g.seats,v)-1;
 if g.status<>'active' or g.phase<>'play' or not (g.double_pending @> to_jsonb(me)) then raise exception 'NOT_DOUBLING'; end if;
 select hands into h from public.trix_secrets where game_id=p_game;
 ok := private.trix_doublable(g.contract, h->me);
 dbl := g.doubles;
 foreach c in array coalesce(p_cards,'{}') loop
   if not (c = any(ok)) then raise exception 'CANNOT_DOUBLE'; end if;
   dbl := dbl || jsonb_build_object(c, me);
 end loop;
 select coalesce(jsonb_agg(x),'[]') into pend from jsonb_array_elements(g.double_pending) x where x <> to_jsonb(me);
 update public.trix_games set doubles=dbl, double_pending=pend,
   phase_deadline=case when jsonb_array_length(pend)>0 then phase_deadline else null end,
   seq=seq+1, updated_at=now() where id=p_game;
end$function$;

create or replace function private.trix_bot_choose(p_game uuid)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare g public.trix_games; h jsonb; jacks int; pick text; opts text[]; v_owner int;
begin
 select * into g from public.trix_games where id=p_game;
 select hands into h from public.trix_secrets where game_id=p_game;
 v_owner := (g.kingdom_start + g.kingdom) % 4;
 select count(*) into jacks from jsonb_array_elements_text(h->v_owner) c where substr(c,2)::int=11;
 if 'trix' = any(g.remaining) and (jacks>=2 or array_length(g.remaining,1)=1) then pick:='trix';
 else
  opts:=array_remove(g.remaining,'trix');
  if array_length(opts,1) is null then opts:=g.remaining; end if;
  pick:=opts[1+floor(random()*array_length(opts,1))::int];
 end if;
 perform private.trix_choose_core(p_game,pick);
end$function$;

-- اختيار ورقة الكمبيوتر — يشمل الكومبلكس (كل الأوراق الخطِرة معًا).
create or replace function private.trix_bot_pick(p_contract text, p_hand jsonb, p_trick jsonb, p_layout jsonb)
returns text language plpgsql set search_path to 'public' as $function$
declare lg text[]; c text; best text; lead text; win int:=0; cand text[]; below text[]; s text;
 bs numeric:=-1; sc numeric;
begin
 lg:=private.trix_legal(p_contract,p_hand,p_trick,p_layout);
 if array_length(lg,1) is null then return null; end if;
 if p_contract='trix' then
  foreach c in array lg loop
   s:=left(c,1);
   sc:=(select count(*) from jsonb_array_elements_text(p_hand) x where left(x,1)=s)+random();
   if sc>bs then bs:=sc; best:=c; end if;
  end loop;
  return best;
 end if;
 if jsonb_array_length(p_trick)=0 then
  bs:=1000;
  foreach c in array lg loop
   sc:=substr(c,2)::int
     + case when c='H13' and p_contract in ('king','complex') then 60 else 0 end
     + case when substr(c,2)::int=12 and p_contract in ('queens','complex') then 50 else 0 end
     + case when left(c,1)='D' and p_contract in ('diamonds','complex') then 8 else 0 end
     + random()*0.1;
   if sc<bs then bs:=sc; best:=c; end if;
  end loop;
  return best;
 end if;
 lead:=left(p_trick->0->>'c',1);
 select max(substr(x->>'c',2)::int) into win from jsonb_array_elements(p_trick) x where left(x->>'c',1)=lead;
 select coalesce(array_agg(x),'{}') into cand from unnest(lg) x where left(x,1)=lead;
 if array_length(cand,1) is not null then
  select coalesce(array_agg(x),'{}') into below from unnest(cand) x where substr(x,2)::int<win;
  if array_length(below,1) is not null then
   select x into best from unnest(below) x order by substr(x,2)::int desc limit 1; return best;
  end if;
  select x into best from unnest(cand) x order by substr(x,2)::int asc limit 1;
  if jsonb_array_length(p_trick)=3 then
    select x into best from unnest(cand) x
     where not (x='H13' and p_contract in ('king','complex'))
       and not (substr(x,2)::int=12 and p_contract in ('queens','complex'))
     order by substr(x,2)::int desc limit 1;
    if best is null then select x into best from unnest(cand) x order by substr(x,2)::int asc limit 1; end if;
  end if;
  return best;
 end if;
 foreach c in array lg loop
  sc:=substr(c,2)::int + case
    when p_contract in ('king','complex') and c='H13' then 100
    when p_contract='king' and left(c,1)='H' then 30
    when p_contract in ('queens','complex') and substr(c,2)::int=12 then 90
    when p_contract in ('diamonds','complex') and left(c,1)='D' then 30
    else 0 end + random()*0.1;
  if sc>bs then bs:=sc; best:=c; end if;
 end loop;
 return best;
end$function$;

-- التسجيل مع الدبل (Jawaker): من يأكل ورقة مدبولة يخسر ضعفها، والمدبِّل
-- يكسب قيمتها الأصلية (إلا إن أكلها بنفسه).
create or replace function private.trix_score2(p_contract text, p_taken jsonb, p_finish jsonb, p_doubles jsonb)
returns integer[] language plpgsql immutable set search_path to 'public' as $function$
declare d int[]:=array[0,0,0,0]; i int; c text; pos int[]:=array[200,150,100,50]; dbl int;
begin
 if p_contract='trix' then
  for i in 0..3 loop
   if jsonb_array_length(p_finish)>i then d[(p_finish->>i)::int+1]:=pos[i+1]; end if;
  end loop;
  return d;
 end if;
 for i in 0..3 loop
  for c in select jsonb_array_elements_text(p_taken->i) loop
   if p_contract in ('king','complex') and c='H13' then
     dbl := (p_doubles->>c)::int;
     if dbl is null then d[i+1]:=d[i+1]-75;
     else d[i+1]:=d[i+1]-150; if dbl<>i then d[dbl+1]:=d[dbl+1]+75; end if; end if;
   end if;
   if p_contract in ('queens','complex') and substr(c,2)::int=12 then
     dbl := (p_doubles->>c)::int;
     if dbl is null then d[i+1]:=d[i+1]-25;
     else d[i+1]:=d[i+1]-50; if dbl<>i then d[dbl+1]:=d[dbl+1]+25; end if; end if;
   end if;
   if p_contract in ('diamonds','complex') and left(c,1)='D' then d[i+1]:=d[i+1]-10; end if;
  end loop;
  if p_contract in ('slaps','complex') then d[i+1]:=d[i+1]-15*(jsonb_array_length(p_taken->i)/4); end if;
 end loop;
 return d;
end$function$;

create or replace function private.trix_apply_play(p_game uuid, p_seat integer, p_card text)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare g public.trix_games; h jsonb; hand jsonb; lg text[]; lay jsonb; s text; r int; i int; cand int; fin jsonb; tr jsonb;
 w int; best int; lead text; tk jsonb; cards jsonb; done boolean:=false; d int[]; sc jsonb; qn int; dn int; k int;
begin
 select * into g from public.trix_games where id=p_game for update;
 if g.status<>'active' or g.phase<>'play' then raise exception 'NOT_PLAYING'; end if;
 if jsonb_array_length(g.double_pending)>0 then raise exception 'DOUBLING_IN_PROGRESS'; end if;
 if g.turn<>p_seat then raise exception 'NOT_YOUR_TURN'; end if;
 select hands into h from public.trix_secrets where game_id=p_game for update;
 hand:=h->p_seat;
 if not (hand ? p_card) then raise exception 'CARD_NOT_IN_HAND'; end if;
 lg:=private.trix_legal(g.contract,hand,g.trick,g.layout);
 if not (p_card = any(lg)) then raise exception 'ILLEGAL_MOVE'; end if;
 select coalesce(jsonb_agg(x order by o),'[]') into hand from jsonb_array_elements_text(hand) with ordinality a(x,o) where x<>p_card;
 h:=jsonb_set(h,array[p_seat::text],hand);
 update public.trix_secrets set hands=h where game_id=p_game;
 tk:=g.taken; fin:=g.finish_order; lay:=g.layout;
 if g.contract='trix' then
  s:=left(p_card,1); r:=substr(p_card,2)::int;
  if lay->s is null then lay:=jsonb_set(lay,array[s],jsonb_build_object('lo',r,'hi',r));
  elsif r<(lay->s->>'lo')::int then lay:=jsonb_set(lay,array[s,'lo'],to_jsonb(r));
  else lay:=jsonb_set(lay,array[s,'hi'],to_jsonb(r)); end if;
  if jsonb_array_length(hand)=0 then fin:=fin||to_jsonb(p_seat); end if;
  if jsonb_array_length(fin)>=3 then
   done:=true;
   for i in 0..3 loop if not (fin @> to_jsonb(i)) then fin:=fin||to_jsonb(i); end if; end loop;
  else
   cand:=null;
   for i in 1..4 loop
    k:=(p_seat+i)%4;
    if jsonb_array_length(h->k)>0 and array_length(private.trix_legal('trix',h->k,'[]',lay),1) is not null then cand:=k; exit; end if;
   end loop;
   if cand is null then
    done:=true;
    for i in 0..3 loop if not (fin @> to_jsonb(i)) then fin:=fin||to_jsonb(i); end if; end loop;
   end if;
  end if;
  update public.trix_games set layout=lay, finish_order=fin, turn=coalesce(cand,p_seat),
    last_trick=jsonb_build_object('cards',jsonb_build_array(jsonb_build_object('s',p_seat,'c',p_card)),'winner',null,'trix',true)
   where id=p_game;
 else
  tr:=g.trick||jsonb_build_array(jsonb_build_object('s',p_seat,'c',p_card));
  if jsonb_array_length(tr)<4 then
   update public.trix_games set trick=tr, turn=(p_seat+1)%4 where id=p_game;
  else
   lead:=left(tr->0->>'c',1); best:=0; w:=0;
   for i in 0..3 loop
    if left(tr->i->>'c',1)=lead and substr(tr->i->>'c',2)::int>best then best:=substr(tr->i->>'c',2)::int; w:=(tr->i->>'s')::int; end if;
   end loop;
   select jsonb_agg(x->'c') into cards from jsonb_array_elements(tr) x;
   tk:=jsonb_set(tk,array[w::text],(tk->w)||cards);
   update public.trix_games set trick='[]', last_trick=jsonb_build_object('cards',tr,'winner',w,'n',(g.counts->>0)::int+(g.counts->>1)::int+(g.counts->>2)::int+(g.counts->>3)::int+1), taken=tk,
     counts=jsonb_set(counts,array[w::text],to_jsonb((counts->>w)::int+1)), turn=w, leader=w where id=p_game;
   if jsonb_array_length(h->0)=0 and jsonb_array_length(h->1)=0 and jsonb_array_length(h->2)=0 and jsonb_array_length(h->3)=0 then done:=true; end if;
   if g.contract='king' and tk::text like '%"H13"%' then done:=true; end if;
   if g.contract='queens' then
    select count(*) into qn from jsonb_array_elements(tk) a, jsonb_array_elements_text(a.value) c where substr(c,2)::int=12;
    if qn>=4 then done:=true; end if;
   end if;
   if g.contract='diamonds' then
    select count(*) into dn from jsonb_array_elements(tk) a, jsonb_array_elements_text(a.value) c where left(c,1)='D';
    if dn>=13 then done:=true; end if;
   end if;
  end if;
 end if;
 if done then
  d:=private.trix_score2(g.contract,case when g.contract='trix' then '[[],[],[],[]]'::jsonb else tk end,fin,g.doubles);
  select jsonb_agg((x::int)+d[o::int] order by o) into sc from jsonb_array_elements_text(g.scores) with ordinality a(x,o);
  update public.trix_games set phase='handover', turn=-1, hand_delta=to_jsonb(d), scores=sc, finish_order=fin,
    history=history||jsonb_build_array(jsonb_build_object('kingdom',g.kingdom,'hand',g.hand_no,'contract',g.contract,'delta',to_jsonb(d),'doubles',g.doubles)) where id=p_game;
 end if;
 update public.trix_games set seq=seq+1, updated_at=now() where id=p_game;
end$function$;

-- خطوة آلية: الكمبيوتر، أو انتهاء نافذة الدبل، أو لاعب غائب (30 ث).
create or replace function public.trix_bot_step(p_game uuid)
returns boolean language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); g public.trix_games; h jsonb; c text; afk boolean;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into g from public.trix_games where id=p_game for update;
 if not found or array_position(g.seats,v) is null then raise exception 'GAME_NOT_FOUND'; end if;
 if g.status<>'active' then return false; end if;
 if g.phase='handover' then return private.trix_advance(p_game); end if;
 if g.phase='play' and jsonb_array_length(g.double_pending)>0 then
   if g.phase_deadline is not null and now()>g.phase_deadline then
     update public.trix_games set double_pending='[]', phase_deadline=null, seq=seq+1, updated_at=now() where id=p_game;
     return true;
   end if;
   return false;
 end if;
 if g.updated_at>now()-interval '450 milliseconds' then return false; end if;
 if g.turn<0 then return false; end if;
 afk := g.seats[g.turn+1] is not null and g.updated_at < now()-interval '30 seconds';
 if g.seats[g.turn+1] is not null and not afk then return false; end if;
 if g.phase='choose' then perform private.trix_bot_choose(p_game); return true; end if;
 if g.phase='play' then
  select hands into h from public.trix_secrets where game_id=p_game;
  c:=private.trix_bot_pick(g.contract,h->g.turn,g.trick,g.layout);
  if c is null then return false; end if;
  perform private.trix_apply_play(p_game,g.turn,c);
  return true;
 end if;
 return false;
end$function$;

-- توافق مع الإصدار الحالي من التطبيق (لا يعرف نافذة الدبل): أي قراءة أو
-- لعب بعد انتهاء النافذة يغلقها تلقائيًا، فلا تعلق اللعبة عند إنسان.
create or replace function private.trix_expire_doubling(p_game uuid)
returns void language plpgsql security definer set search_path to 'public' as $function$
begin
 update public.trix_games set double_pending='[]', phase_deadline=null, seq=seq+1, updated_at=now()
  where id=p_game and status='active' and phase='play' and jsonb_array_length(double_pending)>0
    and phase_deadline is not null and phase_deadline<now();
end$function$;

create or replace function public.trix_play(p_game uuid, p_card text)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); g public.trix_games;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into g from public.trix_games where id=p_game;
 if not found or array_position(g.seats,v) is null then raise exception 'GAME_NOT_FOUND'; end if;
 perform private.trix_expire_doubling(p_game);
 perform private.trix_apply_play(p_game,array_position(g.seats,v)-1,p_card);
end$function$;

create or replace function public.trix_my_view(p_game uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); g public.trix_games; h jsonb; me int; j jsonb; lg text[]; names jsonb:='[]'; i int; nm text; mydbl text[]:='{}';
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into g from public.trix_games where id=p_game;
 if not found or array_position(g.seats,v) is null then raise exception 'GAME_NOT_FOUND'; end if;
 if jsonb_array_length(g.double_pending)>0 and g.phase_deadline<now() then
   perform private.trix_expire_doubling(p_game);
   select * into g from public.trix_games where id=p_game;
 end if;
 me:=array_position(g.seats,v)-1;
 select hands into h from public.trix_secrets where game_id=p_game;
 j:=to_jsonb(g)-'escrow';
 for i in 0..3 loop
  if g.seats[i+1] is null then nm:='الكمبيوتر '||(i+1);
  else select coalesce(nullif(trim(display_name),''),nullif(trim(username),''),'عضو') into nm from public.profiles where id=g.seats[i+1]; end if;
  names:=names||to_jsonb(coalesce(nm,'عضو'));
 end loop;
 lg:='{}';
 if g.status='active' and g.phase='play' and g.turn=me and jsonb_array_length(g.double_pending)=0 then
   lg:=private.trix_legal(g.contract,h->me,g.trick,g.layout);
 end if;
 if g.status='active' and g.phase='play' and g.double_pending @> to_jsonb(me) then
   mydbl := private.trix_doublable(g.contract, h->me);
 end if;
 return j||jsonb_build_object('me',me,'hand',case when g.status='active' then h->me else '[]'::jsonb end,'legal',to_jsonb(lg),'names',names,
   'owner',(g.kingdom_start+g.kingdom)%4,
   'contracts',to_jsonb(private.trix_contracts(g.variant)),
   'my_doublable',to_jsonb(mydbl),
   'server_now',now(),
   'humans',(select count(*) from unnest(g.seats) as st(seat_uid) where st.seat_uid is not null),
   'hand_sizes',jsonb_build_array(jsonb_array_length(h->0),jsonb_array_length(h->1),jsonb_array_length(h->2),jsonb_array_length(h->3)));
end$function$;

-- الجوائز: نقاط + جواهر، بحد 20 جائزة يوميًا و5 جوائز جواهر يوميًا لكل مستخدم.
create or replace function private.award_game_prize(p_uid uuid, p_game text, p_ref text)
returns bigint language plpgsql security definer set search_path to 'public' as $function$
declare amt bigint; gm bigint; n int; ng int; b bigint;
begin
 if p_uid is null then return 0; end if;
 if not private.game_prize_eligible(p_uid) then return 0; end if;
 select amount, gems into amt, gm from public.game_prizes where game=p_game;
 if coalesce(amt,0)<=0 and coalesce(gm,0)<=0 then return 0; end if;
 perform pg_advisory_xact_lock(hashtext('prize'||p_uid::text));
 select count(*), count(*) filter (where gems>0) into n, ng from public.game_prize_log where user_id=p_uid and created_at>now()-interval '24 hours';
 if n>=20 then return 0; end if;
 if ng>=5 then gm:=0; end if;
 if exists(select 1 from public.game_prize_log where user_id=p_uid and game=p_game and ref=p_ref) then return 0; end if;
 insert into public.game_prize_log(user_id,game,ref,amount,gems) values(p_uid,p_game,p_ref,coalesce(amt,0),coalesce(gm,0));
 if coalesce(amt,0)>0 then perform private.trix_wallet(p_uid,amt,'game_prize',p_ref); end if;
 if coalesce(gm,0)>0 then
   insert into public.gems_wallets(user_id) values(p_uid) on conflict (user_id) do nothing;
   select balance into b from public.gems_wallets where user_id=p_uid for update;
   update public.gems_wallets set balance=balance+gm, lifetime_earned=lifetime_earned+gm, version=version+1, updated_at=now() where user_id=p_uid;
   insert into public.wallet_transactions(user_id,currency,amount,balance_before,balance_after,transaction_type,reference_type,reference_id,idempotency_key,metadata,created_by)
   values(p_uid,'gems',gm,coalesce(b,0),coalesce(b,0)+gm,'game_prize','game_prize',p_ref,gen_random_uuid(),jsonb_build_object('game',p_game),p_uid);
 end if;
 return coalesce(amt,0);
end$function$;

create or replace function private.trix_settle(p_game uuid, p_resign integer default null)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare g public.trix_games; sc int[]; nets bigint[]:=array[0,0,0,0]; S bigint; i int; j int; pos int; t int; vals bigint[]; tot bigint;
 t0 int; t1 int; uid uuid; esc bigint; pay bigint; txt text; humans int; v_won boolean; v_kind text; v_prize bigint; v_pg text; v_gems bigint;
begin
 select * into g from public.trix_games where id=p_game for update;
 if g.settled then return; end if;
 S:=g.stake;
 humans := (select count(*) from unnest(g.seats) as st(seat_uid) where st.seat_uid is not null);
 select array_agg(x::int order by o) into sc from jsonb_array_elements_text(g.scores) with ordinality a(x,o);
 if p_resign is not null then
  for i in 0..3 loop
   if g.seats[i+1] is null then continue; end if;
   if i=p_resign or (g.mode='partner' and i%2=p_resign%2) then nets[i+1]:=-S; else nets[i+1]:=S; end if;
  end loop;
 elsif g.mode='solo' then
  vals:=array[2*S,0,-S,-S];
  for i in 1..4 loop
   pos:=1; t:=0;
   for j in 1..4 loop
    if sc[j]>sc[i] then pos:=pos+1; end if;
    if sc[j]=sc[i] then t:=t+1; end if;
   end loop;
   tot:=0; for j in pos..pos+t-1 loop tot:=tot+vals[j]; end loop;
   nets[i]:=floor(tot::numeric/t);
  end loop;
 else
  t0:=sc[1]+sc[3]; t1:=sc[2]+sc[4];
  for i in 0..3 loop
   nets[i+1]:=case when t0=t1 then 0 when (i%2=0)=(t0>t1) then S else -S end;
  end loop;
 end if;
 v_pg := case when humans=4 then 'trix_human' else 'trix_bot' end;
 select coalesce(gems,0) into v_gems from public.game_prizes where game=v_pg;
 for i in 0..3 loop
  uid:=g.seats[i+1];
  if uid is null then continue; end if;
  esc:=coalesce((g.escrow->>uid::text)::bigint,0);
  pay:=case when public._is_platform_owner(uid) then greatest(nets[i+1],0) else greatest(esc+nets[i+1],0) end;
  if nets[i+1]>0 and not private.game_prize_eligible(uid) and humans<4 then pay:=least(pay,esc); end if;
  if pay>0 then perform private.trix_wallet(uid,pay,'trix_payout',p_game::text); end if;
  txt:='🃏 تركس: '||case when S=0 then 'مباراة ودّية' when nets[i+1]>0 then 'ربحت '||nets[i+1]||' نقطة' when nets[i+1]<0 then 'خسرت '||(-nets[i+1])||' نقطة' else 'تعادل' end;
  v_won:=case when p_resign is not null then not (i=p_resign or (g.mode='partner' and i%2=p_resign%2))
    when g.mode='solo' then sc[i+1]=(select max(x) from unnest(sc) x)
    else t0<>t1 and ((i%2=0)=(t0>t1)) end;
  v_kind:=case when v_won then 'win' when p_resign is null and g.mode='partner' and t0=t1 then 'draw' else 'lose' end;
  v_prize:=0;
  -- الجائزة للمباريات المكتملة فقط: الفوز بانسحاب الخصم بلا جائزة، وإلا
  -- أمكن لحسابات متواطئة حصد الجواهر بانسحاب فوري.
  if v_won and p_resign is null then v_prize:=private.award_game_prize(uid,v_pg,p_game::text); end if;
  perform private.game_notify(uid,v_kind,txt||case when v_prize>0 then ' — 🎁 جائزة +'||v_prize||' نقطة'||case when v_gems>0 then ' و'||v_gems||' 💎' else '' end else '' end,p_game::text,uid);
 end loop;
 update public.trix_games set status='finished', phase='done', turn=-1, settled=true, updated_at=now(), seq=seq+1,
   result=jsonb_build_object('nets',to_jsonb(nets),'scores',g.scores,'resigned',p_resign,'prize_game',v_pg) where id=p_game;
 if g.table_id is not null then
   update public.trix_tables set updated_at=now() where id=g.table_id;
 end if;
end$function$;

-- إنشاء مباراة بنمط (كلاسيك/كومبلكس). trix_create القديمة تبقى للتوافق.
create or replace function private.trix_create2(p_mode text, p_variant text, p_seats uuid[], p_stake bigint, p_room uuid, p_escrow_taken jsonb default null, p_table uuid default null)
returns uuid language plpgsql security definer set search_path to 'public' as $function$
declare v_id uuid:=gen_random_uuid(); u uuid; esc jsonb:='{}';
begin
 if p_variant not in ('classic','complex') then raise exception 'INVALID_VARIANT'; end if;
 insert into public.trix_games(id,mode,variant,seats,stake,room_id,remaining,table_id)
 values(v_id,p_mode,p_variant,p_seats,p_stake,p_room,private.trix_contracts(p_variant),p_table);
 if p_escrow_taken is not null then
   esc := p_escrow_taken;
 else
   foreach u in array p_seats loop
    if u is not null and p_stake>0 and not public._is_platform_owner(u) then
     perform private.trix_wallet(u,-p_stake,'trix_stake',v_id::text);
     esc:=esc||jsonb_build_object(u::text,p_stake);
    end if;
   end loop;
 end if;
 update public.trix_games set escrow=esc where id=v_id;
 perform private.trix_deal(v_id);
 return v_id;
end$function$;

create or replace function private.trix_create(p_mode text, p_seats uuid[], p_stake bigint, p_room uuid)
returns uuid language sql security definer set search_path to 'public' as $$
  select private.trix_create2(p_mode,'classic',p_seats,p_stake,p_room,null,null) $$;

create or replace function private.trix_user_busy(p_uid uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists(select 1 from public.trix_games where status='active' and p_uid=any(seats))
      or exists(select 1 from public.trix_tables where status='open' and (p_uid=any(seats) or host=p_uid)) $$;

-- ضد الكمبيوتر بنمط اللعب (اسم جديد حتى لا يتعارض مع توقيع الإصدارات القديمة).
create or replace function public.trix_start_game(p_mode text, p_variant text default 'classic', p_stake bigint default 0, p_room_id uuid default null)
returns uuid language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); bal bigint;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_mode not in ('solo','partner') then raise exception 'INVALID_GAME'; end if;
 if p_stake not in (0,10,50,100,500,1000) then raise exception 'INVALID_STAKE'; end if;
 perform public.trix_my_active();
 if private.trix_user_busy(v) then raise exception 'ALREADY_IN_GAME'; end if;
 if p_stake>0 and not public._is_platform_owner(v) then
  select balance into bal from public.points_wallets where user_id=v;
  if coalesce(bal,0)<p_stake then raise exception 'INSUFFICIENT_POINTS'; end if;
 end if;
 return private.trix_create2(p_mode,p_variant,array[v,null,null,null]::uuid[],p_stake,p_room_id,null,null);
end$function$;

-- ════════════════════ الطاولات (4 لاعبين حقيقيين) ════════════════════

create or replace function private.trix_table_refund(p_table uuid, p_uid uuid)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare t public.trix_tables; amt bigint;
begin
 select * into t from public.trix_tables where id=p_table for update;
 amt := coalesce((t.escrow->>p_uid::text)::bigint,0);
 if amt>0 then
   perform private.trix_wallet(p_uid, amt, 'trix_refund', p_table::text);
   update public.trix_tables set escrow = escrow - p_uid::text where id=p_table;
 end if;
end$function$;

create or replace function private.trix_table_seat_user(p_table uuid, p_uid uuid, p_seat int)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare t public.trix_tables; bal bigint;
begin
 select * into t from public.trix_tables where id=p_table for update;
 if not found or t.status<>'open' then raise exception 'TABLE_NOT_OPEN'; end if;
 if t.expires_at < now() then raise exception 'TABLE_EXPIRED'; end if;
 if p_seat<1 or p_seat>3 or t.seats[p_seat+1] is not null then raise exception 'SEAT_TAKEN'; end if;
 if p_uid = any(t.seats) then raise exception 'ALREADY_SEATED'; end if;
 if private.trix_user_busy(p_uid) then raise exception 'ALREADY_IN_GAME'; end if;
 if public._users_blocked(t.host, p_uid) then raise exception 'BLOCKED'; end if;
 if t.stake>0 and not public._is_platform_owner(p_uid) then
   select balance into bal from public.points_wallets where user_id=p_uid;
   if coalesce(bal,0)<t.stake then raise exception 'INSUFFICIENT_POINTS'; end if;
   perform private.trix_wallet(p_uid,-t.stake,'trix_stake',p_table::text);
   update public.trix_tables set escrow = escrow || jsonb_build_object(p_uid::text, t.stake) where id=p_table;
 end if;
 update public.trix_tables set seats[p_seat+1]=p_uid, updated_at=now(), expires_at=greatest(expires_at, now()+interval '10 minutes') where id=p_table;
end$function$;

create or replace function public.trix_table_create(p_mode text, p_variant text default 'classic', p_stake bigint default 0, p_room_id uuid default null)
returns uuid language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); bal bigint; tid uuid;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_mode not in ('solo','partner') then raise exception 'INVALID_GAME'; end if;
 if p_variant not in ('classic','complex') then raise exception 'INVALID_VARIANT'; end if;
 if p_stake not in (0,10,50,100,500,1000) then raise exception 'INVALID_STAKE'; end if;
 perform public.trix_my_active();
 if private.trix_user_busy(v) then raise exception 'ALREADY_IN_GAME'; end if;
 insert into public.trix_tables(host,mode,variant,stake,room_id,seats) values(v,p_mode,p_variant,p_stake,p_room_id,array[v,null,null,null]::uuid[])
 returning id into tid;
 if p_stake>0 and not public._is_platform_owner(v) then
   select balance into bal from public.points_wallets where user_id=v;
   if coalesce(bal,0)<p_stake then raise exception 'INSUFFICIENT_POINTS'; end if;
   perform private.trix_wallet(v,-p_stake,'trix_stake',tid::text);
   update public.trix_tables set escrow=jsonb_build_object(v::text,p_stake) where id=tid;
 end if;
 return tid;
end$function$;

create or replace function public.trix_table_view(p_table uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); t public.trix_tables; names jsonb:='[]'; i int; nm text; inv jsonb;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into t from public.trix_tables where id=p_table;
 if not found then raise exception 'TABLE_NOT_FOUND'; end if;
 for i in 0..3 loop
  if t.seats[i+1] is null then nm:=null;
  else select coalesce(nullif(trim(display_name),''),nullif(trim(username),''),'عضو') into nm from public.profiles where id=t.seats[i+1]; end if;
  names:=names||to_jsonb(nm);
 end loop;
 select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'seat',x.seat,'to_uid',x.to_uid,
   'name',coalesce(nullif(trim(p.display_name),''),nullif(trim(p.username),''),'عضو')) order by x.seat),'[]')
   into inv from public.trix_table_invites x join public.profiles p on p.id=x.to_uid
  where x.table_id=p_table and x.status='pending' and x.created_at>now()-interval '10 minutes';
 return jsonb_build_object('id',t.id,'host',t.host,'is_host',t.host=v,'mode',t.mode,'variant',t.variant,'stake',t.stake,
   'room_id',t.room_id,'seats',to_jsonb(t.seats),'names',names,'status',t.status,'game_id',t.game_id,
   'my_seat',array_position(t.seats,v)-1,'invites',inv,'expires_at',t.expires_at,'server_now',now());
end$function$;

create or replace function public.trix_table_invite(p_table uuid, p_to uuid, p_seat int)
returns uuid language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); t public.trix_tables; iid uuid; nm text;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into t from public.trix_tables where id=p_table for update;
 if not found or t.host<>v then raise exception 'NOT_HOST'; end if;
 if t.status<>'open' then raise exception 'TABLE_NOT_OPEN'; end if;
 if p_to=v then raise exception 'INVALID_RECIPIENT'; end if;
 if p_seat<1 or p_seat>3 or t.seats[p_seat+1] is not null then raise exception 'SEAT_TAKEN'; end if;
 if public._users_blocked(v,p_to) then raise exception 'BLOCKED'; end if;
 update public.trix_table_invites set status='cancelled', updated_at=now()
  where table_id=p_table and status='pending' and (seat=p_seat or to_uid=p_to);
 insert into public.trix_table_invites(table_id,from_uid,to_uid,seat) values(p_table,v,p_to,p_seat) returning id into iid;
 select coalesce(nullif(trim(display_name),''),nullif(trim(username),''),'عضو') into nm from public.profiles where id=v;
 insert into public.notifications(uid,type,title,body,related_id,actor_uid,is_read,created_at)
 values(p_to,'system','🃏 دعوة تركس',coalesce(nm,'عضو')||' يدعوك إلى طاولة تركس '||case t.mode when 'partner' then '(شراكة 2×2)' else '(فردي)' end
   ||case when p_seat=2 and t.mode='partner' then ' — شريكًا له' else ' — خصمًا' end
   ||case when t.stake>0 then ' على '||t.stake||' نقطة' else '' end, iid::text, v, false, now());
 return iid;
end$function$;

create or replace function public.trix_my_table_invites()
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid();
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 update public.trix_table_invites set status='expired', updated_at=now() where to_uid=v and status='pending' and created_at<now()-interval '10 minutes';
 return coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'table_id',x.table_id,'seat',x.seat,'mode',t.mode,'variant',t.variant,'stake',t.stake,
   'from_name',coalesce(nullif(trim(p.display_name),''),nullif(trim(p.username),''),'عضو'),'created_at',x.created_at) order by x.created_at desc)
   from public.trix_table_invites x join public.trix_tables t on t.id=x.table_id join public.profiles p on p.id=x.from_uid
  where x.to_uid=v and x.status='pending' and t.status='open'),'[]');
end$function$;

create or replace function public.trix_table_respond(p_invite uuid, p_accept boolean)
returns uuid language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); x public.trix_table_invites;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into x from public.trix_table_invites where id=p_invite for update;
 if not found or x.to_uid<>v then raise exception 'REQUEST_NOT_FOUND'; end if;
 if x.status<>'pending' then raise exception 'REQUEST_NOT_PENDING'; end if;
 if x.created_at<now()-interval '10 minutes' then
   update public.trix_table_invites set status='expired', updated_at=now() where id=p_invite;
   raise exception 'REQUEST_EXPIRED';
 end if;
 if not p_accept then
   update public.trix_table_invites set status='declined', updated_at=now() where id=p_invite;
   insert into public.notifications(uid,type,title,body,related_id,actor_uid,is_read,created_at)
   values(x.from_uid,'system','🃏 دعوة تركس','تم رفض دعوتك للطاولة',x.table_id::text,v,false,now());
   return null;
 end if;
 perform public.trix_my_active();
 perform private.trix_table_seat_user(x.table_id, v, x.seat);
 update public.trix_table_invites set status='accepted', updated_at=now() where id=p_invite;
 return x.table_id;
end$function$;

create or replace function public.trix_table_join(p_table uuid, p_seat int)
returns uuid language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid();
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 perform public.trix_my_active();
 perform private.trix_table_seat_user(p_table, v, p_seat);
 update public.trix_table_invites set status='accepted', updated_at=now() where table_id=p_table and to_uid=v and status='pending';
 return p_table;
end$function$;

create or replace function public.trix_table_leave(p_table uuid)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); t public.trix_tables; u uuid; i int;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into t from public.trix_tables where id=p_table for update;
 if not found or t.status<>'open' then return; end if;
 if t.host=v then
   foreach u in array t.seats loop
     if u is not null then perform private.trix_table_refund(p_table,u); end if;
   end loop;
   update public.trix_tables set status='cancelled', updated_at=now() where id=p_table;
   update public.trix_table_invites set status='cancelled', updated_at=now() where table_id=p_table and status='pending';
   for i in 2..4 loop
     if t.seats[i] is not null then
       insert into public.notifications(uid,type,title,body,related_id,actor_uid,is_read,created_at)
       values(t.seats[i],'system','🃏 طاولة تركس','ألغى المضيف الطاولة واسترددت رهانك',p_table::text,v,false,now());
     end if;
   end loop;
 elsif v = any(t.seats) then
   perform private.trix_table_refund(p_table,v);
   update public.trix_tables set seats[array_position(t.seats,v)]=null, updated_at=now() where id=p_table;
 end if;
end$function$;

create or replace function public.trix_table_start(p_table uuid)
returns uuid language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); t public.trix_tables; gid uuid; u uuid; i int;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into t from public.trix_tables where id=p_table for update;
 if not found or t.host<>v then raise exception 'NOT_HOST'; end if;
 if t.status<>'open' then raise exception 'TABLE_NOT_OPEN'; end if;
 gid := private.trix_create2(t.mode, t.variant, t.seats, t.stake, t.room_id, t.escrow, p_table);
 update public.trix_tables set status='started', game_id=gid, escrow='{}', updated_at=now() where id=p_table;
 update public.trix_table_invites set status='cancelled', updated_at=now() where table_id=p_table and status='pending';
 for i in 2..4 loop
   u := t.seats[i];
   if u is not null then
     insert into public.notifications(uid,type,title,body,related_id,actor_uid,is_read,created_at)
     values(u,'system','🃏 بدأت مباراة التركس','ادخل الطاولة الآن',gid::text,v,false,now());
   end if;
 end loop;
 return gid;
end$function$;

create or replace function public.trix_open_tables(p_room_id uuid default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid();
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 return coalesce((select jsonb_agg(public.trix_table_view(q.id) order by q.created_at desc)
   from (select t.id, t.created_at from public.trix_tables t
          where t.status='open' and t.expires_at>now()
            and (p_room_id is null or t.room_id=p_room_id)
            and not public._users_blocked(t.host, v)
          order by t.created_at desc limit 20) q),'[]');
end$function$;

create or replace function public.trix_my_table()
returns uuid language sql security definer set search_path to 'public' as $$
  select id from public.trix_tables where status='open' and (auth.uid()=any(seats) or host=auth.uid()) order by created_at desc limit 1 $$;

-- ════════════════════ تصميم الورق ════════════════════

create or replace function public.get_card_faces()
returns jsonb language sql stable set search_path to 'public' as $$
 select '[{"key":"classic","name":"كلاسيكي"},{"key":"jumbo","name":"أرقام كبيرة"},{"key":"four_color","name":"أربعة ألوان"},{"key":"royal_gold","name":"ذهبي ملكي"},{"key":"neon","name":"نيون ليلي"}]'::jsonb $$;

create or replace function public.get_my_card_face()
returns text language sql stable security definer set search_path to 'public' as $$
 select coalesce((select face_key from public.user_card_face where user_id=auth.uid()),'classic') $$;

create or replace function public.set_my_card_face(p_key text)
returns void language plpgsql security definer set search_path to 'public' as $function$
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_key not in ('classic','jumbo','four_color','royal_gold','neon') then raise exception 'INVALID_FACE'; end if;
 insert into public.user_card_face(user_id,face_key) values(auth.uid(),p_key)
 on conflict (user_id) do update set face_key=excluded.face_key, updated_at=now();
end$function$;

-- ════════════════════ صيانة دورية ════════════════════
create or replace function private.trix_maintenance()
returns void language plpgsql security definer set search_path to 'public' as $function$
declare t record; u uuid; g record;
begin
 for t in select * from public.trix_tables where status='open' and expires_at<now() loop
   foreach u in array t.seats loop
     if u is not null then perform private.trix_table_refund(t.id,u); end if;
   end loop;
   update public.trix_tables set status='cancelled', updated_at=now() where id=t.id;
   update public.trix_table_invites set status='expired', updated_at=now() where table_id=t.id and status='pending';
 end loop;
 update public.trix_table_invites set status='expired', updated_at=now() where status='pending' and created_at<now()-interval '10 minutes';
 for g in select id, turn, seats from public.trix_games where status='active' and updated_at<now()-interval '30 minutes' loop
   perform private.trix_settle(g.id, case when g.turn>=0 and g.seats[g.turn+1] is not null then g.turn else null end);
 end loop;
end$function$;
revoke all on function private.trix_maintenance() from public, anon, authenticated;
select cron.schedule('trix_maintenance', '* * * * *', 'select private.trix_maintenance();');

-- صلاحيات الدوال العامة الجديدة
do $$
declare f text;
begin
 foreach f in array array[
   'public.trix_double(uuid,text[])','public.trix_start_game(text,text,bigint,uuid)',
   'public.trix_table_create(text,text,bigint,uuid)','public.trix_table_view(uuid)','public.trix_table_invite(uuid,uuid,integer)',
   'public.trix_my_table_invites()','public.trix_table_respond(uuid,boolean)','public.trix_table_join(uuid,integer)',
   'public.trix_table_leave(uuid)','public.trix_table_start(uuid)','public.trix_open_tables(uuid)','public.trix_my_table()',
   'public.get_card_faces()','public.get_my_card_face()','public.set_my_card_face(text)'] loop
   execute format('revoke all on function %s from anon', f);
   execute format('grant execute on function %s to authenticated', f);
 end loop;
end $$;
