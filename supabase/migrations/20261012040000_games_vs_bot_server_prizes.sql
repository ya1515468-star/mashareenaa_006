-- الألعاب المصغّرة حقيقية من الخادم:
-- ① ضد الكمبيوتر (أربعة في صف، حجر ورقة مقص، العملة، النرد): الحركات والذكاء
--    والعشوائية والنتيجة والجائزة كلها في الخادم (game_bot_matches).
-- ② ضد لاعب: جوائز سخية (نقاط + جواهر)، بلا جائزة عند الاستسلام (منع التواطؤ)،
--    والجائزة الفعلية تُكتب في state.prize لعرضها في شاشة النتيجة.

-- ───── الجوائز ─────
insert into public.game_prizes(game, amount, gems) values
  ('connect4', 80, 1), ('rps', 50, 1), ('coin', 25, 0), ('dice', 25, 0),
  ('connect4_bot', 40, 0), ('rps_bot', 20, 0), ('coin_bot', 10, 0), ('dice_bot', 10, 0)
on conflict (game) do update set amount = excluded.amount, gems = excluded.gems;

-- ───── حدود الجوائز: 20 يوميًا لمباريات الكمبيوتر و20 منفصلة لمباريات اللاعبين
-- (فلا تستهلك رميات العملة حصة جوائز التركس)، و5 جوائز جواهر يوميًا. ─────
create or replace function private.award_game_prize(p_uid uuid, p_game text, p_ref text)
returns bigint language plpgsql security definer set search_path to 'public' as $function$
declare amt bigint; gm bigint; n int; ng int; b bigint; is_bot boolean := p_game like '%\_bot';
begin
 if p_uid is null then return 0; end if;
 if not private.game_prize_eligible(p_uid) then return 0; end if;
 select amount, gems into amt, gm from public.game_prizes where game=p_game;
 if coalesce(amt,0)<=0 and coalesce(gm,0)<=0 then return 0; end if;
 perform pg_advisory_xact_lock(hashtext('prize'||p_uid::text));
 select count(*) filter (where (game like '%\_bot') = is_bot), count(*) filter (where gems>0) into n, ng
   from public.game_prize_log where user_id=p_uid and created_at>now()-interval '24 hours';
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

-- ───── جدول مباريات الكمبيوتر ─────
create table if not exists public.game_bot_matches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  game_type text not null check (game_type in ('connect4','rps','coin','dice')),
  state jsonb not null default '{}'::jsonb,
  status text not null default 'active' check (status in ('active','finished')),
  result text check (result in ('win','lose','draw')),
  prize jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists game_bot_matches_user_idx on public.game_bot_matches(user_id, created_at desc);
alter table public.game_bot_matches enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='game_bot_matches' and policyname='game_bot_matches_own') then
    create policy game_bot_matches_own on public.game_bot_matches for select to authenticated using (user_id = auth.uid());
  end if;
end $$;
revoke all on public.game_bot_matches from anon, authenticated;
grant select on public.game_bot_matches to authenticated;

-- ───── أدوات أربعة في صف ─────
create or replace function private.c4_drop(b int[], p_col int)
returns int language plpgsql immutable as $function$
declare r int;
begin
 if p_col < 0 or p_col > 6 then return -1; end if;
 for r in reverse 5..0 loop
   if b[r*7+p_col+1] = 0 then return r*7+p_col; end if;
 end loop;
 return -1;
end$function$;

create or replace function private.c4_win(b int[], idx int, me int)
returns int[] language plpgsql immutable as $function$
declare dr int[]:=array[0,1,1,1]; dc int[]:=array[1,0,1,-1]; d int; k int; rr int; cc int; nr int; nc int; cells int[];
begin
 rr:=idx/7; cc:=idx%7;
 for d in 1..4 loop
   cells:=array[idx];
   for k in 1..3 loop
     nr:=rr+k*dr[d]; nc:=cc+k*dc[d];
     if nr between 0 and 5 and nc between 0 and 6 and b[nr*7+nc+1]=me then cells:=cells||(nr*7+nc); else exit; end if;
   end loop;
   for k in 1..3 loop
     nr:=rr-k*dr[d]; nc:=cc-k*dc[d];
     if nr between 0 and 5 and nc between 0 and 6 and b[nr*7+nc+1]=me then cells:=cells||(nr*7+nc); else exit; end if;
   end loop;
   if array_length(cells,1)>=4 then return cells; end if;
 end loop;
 return null;
