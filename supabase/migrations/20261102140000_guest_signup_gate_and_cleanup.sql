-- ============================================================
-- حساب الزائر — بوّابة الدخول وتنظيف المهجورين
--
-- مشكلتان بقيتا بعد الهجرتين السابقتين:
--
-- 1) مفتاح `guest_signup` لم يكن له أثر: `feature_flags` مقروء
--    لـ authenticated فقط، وصفحة التسجيل لا جلسة فيها — فالتطبيق
--    لا يعرف أيُظهر زر «دخول كزائر» أم لا. والأهمّ: لا شيء كان
--    يمنع الدخول فعليًا لو أغلقه المالك.
--
-- 2) حسابات الزوّار المهجورة تتراكم بلا حدّ وتضخّم فاتورة MAU
--    (تحذير Supabase نفسه عند تفعيل الدخول المجهول).
-- ============================================================

-- ── 1) هل الدخول كزائر مسموح؟ — مقروء قبل تسجيل الدخول ──
-- تكشف قيمة منطقية واحدة لا أكثر، فلا تسريب لبقية المفاتيح.
create or replace function public.guest_signup_enabled()
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(
    (select f.is_enabled from public.feature_flags f
      where f.flag_key = 'guest_signup'),
    false);
$$;

grant execute on function public.guest_signup_enabled() to anon, authenticated;

-- ── 2) الفرض الخادمي لبوّابة الدخول ──
-- التريجر يعمل عند الإدراج في auth.users، فرفع خطأ هنا يُفشل إنشاء
-- الزائر من أصله. الحارس ضيّق عمدًا: لا يمسّ إلا الحساب المجهول،
-- ولا يُفعَّل إلا إن أغلق المالك المفتاح صراحةً — فتسجيل الأعضاء
-- العاديين لا يتأثر بحال.
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
    if coalesce(new.is_anonymous, false)
       and not public.guest_signup_enabled() then
        raise exception 'GUEST_SIGNUP_DISABLED: الدخول كزائر متوقف حاليًا.';
    end if;

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

-- ── 3) تنظيف الزوّار المهجورين ──
-- من لم يُرقِّ حسابه ولم يعد منذ [p_days] يومًا. الحذف من auth.users
-- يتكفّل ببقية الجداول عبر المفاتيح الأجنبية القائمة.
-- يُنادى من المالك أو السوبر أدمن، أو يُجدوَل بـ pg_cron.
create or replace function public.cleanup_abandoned_guests(p_days integer default 30)
returns integer
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_deleted integer := 0;
  v_days integer := greatest(coalesce(p_days, 30), 7);
begin
  if not public.can_manage_guest_settings() then
    raise exception 'FORBIDDEN';
  end if;

  with doomed as (
    select u.id
      from auth.users u
     where coalesce(u.is_anonymous, false)
       and coalesce(u.last_sign_in_at, u.created_at) < now() - make_interval(days => v_days)
  ), gone as (
    delete from auth.users u
     using doomed d
     where u.id = d.id
    returning u.id
  )
  select count(*) into v_deleted from gone;

  insert into public.audit_logs(
    actor_user_id, actor_id, action, resource_type, resource_id,
    target_id, result, metadata)
  values (auth.uid(), auth.uid(), 'GUESTS_CLEANED', 'auth.users', 'anonymous',
          'anonymous', 'success',
          jsonb_build_object('deleted', v_deleted, 'older_than_days', v_days));

  return v_deleted;
end;
$function$;

grant execute on function public.cleanup_abandoned_guests(integer) to authenticated;

-- ── 4) عدّاد للوحة المالك ──
create or replace function public.owner_guest_stats()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select jsonb_build_object(
    'total_guests',
      (select count(*) from auth.users where coalesce(is_anonymous,false)),
    'active_7d',
      (select count(*) from auth.users
        where coalesce(is_anonymous,false)
          and coalesce(last_sign_in_at, created_at) >= now() - interval '7 days'),
    'abandoned_30d',
      (select count(*) from auth.users
        where coalesce(is_anonymous,false)
          and coalesce(last_sign_in_at, created_at) < now() - interval '30 days'),
    'upgraded',
      (select count(*) from auth.users
        where not coalesce(is_anonymous,false)
          and email_confirmed_at is not null)
  );
$$;

grant execute on function public.owner_guest_stats() to authenticated;
