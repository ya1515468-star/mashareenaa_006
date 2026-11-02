-- ============================================================
-- حساب الزائر — المنع الخادمي ولوحة تحكم المالك
--
-- «كل شيء ينفَّذ خادميًا ويُحفظ»: القرار هنا لا في التطبيق. لو
-- عُدّل التطبيق أو نوديت الـAPI مباشرةً، يُرفض الطلب من الخادم.
-- التطبيق يقرأ المفاتيح ليُطفئ الأزرار فقط — راحةً للمستخدم، لا
-- حمايةً.
--
-- الدالتان أدناه تُعاد كتابتهما بجسمهما المنشور حرفيًا، والإضافة
-- هي الحارس في أول السطور فقط.
-- ============================================================

-- ── 1) من يملك تبديل صلاحيات الزائر؟ المالك أو السوبر أدمن ──
create or replace function public.can_manage_guest_settings()
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select public._is_platform_owner(auth.uid())
      or exists (
        select 1
          from public.user_roles ur
          join public.roles r on r.id = ur.role_id
         where ur.user_id = auth.uid()
           and r.code in ('dragon','super_admin')
      );
$$;

-- ── 2) الخاص: المنع داخل دالة الإرسال نفسها ──
create or replace function private_rpc.send_chat_message(
  p_to_uid uuid,
  p_text text,
  p_type text default 'text',
  p_media_url text default null,
  p_thumbnail_url text default null,
  p_media_duration_seconds integer default null,
  p_reply_to_id uuid default null,
  p_reply_to_preview text default null,
  p_reply_to_sender_uid uuid default null,
  p_metadata jsonb default null
)
returns public.chat_messages
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE
  v_uid uuid:=auth.uid(); v_thread_id text; v_message public.chat_messages; v_meta jsonb:=coalesce(p_metadata,'{}'::jsonb);
  v_effect text; v_font double precision; v_color bigint; v_animated text; v_frame_key text;
  v_bg_key text; v_bg_mode text; v_bg_c1 text; v_bg_c2 text; v_bg_opacity double precision; v_bg_outer text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;

  -- حارس الزائر: الخاص مغلق افتراضيًا ويفتحه المالك من feature_flags
  -- (guest_private_chat). العضو المسجَّل يمرّ دائمًا بلا أي أثر.
  IF NOT public.guest_can('guest_private_chat') THEN
    RAISE EXCEPTION 'GUEST_FEATURE_LOCKED: %',
      public.guest_lock_message('guest_private_chat');
  END IF;

  -- رفع الوسائط في الخاص يخضع لمفتاحه المستقل.
  IF p_media_url IS NOT NULL AND NOT public.guest_can('guest_uploads') THEN
    RAISE EXCEPTION 'GUEST_FEATURE_LOCKED: %',
      public.guest_lock_message('guest_uploads');
  END IF;

  IF p_to_uid IS NULL OR p_to_uid=v_uid THEN RAISE EXCEPTION 'INVALID_PARTICIPANT'; END IF;
  IF nullif(trim(coalesce(p_text,'')),'') IS NULL AND p_media_url IS NULL THEN RAISE EXCEPTION 'EMPTY_MESSAGE'; END IF;
  IF p_type NOT IN ('text','emoji','gif','image','video','audio','file','product','project','quote','invoice','order','call','gift','system') THEN RAISE EXCEPTION 'INVALID_MESSAGE_TYPE'; END IF;
  v_thread_id:=least(v_uid::text,p_to_uid::text)||'_'||greatest(v_uid::text,p_to_uid::text);
  INSERT INTO public.chat_threads(id,type,participant_uids,last_message_text,last_message_sender_uid,last_message_at,unread_counts,updated_at)
  VALUES(v_thread_id,'direct',array[v_uid::text,p_to_uid::text],trim(coalesce(p_text,'')),v_uid,now(),jsonb_build_object(v_uid::text,0,p_to_uid::text,1),now())
  ON CONFLICT(id) DO UPDATE SET participant_uids=excluded.participant_uids,last_message_text=excluded.last_message_text,last_message_sender_uid=excluded.last_message_sender_uid,last_message_at=excluded.last_message_at,updated_at=now(),
    unread_counts=jsonb_set(coalesce(public.chat_threads.unread_counts,'{}'::jsonb),array[p_to_uid::text],to_jsonb(coalesce((public.chat_threads.unread_counts->>p_to_uid::text)::int,0)+1),true),
    hidden_for_uids=array_remove(array_remove(coalesce(public.chat_threads.hidden_for_uids,'{}'),p_to_uid::text),v_uid::text);
  SELECT coalesce(gs.username_effect,'none'),p.username_font_size,p.username_color,p.animated_avatar_url,p.avatar_frame_key,
         p.username_background_key,p.username_background_mode,p.username_background_color1,p.username_background_color2,p.username_background_opacity,p.username_background_external_effect
  INTO v_effect,v_font,v_color,v_animated,v_frame_key,v_bg_key,v_bg_mode,v_bg_c1,v_bg_c2,v_bg_opacity,v_bg_outer
  FROM public.profiles p LEFT JOIN public.gamification_stats gs ON gs.user_id=p.id WHERE p.id=v_uid;
  v_meta=jsonb_set(v_meta,'{username_effect}',to_jsonb(coalesce(v_effect,'none')),true);
  v_meta=jsonb_set(v_meta,'{username_font_size}',to_jsonb(coalesce(v_font,22)),true);
  v_meta=jsonb_set(v_meta,'{username_color}',coalesce(to_jsonb(v_color),'null'::jsonb),true);
  v_meta=jsonb_set(v_meta,'{username_shine}',to_jsonb(false),true);
  v_meta=jsonb_set(v_meta,'{animated_avatar_url}',to_jsonb(coalesce(v_animated,'')),true);
  v_meta=jsonb_set(v_meta,'{avatar_frame_key}',to_jsonb(coalesce(v_frame_key,'')),true);
  v_meta=jsonb_set(v_meta,'{username_background_key}',to_jsonb(coalesce(v_bg_key,'')),true);
  v_meta=jsonb_set(v_meta,'{username_background_mode}',to_jsonb(coalesce(v_bg_mode,'')),true);
  v_meta=jsonb_set(v_meta,'{username_background_color1}',to_jsonb(coalesce(v_bg_c1,'')),true);
  v_meta=jsonb_set(v_meta,'{username_background_color2}',to_jsonb(coalesce(v_bg_c2,'')),true);
  v_meta=jsonb_set(v_meta,'{username_background_opacity}',to_jsonb(coalesce(v_bg_opacity,.82)),true);
  v_meta=jsonb_set(v_meta,'{username_background_external_effect}',to_jsonb(coalesce(v_bg_outer,'')),true);
  INSERT INTO public.chat_messages(thread_id,sender_uid,type,text,media_url,thumbnail_url,media_duration_seconds,status,reply_to_id,reply_to_preview,reply_to_sender_uid,metadata)
  VALUES(v_thread_id,v_uid,p_type,trim(coalesce(p_text,'')),p_media_url,p_thumbnail_url,p_media_duration_seconds,'sent',p_reply_to_id,p_reply_to_preview,p_reply_to_sender_uid,v_meta)
  RETURNING * INTO v_message;
  RETURN v_message;