end$function$;

create or replace function private.c4_score(b int[], me int)
returns int language plpgsql immutable as $function$
declare o int:=3-me; s int:=0; r int; c int; d int; k int; v int; mine int; theirs int; empty int; er int; ec int;
 dr int[]:=array[0,1,1,1]; dc int[]:=array[1,0,1,-1];
begin
 for r in 0..5 loop
   if b[r*7+3+1]=me then s:=s+3; elsif b[r*7+3+1]=o then s:=s-3; end if;
 end loop;
 for r in 0..5 loop
  for c in 0..6 loop
   for d in 1..4 loop
     er:=r+3*dr[d]; ec:=c+3*dc[d];
     continue when er<0 or er>5 or ec<0 or ec>6;
     mine:=0; theirs:=0; empty:=0;
     for k in 0..3 loop
       v:=b[(r+k*dr[d])*7+c+k*dc[d]+1];
       if v=me then mine:=mine+1; elsif v=o then theirs:=theirs+1; else empty:=empty+1; end if;
     end loop;
     if mine=3 and empty=1 then s:=s+6; end if;
     if mine=2 and empty=2 then s:=s+2; end if;
     if theirs=3 and empty=1 then s:=s-5; end if;
   end loop;
  end loop;
 end loop;
 return s;
end$function$;

-- الكمبيوتر: يفوز إن أمكن، يصدّ فوز الخصم، يتجنّب منح الخصم فوزًا فوريًا،
-- ثم يختار بالتقييم مع هامش عشوائي صغير (قويّ لكن قابل للهزيمة).
create or replace function private.c4_bot_move(b int[], bot int)
returns int language plpgsql volatile as $function$
declare o int:=3-bot; col int; idx int; idx2 int; b2 int[]; b3 int[]; best int:=-1; best_s numeric:=-1e9; s numeric;
 ord int[]:=array[3,2,4,1,5,0,6];
begin
 foreach col in array ord loop
   idx:=private.c4_drop(b,col); continue when idx<0;
   b2:=b; b2[idx+1]:=bot;
   if private.c4_win(b2,idx,bot) is not null then return col; end if;
 end loop;
 foreach col in array ord loop
   idx:=private.c4_drop(b,col); continue when idx<0;
   b2:=b; b2[idx+1]:=o;
   if private.c4_win(b2,idx,o) is not null then return col; end if;
 end loop;
 foreach col in array ord loop
   idx:=private.c4_drop(b,col); continue when idx<0;
   b2:=b; b2[idx+1]:=bot;
   s:=private.c4_score(b2,bot) + random()*4;
   idx2:=private.c4_drop(b2,col);
   if idx2>=0 then
     b3:=b2; b3[idx2+1]:=o;
     if private.c4_win(b3,idx2,o) is not null then s:=s-1000; end if;
   end if;
   if s>best_s then best_s:=s; best:=col; end if;
 end loop;
 return best;
end$function$;

-- ───── إنهاء مباراة كمبيوتر + الجائزة الفعلية ─────
create or replace function private.gb_finish(p_id uuid, p_result text, p_state jsonb)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare m public.game_bot_matches; pts bigint; gm bigint; pz jsonb:=null;
begin
 select * into m from public.game_bot_matches where id=p_id for update;
 if m.status='finished' then return; end if;
 if p_result='win' then
   perform private.award_game_prize(m.user_id, m.game_type||'_bot', m.id::text);
   select coalesce(amount,0), coalesce(gems,0) into pts, gm from public.game_prize_log
     where user_id=m.user_id and game=m.game_type||'_bot' and ref=m.id::text;
   if coalesce(pts,0)>0 or coalesce(gm,0)>0 then pz:=jsonb_build_object('points',coalesce(pts,0),'gems',coalesce(gm,0)); end if;
 end if;
 update public.game_bot_matches set state=p_state, status='finished', result=p_result, prize=pz, updated_at=now() where id=p_id;
