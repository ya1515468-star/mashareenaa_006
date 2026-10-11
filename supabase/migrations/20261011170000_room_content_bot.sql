-- بوت المحتوى في الغرف: ينشر تلقائيًا في كل غرفة نشطة (بما فيها أي غرفة
-- تُنشأ لاحقًا) معلومة عن الخياطة/أذكار/أسرار المهنة/الحياة/تجارب/التجارة.
-- الجدولة خادمية بالكامل عبر pg_cron (كل دقيقة يُفحص)، والفاصل الفعلي بين
-- منشورين في الغرفة نفسها يحدده المالك (افتراضي 3 دقائق، أدنى 1).
-- لا يُنشر في غرفة آخر رسالة فيها منشور للبوت نفسه، حتى لا يملأ غرفة
-- خاملة فيدفع رسائل الأعضاء خارج نافذة آخر 150 رسالة.

create table if not exists public.room_content_bot_settings (
  id smallint primary key default 1 check (id = 1),
  enabled boolean not null default true,
  interval_minutes integer not null default 3 check (interval_minutes between 1 and 1440),
  skip_if_last_is_bot boolean not null default true,
  updated_at timestamptz not null default now()
);
insert into public.room_content_bot_settings (id) values (1) on conflict (id) do nothing;

create table if not exists public.room_content_bot_posts (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('sewing','adhkar','secrets','life','experience','trade')),
  body text not null check (length(trim(body)) between 5 and 600),
  is_active boolean not null default true,
  posted_count integer not null default 0,
  last_posted_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.room_content_bot_settings enable row level security;
alter table public.room_content_bot_posts enable row level security;
-- لا سياسات قراءة/كتابة مباشرة: الوصول عبر دوال المالك فقط.

create unique index if not exists room_content_bot_posts_body_uq
  on public.room_content_bot_posts (md5(body));