END;
$function$;

-- ── 3) المكالمات: المنع داخل دالة بدء المكالمة ──
create or replace function private_rpc.start_call(p_callee_uid uuid, p_type text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_call_id uuid := gen_random_uuid();
  v_now timestamptz := pg_catalog.now();
  v_payload jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;

  -- حارس الزائر: المكالمات مغلقة افتراضيًا (guest_calls).
  if not public.guest_can('guest_calls') then
    raise exception 'GUEST_FEATURE_LOCKED: %',
      public.guest_lock_message('guest_calls');
  end if;

  if p_callee_uid is null or p_callee_uid = v_uid then raise exception 'INVALID_RECIPIENT'; end if;
  if lower(trim(coalesce(p_type,''))) not in ('voice','video') then raise exception 'INVALID_CALL_TYPE'; end if;
  if not public.has_profile_service_for_user(v_uid,'voice_video_calls') then
    raise exception 'FEATURE_REQUIRED_VOICE_VIDEO';
  end if;
  if not exists(select 1 from auth.users where id=p_callee_uid) then
    raise exception 'RECIPIENT_NOT_FOUND';
  end if;

  v_payload := jsonb_build_object(
    'id',v_call_id::text,
    'callerUid',v_uid::text,
    'calleeUid',p_callee_uid::text,
    'participants',jsonb_build_array(v_uid::text,p_callee_uid::text),
    'type',lower(trim(p_type)),
    'status','ringing',
    'createdAt',v_now,
    'updatedAt',v_now
  );

  insert into public.app_documents(collection_path,doc_id,owner_id,data)
  values('calls',v_call_id::text,v_uid,v_payload);

  return v_payload;
end;
$function$;

-- ── 4) لوحة تحكم المالك/السوبر أدمن ──
-- القراءة: كل مفاتيح الزائر بحالتها ورسائلها.
create or replace function public.owner_get_guest_settings()
returns table (
  flag_key text,
  is_enabled boolean,
  name_ar text,
  disabled_message_ar text,
  updated_at timestamptz,
  updated_by uuid
)
language sql
stable
security definer
set search_path to ''
as $$
  select f.flag_key, f.is_enabled, f.name_ar, f.disabled_message_ar,
         f.updated_at, f.updated_by
    from public.feature_flags f
   where f.flag_key like 'guest\_%'
   order by f.flag_key;