end$function$;

-- ───── بدء مباراة ضد الكمبيوتر ─────
create or replace function public.game_bot_start(p_game text, p_pick text default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); st jsonb; v_id uuid; side text; a int; b int; c int; d int; res text;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_game not in ('connect4','rps','coin','dice') then raise exception 'INVALID_GAME'; end if;
 if (select count(*) from public.game_bot_matches where user_id=v and created_at>now()-interval '1 day') >= 300 then
   raise exception 'RATE_LIMIT';
 end if;
 -- مباراة سابقة غير مكتملة من النوع نفسه تُغلق بلا جائزة.
 update public.game_bot_matches set status='finished', result='lose', updated_at=now()
  where user_id=v and game_type=p_game and status='active';
 if p_game='connect4' then
   st:=jsonb_build_object('board',(select jsonb_agg(0) from generate_series(1,42)),'last',null,'bot_last',null,'win_cells','[]'::jsonb,'moves',0);
 elsif p_game='rps' then
   st:=jsonb_build_object('scores',jsonb_build_array(0,0),'round',1,'last',null);
 elsif p_game='coin' then
   if coalesce(p_pick,'') not in ('heads','tails') then raise exception 'INVALID_MOVE'; end if;
   side:=case when random()<0.5 then 'heads' else 'tails' end;
   st:=jsonb_build_object('pick',p_pick,'side',side);
   res:=case when side=p_pick then 'win' else 'lose' end;
 else
   a:=1+floor(random()*6)::int; b:=1+floor(random()*6)::int; c:=1+floor(random()*6)::int; d:=1+floor(random()*6)::int;
   st:=jsonb_build_object('me',jsonb_build_array(a,b),'bot',jsonb_build_array(c,d));
   res:=case when a+b>c+d then 'win' when a+b<c+d then 'lose' else 'draw' end;
 end if;
 insert into public.game_bot_matches(user_id,game_type,state) values(v,p_game,st) returning game_bot_matches.id into v_id;
 if res is not null then perform private.gb_finish(v_id,res,st); end if;
 return (select to_jsonb(m) from public.game_bot_matches m where m.id=v_id);
end$function$;

-- ───── حركة في أربعة في صف (اللاعب ثم الكمبيوتر في المعاملة نفسها) ─────
create or replace function public.game_bot_c4(p_match uuid, p_col int)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); m public.game_bot_matches; b int[]; idx int; bidx int:=null; col int; win int[]; st jsonb; mv int;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into m from public.game_bot_matches where id=p_match for update;
 if not found or m.user_id<>v or m.game_type<>'connect4' then raise exception 'MATCH_NOT_FOUND'; end if;
 if m.status<>'active' then raise exception 'MATCH_FINISHED'; end if;
 select array_agg(x::int order by o) into b from jsonb_array_elements_text(m.state->'board') with ordinality t(x,o);
 idx:=private.c4_drop(b,p_col);
 if idx<0 then raise exception 'COLUMN_FULL'; end if;
 b[idx+1]:=1;
 mv:=coalesce((m.state->>'moves')::int,0)+1;
 win:=private.c4_win(b,idx,1);
 if win is not null then
   st:=jsonb_build_object('board',to_jsonb(b),'last',idx,'bot_last',null,'win_cells',to_jsonb(win),'moves',mv);
   perform private.gb_finish(m.id,'win',st);
 elsif not (0 = any(b)) then
   st:=jsonb_build_object('board',to_jsonb(b),'last',idx,'bot_last',null,'win_cells','[]'::jsonb,'moves',mv);
   perform private.gb_finish(m.id,'draw',st);
 else
   col:=private.c4_bot_move(b,2);
   bidx:=private.c4_drop(b,col);
   b[bidx+1]:=2;
   win:=private.c4_win(b,bidx,2);
   st:=jsonb_build_object('board',to_jsonb(b),'last',idx,'bot_last',bidx,'win_cells',coalesce(to_jsonb(win),'[]'::jsonb),'moves',mv);
   if win is not null then perform private.gb_finish(m.id,'lose',st);
   elsif not (0 = any(b)) then perform private.gb_finish(m.id,'draw',st);
   else update public.game_bot_matches set state=st, updated_at=now() where id=m.id;
   end if;
 end if;
 return (select to_jsonb(x) from public.game_bot_matches x where x.id=p_match);
