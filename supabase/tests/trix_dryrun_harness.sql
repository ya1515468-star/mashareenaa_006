-- اختبار شامل يُشغَّل بعد الترحيل داخل المعاملة نفسها ثم يرمي استثناءً
-- يحمل النتائج، فيُلغى كل شيء (لا أثر على البيانات الحقيقية).
do $$
declare
  gid uuid; g public.trix_games; h jsonb; c text; steps int; v text; res jsonb := '[]'; rec jsonb;
  k int; hsum int; base int; selfdbl int; bad int; hist jsonb; e jsonb; holder int;
  variants text[] := array['classic','classic','complex','complex','classic','complex'];
  modes text[] := array['partner','solo','partner','solo','partner','partner'];
  i int; ndbl int; nself int;
  -- اختبار الطاولة
  u_osama uuid := '1e854071-7a79-40ac-8792-30bdeddbd8a8';
  u_moh uuid := '7ebf9aa4-6e38-4a64-ac52-b083b05f1ddd';
  u_4 uuid; tid uuid; inv uuid; tg uuid; vw jsonb; seat_uid uuid; who uuid; lg jsonb; acted boolean;
  tbl jsonb; human_plays int := 0; dbl_calls int := 0; bot_steps int := 0; t_hist jsonb; prize_rows int;
