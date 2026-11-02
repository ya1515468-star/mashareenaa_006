-- ============================================================
-- إكمال بيانات الملف الشخصي (الجنس وتاريخ الميلاد)
--
-- الثغرة التي كشفها الفحص: الدخول بجوجل يتخطّى نموذج التسجيل كلّه،
-- فلا يُسأل صاحبه عن جنس ولا ميلاد. فحصت قاعدتك: 7 حسابات جوجل،
-- كلها بلا جنس وبلا ميلاد. ومثلها الحسابات المسجَّلة بالبريد قبل
-- إضافة الحقلين.
--
-- فصار اكتمال البيانات ثلاثة مسارات: بالبريد (يُسأل)، كزائر (يُسأل)،
-- بجوجل (لا يُسأل). وهذه الهجرة تسدّ الثالث وتُصلح القديم معًا.
--
-- ولماذا دالة لا تحديث مباشر: جدول profiles لا يملك سياسة UPDATE
-- للمالك نفسه — فقط `dragon_full_access_profiles_update`. فكل تعديل
-- يمرّ بدالة `set_my_*` كما هو نمط المشروع.
-- ============================================================

-- ── 1) ما الذي ينقص ملفي؟ ──
create or replace function public.get_my_profile_completion()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select jsonb_build_object(
    'has_gender',     (p.gender is not null),
    'has_birth_date', (p.birth_date is not null),
    'has_username',   (nullif(trim(coalesce(p.username,'')),'') is not null),
    'gender',         p.gender,
    'birth_date',     p.birth_date,
    'age',            public.profile_age(p.birth_date),
    'needs_basics',   (p.gender is null or p.birth_date is null)
  )
  from public.profiles p
  where p.id = auth.uid();
$$;

grant execute on function public.get_my_profile_completion() to authenticated;

-- ── 2) ضبط الجنس وتاريخ الميلاد ──
-- التحقق خادمي: الجنس من قيمتين، والتاريخ في نطاق معقول. ويُسجَّل أي
-- **تغيير** لقيمة سبق ضبطها (لا الضبط الأول) — فتعديل العمر لاحقًا
-- يترك أثرًا يُراجَع، بلا منع التصحيح البريء لخطأ إدخال.
create or replace function public.set_my_gender_birth(
  p_gender text default null,
  p_birth_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_old_gender text;
  v_old_birth date;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;

  if p_gender is not null and p_gender not in ('male','female') then
    raise exception 'INVALID_GENDER';
  end if;
  if p_birth_date is not null
     and (p_birth_date <= date '1900-01-01' or p_birth_date >= current_date) then
    raise exception 'INVALID_BIRTH_DATE';
  end if;
  if p_gender is null and p_birth_date is null then
    raise exception 'NOTHING_TO_SET';
  end if;

  select gender, birth_date into v_old_gender, v_old_birth
    from public.profiles where id = v_uid;

  update public.profiles
     set gender     = coalesce(p_gender, gender),
         birth_date = coalesce(p_birth_date, birth_date),
         updated_at = now()
   where id = v_uid;

  -- أثر للمراجعة عند تغيير قيمة مضبوطة سلفًا، لا عند الضبط الأول.
  if (p_gender is not null and v_old_gender is not null
      and p_gender is distinct from v_old_gender)
     or (p_birth_date is not null and v_old_birth is not null
         and p_birth_date is distinct from v_old_birth) then
    insert into public.audit_logs(
      actor_user_id, actor_id, action, resource_type, resource_id,
      target_id, result, metadata)
    values (v_uid, v_uid, 'PROFILE_BASICS_CHANGED', 'profiles',
            v_uid::text, v_uid::text, 'success',
            jsonb_build_object(
              'gender_from', v_old_gender, 'gender_to', p_gender,
              'birth_from', v_old_birth,  'birth_to', p_birth_date));
  end if;

  return public.get_my_profile_completion();
end;
$function$;

grant execute on function public.set_my_gender_birth(text, date) to authenticated;

-- ── 3) عدّاد للوحة المالك: كم ملفًا ناقصًا، ومن أي مسار ──
create or replace function public.owner_profile_completion_stats()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select jsonb_build_object(
    'total',        (select count(*) from public.profiles),
    'missing_both', (select count(*) from public.profiles
                      where gender is null and birth_date is null),
    'missing_any',  (select count(*) from public.profiles
                      where gender is null or birth_date is null),
    'by_provider',  coalesce((
      select jsonb_object_agg(x.provider, x.missing)
        from (
          select i.provider::text as provider, count(*) as missing
            from auth.identities i
            join public.profiles p on p.id = i.user_id
           where p.gender is null or p.birth_date is null
           group by i.provider
        ) x
    ), '{}'::jsonb)
  );
$$;

grant execute on function public.owner_profile_completion_stats() to authenticated;
