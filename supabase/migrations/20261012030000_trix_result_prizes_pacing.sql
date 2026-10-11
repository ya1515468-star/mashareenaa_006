-- تركس: الجائزة الفعلية لكل مقعد في نتيجة المباراة (لعرضها في شاشة النهاية)
-- + إيقاع أوضح بعد اكتمال كل أكلة.
create or replace function private.trix_settle(p_game uuid, p_resign integer default null)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare g public.trix_games; sc int[]; nets bigint[]:=array[0,0,0,0]; S bigint; i int; j int; pos int; t int; vals bigint[]; tot bigint;
 t0 int; t1 int; uid uuid; esc bigint; pay bigint; txt text; humans int; v_won boolean; v_kind text; v_prize bigint; v_pg text; v_gems bigint; prizes jsonb:='[null,null,null,null]'::jsonb; v_pp bigint; v_pgm bigint;
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
  v_pp:=0; v_pgm:=0;
  if v_won and p_resign is null then
    v_prize:=private.award_game_prize(uid,v_pg,p_game::text);
    -- الجائزة الفعلية من السجل (قد تُصفَّر الجواهر بالحد اليومي أو الأهلية).
    select coalesce(amount,0), coalesce(gems,0) into v_pp, v_pgm from public.game_prize_log
      where user_id=uid and game=v_pg and ref=p_game::text;
    v_pp:=coalesce(v_pp,0); v_pgm:=coalesce(v_pgm,0);
    if v_pp>0 or v_pgm>0 then
      prizes:=jsonb_set(prizes,array[i::text],jsonb_build_object('points',v_pp,'gems',v_pgm));
    end if;
  end if;
  perform private.game_notify(uid,v_kind,txt||case when v_pp>0 or v_pgm>0 then ' — 🎁 جائزة'||case when v_pp>0 then ' +'||v_pp||' نقطة' else '' end||case when v_pgm>0 then ' +'||v_pgm||' 💎' else '' end else '' end,p_game::text,uid);
 end loop;
 update public.trix_games set status='finished', phase='done', turn=-1, settled=true, updated_at=now(), seq=seq+1,
   result=jsonb_build_object('nets',to_jsonb(nets),'scores',g.scores,'resigned',p_resign,'prize_game',v_pg,'prizes',prizes) where id=p_game;
 if g.table_id is not null then
   update public.trix_tables set updated_at=now() where id=g.table_id;
 end if;
end$function$;

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
 -- إيقاع اللعب: 450ms بين الأوراق، و1100ms بعد اكتمال أكلة حتى تُرى حركة
 -- جمع الأوراق والتأثيرات على كل الأجهزة قبل أن يفتح الكمبيوتر الأكلة التالية.
 if g.updated_at>now()-(case when g.phase='play' and jsonb_array_length(g.trick)=0 and coalesce(g.last_trick ? 'n',false)
      then interval '1100 milliseconds' else interval '450 milliseconds' end) then return false; end if;
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