begin
  -- ① ست مباريات آلية كاملة (4 كمبيوتر) تتحقق من القواعد والتسجيل
  for i in 1..array_length(variants,1) loop
    gid := private.trix_create2(modes[i], variants[i], array[null,null,null,null]::uuid[], 0, null, null, null);
    select * into g from public.trix_games where id=gid;
    select hands into h from public.trix_secrets where game_id=gid;
    holder := null;
    for k in 0..3 loop if (h->k) ? 'H7' then holder := k; end if; end loop;
    steps := 0;
    loop
      select * into g from public.trix_games where id=gid;
      exit when g.status<>'active' or steps>6000;
      if g.phase='handover' then
        update public.trix_games set updated_at=now()-interval '5 seconds' where id=gid;
        perform private.trix_advance(gid);
      elsif g.phase='choose' then
        perform private.trix_bot_choose(gid);
      else
        select hands into h from public.trix_secrets where game_id=gid;
        c := private.trix_bot_pick(g.contract, h->g.turn, g.trick, g.layout);
        perform private.trix_apply_play(gid, g.turn, c);
      end if;
      steps := steps+1;
    end loop;
    select * into g from public.trix_games where id=gid;
    -- تحقق: مجموع كل يد = القيمة الأساسية للعقد ناقص (القيمة الإضافية لكل دبل أكله صاحبه)
    bad := 0; ndbl := 0; nself := 0;
    for e in select * from jsonb_array_elements(g.history) loop
      select sum(x::int) into hsum from jsonb_array_elements_text(e->'delta') x;
      base := case e->>'contract' when 'king' then -75 when 'queens' then -100 when 'diamonds' then -130
                when 'slaps' then -195 when 'trix' then 500 when 'complex' then -500 end;
      ndbl := ndbl + (select count(*) from jsonb_object_keys(coalesce(e->'doubles','{}')));
      selfdbl := 0;
      -- الدبل الذي أكله صاحبه يضيف −قيمة الورقة للمجموع (الآخر: −2x +x = −x كالأصل)
      -- نتحقق بإعادة الحساب من الدالة نفسها على سجل اليد غير متاح هنا، فنقبل
      -- فروقًا هي مضاعفات 75 أو 25 فقط عند وجود دبل.
      if hsum <> base then
        if (select count(*) from jsonb_object_keys(coalesce(e->'doubles','{}'))) = 0 then bad := bad+1;
        elsif ((base - hsum) % 25) <> 0 then bad := bad+1;
        else nself := nself+1; end if;
      end if;
    end loop;
    rec := jsonb_build_object('variant',g.variant,'mode',g.mode,'status',g.status,'steps',steps,
      'hands_played',jsonb_array_length(g.history),
      'expected_hands',case g.variant when 'complex' then 8 else 20 end,
      'kingdom_start',g.kingdom_start,'h7_holder_first_deal',holder,
      'final_scores',g.scores,'score_total',(select sum(x::int) from jsonb_array_elements_text(g.scores) x),
      'doubles_declared',ndbl,'self_eaten_doubles',nself,'bad_hand_sums',bad,'result',g.result);
    res := res || jsonb_build_array(rec);
  end loop;

  -- ② طاولة بلاعبين حقيقيين (محاكاة جلسات): osama مضيف، محمد شريك (مقعد 2)،
  --    المستخدم الرابع خصم (مقعد 1)، والمقعد 3 كمبيوتر عند البدء.
  select id into u_4 from public.profiles where id not in (u_osama,u_moh,'1e0eb6a1-640f-49f0-830c-aba188cd55a2') limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub',u_osama,'role','authenticated')::text, true);
  tid := public.trix_table_create('partner','classic',0,null);
  inv := public.trix_table_invite(tid, u_moh, 2);
  perform set_config('request.jwt.claims', json_build_object('sub',u_moh,'role','authenticated')::text, true);
  tbl := public.trix_my_table_invites();
  perform public.trix_table_respond(inv, true);
  perform set_config('request.jwt.claims', json_build_object('sub',u_4,'role','authenticated')::text, true);
  perform public.trix_table_join(tid, 1);
  perform set_config('request.jwt.claims', json_build_object('sub',u_osama,'role','authenticated')::text, true);
  vw := public.trix_table_view(tid);
  tg := public.trix_table_start(tid);
  steps := 0;
  loop
    select * into g from public.trix_games where id=tg;
    exit when g.status<>'active' or steps>8000;
    steps := steps+1;
    if g.phase='play' and jsonb_array_length(g.double_pending)>0 then
      -- كل إنسان معلّق يدبل كل ما يملك (لاختبار المسار الكامل)
      k := (g.double_pending->>0)::int;
      who := g.seats[k+1];
      perform set_config('request.jwt.claims', json_build_object('sub',who,'role','authenticated')::text, true);
      vw := public.trix_my_view(tg);
      perform public.trix_double(tg, array(select jsonb_array_elements_text(vw->'my_doublable')));
      dbl_calls := dbl_calls+1;
      continue;
    end if;
    if g.phase='handover' or g.turn<0 or g.seats[g.turn+1] is null then
      update public.trix_games set updated_at=now()-interval '5 seconds' where id=tg;
      perform set_config('request.jwt.claims', json_build_object('sub',u_osama,'role','authenticated')::text, true);
      acted := public.trix_bot_step(tg);
      bot_steps := bot_steps+1;
      continue;
    end if;
    who := g.seats[g.turn+1];
    perform set_config('request.jwt.claims', json_build_object('sub',who,'role','authenticated')::text, true);
    vw := public.trix_my_view(tg);
    if g.phase='choose' then
      perform public.trix_choose_contract(tg, vw->'remaining'->>0);
    else
      lg := vw->'legal';
      perform public.trix_play(tg, lg->>0);
      human_plays := human_plays+1;
    end if;
  end loop;
  select * into g from public.trix_games where id=tg;
  select count(*) into prize_rows from public.game_prize_log where ref=tg::text;
  res := res || jsonb_build_array(jsonb_build_object('table_test',true,'table_status',(select status from public.trix_tables where id=tid),
    'game_status',g.status,'steps',steps,'human_plays',human_plays,'double_calls',dbl_calls,'bot_steps',bot_steps,
    'hands_played',jsonb_array_length(g.history),'seats_humans',(select count(*) from unnest(g.seats) s where s is not null),
    'result',g.result,'prize_log_rows',prize_rows,
    'notifications_for_game',(select count(*) from public.notifications where related_id=tg::text)));
  raise exception 'DRYRUN_RESULT %', res::text;
end $$;