insert into public.room_content_bot_posts (category, body) values
-- ✂️ الخياطة
('sewing','غيّر إبرة الماكينة مع كل مشروع جديد أو بعد نحو 8 ساعات خياطة فعلية؛ الإبرة المثلومة هي السبب الأول للغرز المقفوزة وتنسيل القماش.'),
('sewing','اغسل القماش القطني واكوِه قبل القص؛ القطن قد ينكمش عدة سنتيمترات في أول غسلة فيضيق الثوب بعد التسليم.'),
('sewing','قصّ دائمًا على اتجاه النسيج (الخيط الطولي الموازي للحافة)؛ القص المائل بالخطأ يجعل الثوب يلتوي ويسقط بشكل غير متوازن.'),
('sewing','جرّب شدّ الخيط على قطعة صغيرة من القماش نفسه وبنفس عدد الطبقات قبل الخياطة الأساسية؛ دقيقة تجربة توفر ساعة فكّ.'),
('sewing','للأقمشة المطاطة (الجيرسيه والليكرا) استعمل إبرة Stretch أو Ballpoint وغرزة متعرجة صغيرة، وإلا ستتقطع الغرز عند الشد.'),
('sewing','اكوِ وأنت تخيط: كيّ كل درزة بعد خياطتها مباشرة هو الفرق الأكبر بين شغل البيت والشغل الاحترافي.'),
('sewing','ثبّت الدبابيس عموديًا على خط الخياطة ورؤوسها للخارج؛ تُسحب بسهولة وأنت تخيط وتقلّ احتمالية كسر الإبرة.'),
('sewing','مقاس الإبرة حسب القماش: الجينز والقماش الثقيل 100/16، القطن المتوسط 80/12، والشيفون والحرير 60/8 إلى 70/10.'),
('sewing','الشيفون ينسحب داخل لوحة الإبرة؟ ضع تحته ورقة رقيقة (ورق زبدة أو ورق مناديل) واخِط عليها ثم انزعها.'),
('sewing','في الحواف المنحنية للرقبة والإبط: اعمل خياطة تثبيت (Staystitch) بعد القص مباشرة لتمنع تمدد القماش قبل التجميع.'),
('sewing','بعد خياطة الحواف المنحنية: قص شقوقًا صغيرة في المنحنى المقعر، ومثلثات في المنحنى المحدب، ليستوي الحرف بعد القلب.'),
('sewing','قس مرتين واقطع مرة؛ القماش المقصوص خطأ لا يعود.'),
('sewing','الياقات والأساور وحواف الأزرار تحتاج حشوة لاصقة (إنترلاينينغ) لتتماسك ولا تتجعد بعد الغسيل.'),
('sewing','ابدأ كل درزة وأنهِها بثلاث غرز رجوع؛ هكذا لا تنفك الخياطة عند أول شدّ.'),
('sewing','نظّف علبة المكوك من الوبر بعد كل مشروع كبير، وزيّت الماكينة حسب دليلها؛ أغلب أعطال الغرز سببها الوبر المتراكم.'),
('sewing','للجلد والقماش المشمع: إبرة جلد، وقدم تفلون أو قدم مشّاية، ومشابك بدل الدبابيس لأن ثقب الدبوس يبقى ظاهرًا.'),
('sewing','قبل خياطة قماش ملوّن على قماش فاتح: بلّل قصاصة صغيرة واضغطها على قماش أبيض؛ إن صبغت فاغسل القماش أولًا.'),
('sewing','السحاب المخفي: اكوِ أسنانه للخلف بمكواة فاترة قبل تركيبه، واستعمل قدم السحاب المخفي، فيختفي تمامًا في الدرزة.'),
('sewing','جرّب العروة دائمًا على قطعة تجربة بنفس عدد الطبقات والحشوة قبل عملها في القطعة الأصلية.'),
('sewing','السرعة الثابتة المتوسطة أدق من الضغط السريع المتقطع على الدواسة؛ الدقة أولًا ثم تأتي السرعة مع الوقت.'),
('sewing','اترك هوامش خياطة جانبية واسعة نسبيًا في ملابس الأطفال والملابس الضيقة؛ تسمح بالتوسيع لاحقًا بدل التفصيل من جديد.'),
('sewing','علّم على القماش بالطباشير أو بقلم يختفي بالماء أو الحرارة، ولا تستعمل القلم الجاف أبدًا على الوجه الظاهر.'),
('sewing','خيط البوليستر متين ومناسب لأغلب الأقمشة، وخيط القطن أنسب للقطن الخالص الذي سيُصبغ أو يُكوى بحرارة عالية.'),
('sewing','الأوفرلوك يعطي تشطيبًا نظيفًا، وإن لم يتوفر فالدرزة الفرنسية مثالية للأقمشة الشفافة: حافة مخفية بلا أي تنسيل.'),
-- 📿 أذكار
('adhkar','سبحان الله وبحمده، سبحان الله العظيم — كلمتان خفيفتان على اللسان، ثقيلتان في الميزان، حبيبتان إلى الرحمن. (متفق عليه)'),
('adhkar','لا حول ولا قوة إلا بالله — كنز من كنوز الجنة. (متفق عليه)'),
('adhkar','أستغفر الله العظيم الذي لا إله إلا هو الحي القيوم وأتوب إليه.'),
('adhkar','اللهم صلِّ وسلّم وبارك على نبينا محمد ﷺ.'),
('adhkar','لا إله إلا الله وحده لا شريك له، له الملك وله الحمد، وهو على كل شيء قدير.'),
('adhkar','اللهم إني أسألك علمًا نافعًا، ورزقًا طيبًا، وعملًا متقبّلًا. (من أذكار الصباح — رواه ابن ماجه)'),
('adhkar','حسبي الله لا إله إلا هو، عليه توكلت وهو رب العرش العظيم.'),
('adhkar','بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء، وهو السميع العليم.'),
('adhkar','رضيت بالله ربًّا، وبالإسلام دينًا، وبمحمد ﷺ نبيًّا.'),
('adhkar','اللهم أعنّي على ذكرك وشكرك وحسن عبادتك.'),
('adhkar','يا حيّ يا قيّوم برحمتك أستغيث، أصلح لي شأني كله، ولا تكلني إلى نفسي طرفة عين.'),
('adhkar','سبحان الله، والحمد لله، ولا إله إلا الله، والله أكبر.'),
('adhkar','﴿رَبِّ اشْرَحْ لِي صَدْرِي * وَيَسِّرْ لِي أَمْرِي﴾'),
('adhkar','﴿رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ﴾'),
('adhkar','اللهم اكفني بحلالك عن حرامك، وأغنني بفضلك عمّن سواك. (رواه الترمذي)'),
('adhkar','قال ﷺ: «ما أكل أحدٌ طعامًا قط خيرًا من أن يأكل من عمل يده». (رواه البخاري) — بارك الله في كل يد تعمل.'),
('adhkar','قال ﷺ: «إن الله يحب إذا عمل أحدكم عملًا أن يتقنه». الإتقان عبادة قبل أن يكون مهنة.'),
('adhkar','قال ﷺ: «التاجر الصدوق الأمين مع النبيين والصديقين والشهداء». (رواه الترمذي)'),
('adhkar','﴿وَقُل رَّبِّ زِدْنِي عِلْمًا﴾'),
('adhkar','اللهم بارك لنا في أعمالنا وأرزاقنا وأوقاتنا، واجعل ما نصنعه بأيدينا خيرًا لنا ولمن يلبسه.'),
-- 🧵 أسرار المهنة
('secrets','صوّر كل قطعة تنجزها في ضوء النهار وعلى خلفية سادة؛ معرض أعمالك هو أقوى إعلان مجاني تملكه.'),
('secrets','احتفظ بسجل مقاسات لكل زبون مع التاريخ؛ الزبون يشعر بالتقدير حين لا يُطلب منه القياس من جديد.'),
('secrets','اطلب عربونًا قبل البدء؛ يحمي وقتك وخاماتك ويؤكد جدية الطلب.'),
('secrets','أعطِ موعد تسليم أبعد قليلًا من تقديرك الحقيقي؛ التسليم قبل الموعد يبني ثقة لا يبنيها أي كلام.'),
('secrets','بروفة القياس في منتصف العمل توفر عليك إعادة تفصيل كاملة في آخره.'),
('secrets','احتفظ بقصاصة صغيرة من قماش كل زبون؛ تحتاجها لأي تصليح أو رقعة لاحقًا.'),
('secrets','التشطيب الداخلي — الحواف المخفية ونظافة الدرزات من الداخل — هو ما يميّز الخياط المحترف عند أول نظرة.'),
('secrets','سعّر بحساب لا بإحساس: (ساعات العمل × أجر الساعة) + الخامات + هامش للمخاطرة والأخطاء.'),
('secrets','التخصص يرفع اسمك: كن «خياط العبايات» أو «خياطة فساتين السهرة» في منطقتك، بدل أن تكون خياطًا لكل شيء.'),
('secrets','ضع ملصقًا باسمك أو شعارك داخل كل قطعة تخرج من يدك؛ كل قطعة تصبح إعلانًا يمشي.'),
('secrets','الصيانة الدورية للماكينة أرخص بكثير من توقفها في موسم الأعياد.'),
('secrets','لا تبدأ قطعة ضيقة بقماش لم يُغسل؛ اشرح للزبون أن الانكماش بعد الغسيل سيضيّقها.'),
('secrets','رتّب طلبات الموسم حسب تاريخ التسليم لا حسب تاريخ الاستلام، وأغلق استقبال الطلبات حين تمتلئ طاقتك.'),
('secrets','اكتب على ظهر كل باترون: المقاس، اسم الموديل، التاريخ، وهامش الخياطة المضمّن؛ ستشكر نفسك بعد سنة.'),
-- 🌿 الحياة
('life','خطوة صغيرة كل يوم أفضل من خطة كبيرة لا تبدأ أبدًا.'),
('life','خذ استراحة قصيرة كل ساعة عمل: قف، حرّك كتفيك، وانظر بعيدًا عن الشاشة أو الماكينة؛ عيناك وظهرك رأس مالك.'),
('life','قل «لا» للعمل الذي يفوق طاقتك؛ الوعد الذي لا تقدر عليه يكلّفك سمعتك.'),
('life','الكلمة الطيبة صدقة، وقد تكون أجمل ما يسمعه أحدهم اليوم.'),
('life','لا تقارن بدايتك بنهاية غيرك؛ كل محترف كان يومًا مبتدئًا.'),
('life','نظّم مكان عملك في آخر اليوم؛ تبدأ صباحك بذهن صافٍ بدل الفوضى.'),
('life','اشكر من علّمك ولو حرفًا، وعلّم غيرك ما تعرفه؛ العلم يزيد بالإنفاق.'),
('life','الصبر على التعلّم اليوم هو ما يجعلك سريعًا ومتقنًا غدًا.'),
('life','اشرب ماءً كافيًا، ونَم جيدًا؛ لا إنتاج حقيقيًا مع جسد متعب.'),
('life','الخطأ ليس فشلًا، الفشل أن تكرر الخطأ نفسه دون أن تتعلم منه.'),
-- 💡 تجارب
('experience','من تجارب أصحاب المهنة: أول عشرة زبائن هم أهم استثمار؛ أتقن شغلهم ولو بلا ربح، فهم من سيجلبون لك العشرين التالين.'),
('experience','من تجارب أصحاب المهنة: الخطأ الأكثر تكلفة كان القص قبل التأكد من اتجاه الرسمة في القماش المطبوع؛ تأكد دائمًا أن الرسمة «واقفة».'),
('experience','من تجارب أصحاب المهنة: الاتفاق المكتوب البسيط (السعر، الموعد، العربون) أنهى معظم الخلافات مع الزبائن.'),
('experience','من تجارب أصحاب المهنة: شراء ماكينة جيدة مستعملة من مصدر موثوق كان أفضل من ماكينة جديدة رخيصة تتعطل باستمرار.'),
('experience','من تجارب أصحاب المهنة: تصوير القطعة على شخص حقيقي يبيع أكثر بكثير من تصويرها مفرودة على الطاولة.'),
('experience','من تجارب أصحاب المهنة: الزبون الغاضب الذي عولجت مشكلته بلطف وسرعة صار من أوفى الزبائن.'),
('experience','من تجارب أصحاب المهنة: تعلّم مهارة واحدة جديدة كل شهر (عروة يدوية، تطريز، باترون) رفع الأسعار أكثر من أي إعلان.'),
('experience','شاركنا تجربتك: ما أكثر خطأ تعلّمت منه في الخياطة أو في عملك؟ اكتبه هنا ليستفيد غيرك ✨'),
('experience','شاركنا تجربتك: ما أفضل نصيحة سمعتها في بدايتك وما زلت تعمل بها حتى اليوم؟'),
-- 💼 التجارة
('trade','افصل حساب مشروعك عن مصروفك الشخصي من اليوم الأول؛ بدون ذلك لن تعرف أبدًا هل تربح أم تخسر.'),
('trade','ابدأ صغيرًا واختبر الطلب قبل التوسع: نموذج واحد بكميات قليلة، ثم زد ما يُباع فعلًا.'),
('trade','اشترِ الخامات بالجملة فقط لما يُباع باستمرار؛ المخزون الراكد مال محبوس.'),
('trade','سجّل كل مصروف ولو كان صغيرًا؛ المصاريف الصغيرة المتكررة هي التي تأكل الربح بصمت.'),
('trade','الصدق في وصف المنتج (القماش، المقاس، اللون الحقيقي) يقلّل المرتجعات ويبني سمعة تدوم.'),
('trade','احسب ربحك الصافي بعد كل التكاليف (خامات، كهرباء، توصيل، وقتك)، لا الفرق بين سعر البيع وسعر القماش فقط.'),
('trade','خدمة ما بعد البيع (تعديل بسيط مجاني خلال أيام) تحوّل المشتري مرة إلى زبون دائم.'),
('trade','نوّع مصادر الخامات ولا تعتمد على مورد واحد؛ توقفه يعني توقفك.'),
('trade','العرض المحدود بوقت حقيقي (كموسم أو مناسبة) يحرّك البيع أكثر من التخفيض الدائم الذي يُضعف قيمة منتجك.'),
('trade','اسأل زبائنك بعد الاستلام عن رأيهم؛ الملاحظة الصادقة أثمن من أي دراسة سوق.'),
('trade','ادّخر جزءًا ثابتًا من كل ربح لتطوير أدواتك؛ المشروع الذي لا يستثمر في نفسه يتوقف عن النمو.')
on conflict do nothing;

