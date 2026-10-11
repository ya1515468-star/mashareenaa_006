-- اختبار جاف لألعاب الكمبيوتر وجوائز مباريات اللاعبين (يُلغى كل شيء بالاستثناء الأخير).
do $$
declare u uuid:='7ebf9aa4-6e38-4a64-ac52-b083b05f1ddd'; u2 uuid; r jsonb; mid uuid; i int; col int; res jsonb:='[]';
 c4w int:=0; c4l int:=0; c4d int:=0; moves int; t0 timestamptz; ms numeric; maxms numeric:=0; rpsw int:=0; rpsl int:=0;
 coinw int:=0; dicew int:=0; diced int:=0; prizes int; m public.game_matches; bad int:=0; b int[]; n1 int; n2 int;
begin
 perform set_config('request.jwt.claims', json_build_object('sub',u,'role','authenticated')::text, true);
 -- ① 10 مباريات أربعة في صف بحركات عشوائية قانونية؛ تحقق من سلامة اللوحة.
 for i in 1..10 loop
   r:=public.game_bot_start('connect4'); mid:=(r->>'id')::uuid; moves:=0;
   while r->>'status'='active' and moves<30 loop
     select array_agg(x::int order by o) into b from jsonb_array_elements_text(r->'state'->'board') with ordinality t(x,o);
     loop col:=floor(random()*7)::int; exit when b[col+1]=0; end loop;
     t0:=clock_timestamp();
     r:=public.game_bot_c4(mid,col);
     ms:=extract(epoch from clock_timestamp()-t0)*1000; if ms>maxms then maxms:=ms; end if;
     moves:=moves+1;
   end loop;
   select count(*) filter (where x::int=1), count(*) filter (where x::int=2) into n1,n2 from jsonb_array_elements_text(r->'state'->'board') x;
   if not (n1=n2 or n1=n2+1) then bad:=bad+1; end if;
   if r->>'result'='win' then c4w:=c4w+1; elsif r->>'result'='lose' then c4l:=c4l+1; else c4d:=c4d+1; end if;
 end loop;
 -- ② 10 مباريات حجر ورقة مقص
 for i in 1..10 loop
   r:=public.game_bot_start('rps'); mid:=(r->>'id')::uuid;
   while r->>'status'='active' loop r:=public.game_bot_rps(mid,(array['rock','paper','scissors'])[1+floor(random()*3)::int]); end loop;
   if r->>'result'='win' then rpsw:=rpsw+1; else rpsl:=rpsl+1; end if;
 end loop;
 -- ③ عملة ونرد
 for i in 1..20 loop r:=public.game_bot_start('coin','heads'); if r->>'result'='win' then coinw:=coinw+1; end if; end loop;
 for i in 1..20 loop r:=public.game_bot_start('dice'); if r->>'result'='win' then dicew:=dicew+1; elsif r->>'result'='draw' then diced:=diced+1; end if; end loop;
 select count(*) into prizes from public.game_prize_log where user_id=u and created_at>now()-interval '1 minute' and game like '%_bot';
 res:=res||jsonb_build_array(jsonb_build_object('c4',jsonb_build_array(c4w,c4l,c4d),'c4_bad_boards',bad,'c4_max_ms',round(maxms),
   'rps',jsonb_build_array(rpsw,rpsl),'coin_wins_of_20',coinw,'dice_w_d_of_20',jsonb_build_array(dicew,diced),'bot_prize_rows',prizes,
   'sample_finished',(select to_jsonb(x) from public.game_bot_matches x where user_id=u and prize is not null order by updated_at desc limit 1)));
 -- ④ الكمبيوتر يصدّ فوزًا مباشرًا ويفوز عند الإمكان
 res:=res||jsonb_build_array(jsonb_build_object(
   'blocks', private.c4_bot_move(array[0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 1,1,1,0,2,2,0]::int[],2),
   'wins_col6_over_block3', private.c4_bot_move(array[0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0,0,0,0,0,0,2, 1,0,0,0,0,0,2, 1,1,1,0,0,0,2]::int[],2)));
 -- ⑤ مباراة لاعبين: فوز طبيعي → state.prize ؛ استسلام → بلا جائزة
 select id into u2 from public.profiles where id<>u order by id limit 1;
 insert into public.game_matches(game_type,p1,p2,state,turn,status,stake_points) values('connect4',u,u2,'{"board":[]}',u,'active',0) returning * into m;
 update public.game_matches set status='finished', winner=u where id=m.id;
 select * into m from public.game_matches where id=m.id;
 res:=res||jsonb_build_array(jsonb_build_object('normal_win_state_prize',m.state->'prize','settled',m.settled));
 insert into public.game_matches(game_type,p1,p2,state,turn,status,stake_points) values('rps',u,u2,'{}',null,'active',0) returning * into m;
 perform set_config('request.jwt.claims', json_build_object('sub',u2,'role','authenticated')::text, true);
 perform public.resign_game_match(m.id);
 select * into m from public.game_matches where id=m.id;
 res:=res||jsonb_build_array(jsonb_build_object('resign_winner_is_u',m.winner=u,'resign_prize',m.state->'prize',
   'resign_prize_rows',(select count(*) from public.game_prize_log where ref=m.id::text)));
 raise exception 'DRYRUN_RESULT %', res::text;
end $$;
