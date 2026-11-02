-- ============================================================
-- حساب الزائر — جدولة التنظيف وتصحيح تقرير الحراسة
-- ============================================================

-- ── 1) تصحيح إيجابيّتين كاذبتين في التقرير ──
-- كانت `guard_guest_write` و`guest_guard_report` تُدرَجان ضمن «الدوال
-- المحروسة» لأنهما تحتويان نصّ GUEST_FEATURE_LOCKED بحكم طبيعتهما —
-- فيُقرأ العدد خطأً. تُستثنيان هنا.
create or replace function public.guest_guard_report()
returns table (guarded_object text, kind text, flag text)
language sql
stable
security definer
set search_path to ''
as $$
  select c.relname::text, 'table_trigger'::text,
         split_part(split_part(pg_get_triggerdef(t.oid), '''', 2), '''', 1)
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname='public' and t.tgname like 'trg_guest_guard_%'
  union all
  select p.proname::text, 'function_guard'::text, 'inline'::text
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname in ('public','private_rpc')
     and p.prosrc like '%GUEST_FEATURE_LOCKED%'
     and p.proname not in ('guard_guest_write','guest_guard_report')
  union all
  select 'storage.objects'::text, 'storage_policy'::text, 'guest_uploads'::text
   where exists (
     select 1 from pg_policies
      where schemaname='storage' and tablename='objects'
        and policyname='guest_upload_block')
  order by 2, 1;
$$;

grant execute on function public.guest_guard_report() to authenticated;

-- ── 2) جدولة حذف الزوّار المهجورين ──
-- `cleanup_abandoned_guests` كانت تعمل بالزرّ فقط. pg_cron مثبَّت في
-- هذا المشروع، فالجدولة ممكنة بلا خدمة خارجية.
--
-- الدالة المجدوَلة تعمل بلا جلسة (auth.uid() = null)، ودالة التنظيف
-- تشترط `can_manage_guest_settings()` — فتفشل تحت cron. لذلك نسخة
-- نظامية منفصلة بلا فحص المنادي، لا تُمنح لأحد غير cron.
create or replace function public.cron_cleanup_abandoned_guests(p_days integer default 30)
returns integer
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_deleted integer := 0;
  v_days integer := greatest(coalesce(p_days, 30), 7);
begin
  with doomed as (
    select u.id
      from auth.users u
     where coalesce(u.is_anonymous, false)
       and coalesce(u.last_sign_in_at, u.created_at)
           < now() - make_interval(days => v_days)
  ), gone as (
    delete from auth.users u
     using doomed d
     where u.id = d.id
    returning u.id
  )
  select count(*) into v_deleted from gone;

  if v_deleted > 0 then
    insert into public.audit_logs(
      actor_user_id, actor_id, action, resource_type, resource_id,
      target_id, result, metadata)
    values (null, null, 'GUESTS_CLEANED_CRON', 'auth.users', 'anonymous',
            'anonymous', 'success',
            jsonb_build_object('deleted', v_deleted, 'older_than_days', v_days));
  end if;

  return v_deleted;
end;
$function$;

-- لا تُمنح لأحد: cron ينفّذها بصلاحية المالك، والمستخدمون يستعملون
-- النسخة المحروسة `cleanup_abandoned_guests`.
revoke all on function public.cron_cleanup_abandoned_guests(integer) from public;
revoke all on function public.cron_cleanup_abandoned_guests(integer) from anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname='pg_cron') then
    -- إزالة أي جدولة سابقة بنفس الاسم قبل إعادة الإنشاء.
    perform cron.unschedule(jobid)
       from cron.job where jobname = 'cleanup_abandoned_guests_daily';
    perform cron.schedule(
      'cleanup_abandoned_guests_daily',
      '17 3 * * *',  -- 3:17 فجرًا UTC يوميًا، خارج ساعات الذروة
      $cron$ select public.cron_cleanup_abandoned_guests(30) $cron$
    );
  end if;
end $$;

-- للتحقق من الجدولة من داخل التطبيق.
create or replace function public.owner_guest_cleanup_schedule()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(
    (select jsonb_build_object(
              'scheduled', true,
              'schedule', j.schedule,
              'active', j.active)
       from cron.job j
      where j.jobname = 'cleanup_abandoned_guests_daily'
      limit 1),
    jsonb_build_object('scheduled', false));
$$;

grant execute on function public.owner_guest_cleanup_schedule() to authenticated;