-- ===== التنفيذ الدوري =====
create or replace function private.content_bot_tick()
returns integer
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_set public.room_content_bot_settings;
  v_room record;
  v_post public.room_content_bot_posts;
  v_last_bot timestamptz;
  v_last_is_bot boolean;
  v_count integer := 0;
  v_label text;
  v_icon text;
begin
  select * into v_set from public.room_content_bot_settings where id = 1;
  if not found or not v_set.enabled then return 0; end if;

  for v_room in
    select r.id from public.chat_rooms r where coalesce(r.is_active, true)
  loop
    select max(m.created_at) into v_last_bot
      from public.public_chat_messages m
     where m.room_id = v_room.id
       and m.metadata->>'system_event' = 'content_bot'
       and m.created_at > now() - interval '2 days';
    if v_last_bot is not null
       and v_last_bot > now() - make_interval(mins => v_set.interval_minutes) + interval '5 seconds' then
      continue;
    end if;

    if v_set.skip_if_last_is_bot then
      select (m.metadata->>'system_event') = 'content_bot' into v_last_is_bot
        from public.public_chat_messages m
       where m.room_id = v_room.id and m.deleted_at is null
       order by m.created_at desc limit 1;
      if coalesce(v_last_is_bot, false) then continue; end if;
    end if;

    select * into v_post from public.room_content_bot_posts p
     where p.is_active
     order by p.posted_count asc, p.last_posted_at asc nulls first, random()
     limit 1
     for update skip locked;
    if not found then return v_count; end if;

    v_label := case v_post.category
      when 'sewing' then 'معلومة خياطة' when 'adhkar' then 'ذِكر'
      when 'secrets' then 'سر من أسرار المهنة' when 'life' then 'من الحياة'
      when 'experience' then 'تجارب' else 'تجارة' end;
    v_icon := case v_post.category
      when 'sewing' then '✂️' when 'adhkar' then '📿' when 'secrets' then '🧵'
      when 'life' then '🌿' when 'experience' then '💡' else '💼' end;

    insert into public.public_chat_messages (room_id, user_id, kind, message, body, metadata)
    values (v_room.id, null, 'system', v_post.body, v_post.body,
            jsonb_build_object('system_event', 'content_bot',
                               'bot_category', v_post.category,
                               'bot_label', v_label,
                               'bot_icon', v_icon,
                               'bot_post_id', v_post.id));

    update public.room_content_bot_posts
       set posted_count = posted_count + 1, last_posted_at = now()
     where id = v_post.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$function$;