end$function$;

-- ───── جولة حجر ورقة مقص (الكمبيوتر يختار بعشوائية الخادم بعد اختيارك) ─────
create or replace function public.game_bot_rps(p_match uuid, p_choice text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v uuid:=auth.uid(); m public.game_bot_matches; bot text; r int; sc int[]; rnd int; st jsonb;
begin
 if v is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_choice not in ('rock','paper','scissors') then raise exception 'INVALID_MOVE'; end if;
 select * into m from public.game_bot_matches where id=p_match for update;
 if not found or m.user_id<>v or m.game_type<>'rps' then raise exception 'MATCH_NOT_FOUND'; end if;
 if m.status<>'active' then raise exception 'MATCH_FINISHED'; end if;
 bot:=(array['rock','paper','scissors'])[1+floor(random()*3)::int];
 r:=case when p_choice=bot then 0 when (p_choice='rock' and bot='scissors') or (p_choice='paper' and bot='rock') or (p_choice='scissors' and bot='paper') then 1 else 2 end;
 sc:=array[(m.state->'scores'->>0)::int,(m.state->'scores'->>1)::int];
 if r=1 then sc[1]:=sc[1]+1; elsif r=2 then sc[2]:=sc[2]+1; end if;
 rnd:=coalesce((m.state->>'round')::int,1);
 st:=jsonb_build_object('scores',to_jsonb(sc),'round',case when sc[1]>=2 or sc[2]>=2 then rnd else rnd+1 end,
   'last',jsonb_build_object('me',p_choice,'bot',bot,'res',r,'round',rnd));
 if sc[1]>=2 then perform private.gb_finish(m.id,'win',st);
 elsif sc[2]>=2 then perform private.gb_finish(m.id,'lose',st);
 else update public.game_bot_matches set state=st, updated_at=now() where id=m.id;
 end if;
 return (select to_jsonb(x) from public.game_bot_matches x where x.id=p_match);
end$function$;

-- ───── مباريات اللاعبين: لا جائزة على الاستسلام + نص الجائزة مع الجواهر ─────
create or replace function private.game_result_notify(p_a uuid, p_b uuid, p_winner uuid, p_game text, p_ref text, p_msg text)
returns bigint language plpgsql security definer set search_path to 'public' as $function$
declare prize bigint:=0; gm bigint:=0; resigned boolean:=false; txt text:='';
begin
 if p_ref ~ '^[0-9a-fA-F-]{36}$' then
   select coalesce((state->>'resigned')::boolean,false) into resigned from public.game_matches where id=p_ref::uuid;
 end if;
 if p_winner is not null and not coalesce(resigned,false) then
   perform private.award_game_prize(p_winner,p_game,p_ref);
   select amount, gems into prize, gm from public.game_prize_log where user_id=p_winner and game=p_game and ref=p_ref;
   prize:=coalesce(prize,0); gm:=coalesce(gm,0);
 end if;
 if prize>0 or gm>0 then
   txt:=' — 🎁 جائزة الخادم'||case when prize>0 then ' +'||prize||' نقطة' else '' end||case when gm>0 then ' +'||gm||' 💎' else '' end;
 end if;
 perform private.game_notify(p_a, case when p_winner is null then 'draw' when p_winner=p_a then 'win' else 'lose' end,
   p_msg||case when p_winner=p_a then txt else '' end, p_ref, p_b);
 perform private.game_notify(p_b, case when p_winner is null then 'draw' when p_winner=p_b then 'win' else 'lose' end,
   p_msg||case when p_winner=p_b then txt else '' end, p_ref, p_a);
 return prize;
end$function$;

create or replace function private.settle_game_match()
returns trigger language plpgsql security definer set search_path to 'public' as $function$
declare w uuid; l uuid; l_bal bigint; w_bal bigint; pay bigint:=0; win_amt bigint:=0; l_owner boolean; wn text; msg text; label text; v_prize jsonb:=null;
begin
 if new.status<>'finished' or new.settled then return new; end if;
 w:=new.winner; l:=case when w=new.p1 then new.p2 when w=new.p2 then new.p1 else null end;
 label:=case new.game_type when 'connect4' then 'أربعة في صف' when 'rps' then 'حجر ورقة مقص' else 'العملة' end;
 if w is not null and new.stake_points>0 then
   insert into public.points_wallets(user_id) values(w) on conflict (user_id) do nothing;
   insert into public.points_wallets(user_id) values(l) on conflict (user_id) do nothing;
   perform 1 from public.points_wallets where user_id in (w,l) order by user_id for update;
   select balance into w_bal from public.points_wallets where user_id=w;
   select balance into l_bal from public.points_wallets where user_id=l;
   l_owner:=public._is_platform_owner(l);
   pay:=case when l_owner then 0 else least(new.stake_points,l_bal) end;
   win_amt:=case when l_owner then new.stake_points else pay end;
   if win_amt>0 then
     update public.points_wallets set balance=balance+win_amt, lifetime_earned=lifetime_earned+win_amt, version=version+1, updated_at=now() where user_id=w;
     insert into public.wallet_transactions(user_id,currency,amount,balance_before,balance_after,transaction_type,reference_type,reference_id,idempotency_key,metadata,created_by)
     values(w,'points',win_amt,w_bal,w_bal+win_amt,'game_win','game_match',new.id::text,gen_random_uuid(),jsonb_build_object('game',new.game_type,'opponent',l),w);
   end if;
   if pay>0 then
     update public.points_wallets set balance=balance-pay, lifetime_spent=lifetime_spent+pay, version=version+1, updated_at=now() where user_id=l;
     insert into public.wallet_transactions(user_id,currency,amount,balance_before,balance_after,transaction_type,reference_type,reference_id,idempotency_key,metadata,created_by)
     values(l,'points',-pay,l_bal,l_bal-pay,'game_loss','game_match',new.id::text,gen_random_uuid(),jsonb_build_object('game',new.game_type,'opponent',w),l);
   end if;
 end if;
 select coalesce(nullif(trim(display_name),''),nullif(trim(username),''),'عضو') into wn from public.profiles where id=w;
 msg:=case when w is null then '🎮 '||label||': انتهت بالتعادل'
   when new.stake_points>0 then '🎮 '||label||': فاز '||coalesce(wn,'عضو')||' وربح '||new.stake_points||' نقطة'
   else '🎮 '||label||': فاز '||coalesce(wn,'عضو') end;
 perform private.game_result_notify(new.p1, new.p2, w, new.game_type, new.id::text, msg);
 if w is not null then
   select jsonb_build_object('uid',w,'points',coalesce(amount,0),'gems',coalesce(gems,0)) into v_prize
     from public.game_prize_log where user_id=w and game=new.game_type and ref=new.id::text;
 end if;
 if new.room_id is not null and exists(select 1 from public.chat_rooms rr where rr.id=new.room_id and rr.is_active) then
   insert into public.public_chat_messages(user_id,room_id,message,body,kind,metadata)
   values(new.p1,new.room_id,msg,msg,'system',jsonb_build_object('system_event','game_result','match_id',new.id));
 end if;
 update public.game_matches set settled=true,
   state=case when v_prize is not null then coalesce(state,'{}'::jsonb)||jsonb_build_object('prize',v_prize) else state end
 where id=new.id;
 return new;
end$function$;

revoke all on function public.game_bot_start(text, text) from public, anon;
revoke all on function public.game_bot_c4(uuid, int) from public, anon;
revoke all on function public.game_bot_rps(uuid, text) from public, anon;
grant execute on function public.game_bot_start(text, text) to authenticated;
grant execute on function public.game_bot_c4(uuid, int) to authenticated;
grant execute on function public.game_bot_rps(uuid, text) to authenticated;
revoke all on function private.gb_finish(uuid, text, jsonb) from public, anon, authenticated;
revoke all on function private.c4_bot_move(int[], int) from public, anon, authenticated;