$$;

-- التبديل: مقصور على مفاتيح الزائر، ومقصور على المالك أو السوبر
-- أدمن، ويُسجَّل من غيّره ومتى (updated_by/updated_at + audit_logs).
create or replace function public.owner_set_guest_feature(
  p_flag_key text,
  p_enabled boolean,
  p_disabled_message_ar text default null
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_key text := trim(coalesce(p_flag_key,''));
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.can_manage_guest_settings() then raise exception 'FORBIDDEN'; end if;
  if v_key not like 'guest\_%' then raise exception 'NOT_A_GUEST_FLAG'; end if;
  if not exists (select 1 from public.feature_flags f where f.flag_key = v_key) then
    raise exception 'UNKNOWN_FLAG';
  end if;

  update public.feature_flags f
     set is_enabled = coalesce(p_enabled, f.is_enabled),
         disabled_message_ar =
           coalesce(nullif(trim(coalesce(p_disabled_message_ar,'')),''),
                    f.disabled_message_ar),
         updated_at = now(),
         updated_by = v_uid
   where f.flag_key = v_key;

  insert into public.audit_logs(
    actor_user_id, actor_id, action, resource_type, resource_id,
    target_id, result, metadata)
  values (v_uid, v_uid, 'GUEST_FEATURE_UPDATED', 'feature_flags', v_key,
          v_key, 'success',
          jsonb_build_object('enabled', p_enabled));

  return jsonb_build_object('ok', true, 'flag_key', v_key, 'enabled', p_enabled);
end;
$function$;

-- ── 5) ما يحتاجه التطبيق لإطفاء الأزرار ──
-- استدعاء واحد يُرجع: هل أنا زائر؟ وأي الميزات مفتوحة لي؟
create or replace function public.get_my_guest_state()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select jsonb_build_object(
    'is_guest', public.is_guest(),
    'features', coalesce((
      select jsonb_object_agg(
               f.flag_key,
               jsonb_build_object(
                 'allowed', public.guest_can(f.flag_key),
                 'message', public.guest_lock_message(f.flag_key)))
        from public.feature_flags f
       where f.flag_key like 'guest\_%'
    ), '{}'::jsonb)
  );
$$;

grant execute on function public.is_guest() to authenticated;
grant execute on function public.guest_can(text) to authenticated;
grant execute on function public.guest_lock_message(text) to authenticated;
grant execute on function public.get_my_guest_state() to authenticated;
grant execute on function public.can_manage_guest_settings() to authenticated;
grant execute on function public.owner_get_guest_settings() to authenticated;
grant execute on function public.owner_set_guest_feature(text, boolean, text) to authenticated;
grant execute on function public.profile_age(date) to authenticated;