revoke all on function private.content_bot_tick() from public, anon, authenticated;

select cron.schedule('room_content_bot_tick', '* * * * *', 'select private.content_bot_tick();');

-- ===== تحكم المالك =====
create or replace function private_rpc.admin_get_content_bot()
returns jsonb language plpgsql security definer set search_path to '' as $function$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public._is_platform_owner(auth.uid()) then raise exception 'FORBIDDEN'; end if;
  return jsonb_build_object(
    'settings', (select to_jsonb(s) from public.room_content_bot_settings s where id = 1),
    'posts', coalesce((select jsonb_agg(to_jsonb(p) order by p.category, p.created_at)
                         from public.room_content_bot_posts p), '[]'::jsonb));
end; $function$;

create or replace function private_rpc.admin_set_content_bot_settings(p_enabled boolean, p_interval_minutes integer)
returns void language plpgsql security definer set search_path to '' as $function$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public._is_platform_owner(auth.uid()) then raise exception 'FORBIDDEN'; end if;
  if p_interval_minutes < 1 or p_interval_minutes > 1440 then raise exception 'INVALID_INTERVAL'; end if;
  update public.room_content_bot_settings
     set enabled = p_enabled, interval_minutes = p_interval_minutes, updated_at = now()
   where id = 1;
end; $function$;

