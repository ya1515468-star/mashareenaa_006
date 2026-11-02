-- ============================================================
-- حساب الزائر (anonymous) — الطبقة الأساسية
--
-- إضافية بالكامل: أعمدة جديدة، دوال جديدة، صفوف جديدة. لا تحذف
-- ولا تُعدّل أي شيء قائم عدا `handle_new_user` التي تُعاد كتابتها
-- بجسمها السابق حرفيًا مع التقاط الجنس والميلاد.
--
-- خلفية: تفعيل Anonymous sign-ins يمنح الزائر دور `authenticated`،
-- أي نفس صلاحيات العضو المسجَّل تحت كل سياسات RLS — وفي هذا
-- المشروع 429 سياسة لا واحدة منها تعرف الزائر. فالمنع الخادمي
-- في الهجرة التالية ليس تحسينًا بل ضرورة.
-- ============================================================

-- ── 1) الجنس وتاريخ الميلاد — لكل المستخدمين لا للزائر وحده ──
-- يُخزَّن تاريخ الميلاد لا العمر: العمر رقم يصدأ، ومن يسجّل بعمر
-- 20 يبقى 20 إلى الأبد.
alter table public.profiles add column if not exists birth_date date;
alter table public.profiles add column if not exists gender text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_gender_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_gender_check
      check (gender is null or gender in ('male','female'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_birth_date_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_birth_date_check
      check (birth_date is null
             or (birth_date > date '1900-01-01' and birth_date < current_date));
  end if;
end $$;

comment on column public.profiles.birth_date is
  'تاريخ الميلاد. العمر يُحسب منه عبر public.profile_age() ولا يُخزَّن.';
comment on column public.profiles.gender is 'male | female | null';

-- العمر محسوبًا — مصدر واحد بدل حسابه في كل موضع.
create or replace function public.profile_age(p_birth_date date)
returns integer
language sql
immutable
set search_path to ''
as $$
  select case
    when p_birth_date is null then null
    else extract(year from age(current_date, p_birth_date))::int
  end;
$$;

-- ── 2) من هو الزائر؟ ──
create or replace function public.is_guest_uid(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select p_uid is not null
     and exists (
       select 1 from auth.users u
       where u.id = p_uid and coalesce(u.is_anonymous, false)
     );
$$;

create or replace function public.is_guest()
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select public.is_guest_uid(auth.uid());
$$;

comment on function public.is_guest() is
  'هل المستخدم الحالي زائر (حساب مجهول لم يُرقَّ ببريد مؤكَّد)؟';

-- ── 3) هل يُسمح للمستخدم الحالي بهذه الميزة؟ ──
-- العضو المسجَّل: نعم دائمًا — فلا يمسّ هذا المنع أحدًا سواه الزائر.
-- الزائر: فقط إن فتحها المالك في feature_flags.
create or replace function public.guest_can(p_flag text)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select case
    when not public.is_guest() then true
    else coalesce(
      (select f.is_enabled from public.feature_flags f where f.flag_key = p_flag),
      false)
  end;
$$;

comment on function public.guest_can(text) is
  'العضو المسجَّل يمرّ دائمًا؛ الزائر يمرّ فقط إن كان المفتاح مفعَّلًا.';

-- رسالة القفل كما كتبها المالك — ليعرضها التطبيق بدل رفض جاف.
create or replace function public.guest_lock_message(p_flag text)
returns text
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(
    (select nullif(trim(f.disabled_message_ar), '')
       from public.feature_flags f where f.flag_key = p_flag),
    'سجّل ببريدك الإلكتروني لتفتح هذه الميزة.');
$$;

-- ── 4) مفاتيح الزائر ──
-- الافتراضي: كل شيء مغلق عدا الدخول نفسه. يفتحها المالك أو
-- السوبر أدمن متى شاء بلا إصدار جديد للتطبيق.
insert into public.feature_flags (flag_key, is_enabled, name_ar, disabled_message_ar)
values
  ('guest_signup',       true,  'السماح بالدخول كزائر',
   'الدخول كزائر متوقف حاليًا.'),
  ('guest_private_chat', false, 'الزائر: الرسائل الخاصة',
   'الرسائل الخاصة للأعضاء المسجَّلين. سجّل ببريدك لتفتحها.'),
  ('guest_calls',        false, 'الزائر: المكالمات',
   'المكالمات للأعضاء المسجَّلين. سجّل ببريدك لتفتحها.'),
  ('guest_gifts',        false, 'الزائر: إرسال الهدايا',
   'إرسال الهدايا للأعضاء المسجَّلين. سجّل ببريدك لتفتحه.'),
  ('guest_purchases',    false, 'الزائر: الشراء',
   'الشراء للأعضاء المسجَّلين. سجّل ببريدك لتفتحه.'),
  ('guest_uploads',      false, 'الزائر: رفع الصور والصوت',
   'رفع الملفات للأعضاء المسجَّلين. سجّل ببريدك لتفتحه.'),
  ('guest_cosmetics',    false, 'الزائر: المظهر المدفوع',
   'تخصيص المظهر للأعضاء المسجَّلين. سجّل ببريدك لتفتحه.')
on conflict (flag_key) do nothing;

-- ── 5) التقاط الاسم والجنس والميلاد عند إنشاء الحساب ──
-- الملف الشخصي للزائر يُنشأ تلقائيًا كأي عضو عبر التريجر
-- on_auth_user_created؛ البيانات تصل في raw_user_meta_data.
-- الجسم السابق محفوظ حرفيًا، والإضافة هي العمودان الجديدان فقط.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
    v_user_role_id bigint;
    v_birth date;
begin
    begin
        v_birth := nullif(new.raw_user_meta_data ->> 'birth_date', '')::date;
    exception when others then
        v_birth := null;
    end;

    insert into public.profiles (id, username, display_name, gender, birth_date)
    values (
        new.id,
        null,
        coalesce(
            new.raw_user_meta_data ->> 'display_name',
            new.raw_user_meta_data ->> 'name'
        ),
        case
          when new.raw_user_meta_data ->> 'gender' in ('male','female')
          then new.raw_user_meta_data ->> 'gender'
          else null
        end,
        v_birth
    )
    on conflict (id) do nothing;

    select id
      into v_user_role_id
      from public.roles
     where code = 'user'
     limit 1;

    if v_user_role_id is not null then
        insert into public.user_roles (user_id, role_id, assigned_by)
        values (new.id, v_user_role_id, new.id)
        on conflict do nothing;
    end if;

    return new;
end;
$function$;