create or replace function private_rpc.admin_upsert_content_bot_post(p_id uuid, p_category text, p_body text, p_active boolean)
returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public._is_platform_owner(auth.uid()) then raise exception 'FORBIDDEN'; end if;
  if p_id is null then
    insert into public.room_content_bot_posts (category, body, is_active)
    values (p_category, trim(p_body), coalesce(p_active, true)) returning id into v_id;
  else
    update public.room_content_bot_posts
       set category = p_category, body = trim(p_body), is_active = coalesce(p_active, is_active)
     where id = p_id returning id into v_id;
    if v_id is null then raise exception 'NOT_FOUND'; end if;
  end if;
  return v_id;
end; $function$;

create or replace function public.admin_get_content_bot()
returns jsonb language sql set search_path to 'public','private_rpc' as $$ select private_rpc.admin_get_content_bot(); $$;
create or replace function public.admin_set_content_bot_settings(p_enabled boolean, p_interval_minutes integer)
returns void language sql set search_path to 'public','private_rpc' as $$ select private_rpc.admin_set_content_bot_settings($1, $2); $$;
create or replace function public.admin_upsert_content_bot_post(p_id uuid, p_category text, p_body text, p_active boolean)
returns uuid language sql set search_path to 'public','private_rpc' as $$ select private_rpc.admin_upsert_content_bot_post($1, $2, $3, $4); $$;

revoke all on function public.admin_get_content_bot() from anon;
revoke all on function public.admin_set_content_bot_settings(boolean, integer) from anon;
revoke all on function public.admin_upsert_content_bot_post(uuid, text, text, boolean) from anon;
grant execute on function public.admin_get_content_bot() to authenticated;
grant execute on function public.admin_set_content_bot_settings(boolean, integer) to authenticated;
grant execute on function public.admin_upsert_content_bot_post(uuid, text, text, boolean) to authenticated;
