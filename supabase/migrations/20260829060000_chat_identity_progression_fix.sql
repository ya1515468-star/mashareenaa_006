-- Chat identity + engagement progression hardening.
-- Owner/DRAGON is a platform role, not a normal progression rank.
-- Non-owner progression is server-authoritative and is earned from:
--   * chat participation (daily capped)
--   * online presence (daily capped)
--   * purchases (heavier weight, no client-side control)

create or replace function public.grant_xp_internal(
  p_user_id uuid,
  p_amount bigint,
  p_event_type text,
  p_reference_type text default null,
  p_reference_id text default null,
  p_idempotency_key uuid default null
)
returns bigint
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_before bigint;
  v_after bigint;
  v_grant bigint := greatest(coalesce(p_amount,0),0);
  v_today bigint := 0;
  v_xp_per_level integer := 100;
  v_rank_id text;
begin
  if p_user_id is null then raise exception 'USER_REQUIRED'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'INVALID_XP_AMOUNT'; end if;
  if p_event_type is null or trim(p_event_type) = '' then raise exception 'EVENT_TYPE_REQUIRED'; end if;

  if p_idempotency_key is not null and exists (
    select 1 from public.gamification_events
    where idempotency_key = p_idempotency_key
  ) then
    select xp into v_after
    from public.gamification_stats
    where user_id = p_user_id;
    return coalesce(v_after, 0);
  end if;

  -- Daily anti-spam caps apply only to activity XP.
  if p_event_type = 'chat_message' then
    select coalesce(sum(xp_amount),0) into v_today
    from public.gamification_events
    where user_id = p_user_id
      and event_type = 'chat_message'
      and created_at >= date_trunc('day', now());
    v_grant := least(v_grant, greatest(0, 100 - v_today));
  elsif p_event_type = 'presence_session' then
    select coalesce(sum(xp_amount),0) into v_today
    from public.gamification_events
    where user_id = p_user_id
      and event_type = 'presence_session'
      and created_at >= date_trunc('day', now());
    v_grant := least(v_grant, greatest(0, 60 - v_today));
  elsif p_event_type = 'purchase' then
    v_grant := least(v_grant, 1000);
  end if;

  if v_grant <= 0 then
    select xp into v_after from public.gamification_stats where user_id = p_user_id;
    return coalesce(v_after, 0);
  end if;

  select xp into v_before
  from public.gamification_stats
  where user_id = p_user_id
  for update;

  if not found then raise exception 'GAMIFICATION_STATS_NOT_FOUND'; end if;

  v_after := v_before + v_grant;

  select greatest(1, coalesce(xp_per_level,100))
    into v_xp_per_level
  from public.gamification_config
  where id = true;
  v_xp_per_level := greatest(1, coalesce(v_xp_per_level,100));

  v_rank_id := case
    when v_after >= 35000 then 'legend'
    when v_after >= 18000 then 'diamond'
    when v_after >= 9000 then 'platinum'
    when v_after >= 4000 then 'gold'
    when v_after >= 1500 then 'silver'
    when v_after >= 500 then 'bronze'
    else 'rookie'
  end;

  update public.gamification_stats
     set xp = v_after,
         rank_level = greatest(1, floor(v_after::numeric / v_xp_per_level)::integer + 1),
         rank_id = v_rank_id,
         updated_at = now()
   where user_id = p_user_id;

  insert into public.gamification_events (
    user_id,event_type,xp_amount,reference_type,reference_id,idempotency_key
  ) values (
    p_user_id,p_event_type,v_grant,p_reference_type,p_reference_id,p_idempotency_key
  );

  return v_after;
end;
$$;

create or replace function private.set_my_presence(
  p_is_online boolean,
  p_current_room_id uuid default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
  v_effective_online boolean;
  v_old_online boolean := false;
  v_old_started timestamptz;
  v_elapsed bigint := 0;
  v_presence_xp bigint := 0;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_current_room_id is not null and not exists(
    select 1 from public.chat_rooms r where r.id=p_current_room_id and r.is_active=true
  ) then raise exception 'ROOM_NOT_FOUND'; end if;

  select is_online,online_started_at
    into v_old_online,v_old_started
  from public.user_presence
  where user_id=v_uid;

  v_effective_online := p_is_online and not(
    public._can_hide_online_status(v_uid)
    and coalesce((select (data->>'appearOffline')::boolean
                  from public.app_documents
                  where collection_path='accounts' and doc_id=v_uid::text),false)
  );

  if v_old_online and not v_effective_online and v_old_started is not null then
    v_elapsed := greatest(0,extract(epoch from(now()-v_old_started))::bigint);
    if not public._is_platform_owner(v_uid) and v_elapsed >= 600 then
      -- 1 XP per 10 minutes, capped by the daily activity cap in grant_xp_internal.
      v_presence_xp := least(60,greatest(0,floor(v_elapsed/600.0)::bigint));
      if v_presence_xp > 0 then
        perform public.grant_xp_internal(
          v_uid,v_presence_xp,'presence_session',
          'presence',coalesce(p_current_room_id::text,'global'),gen_random_uuid()
        );
      end if;
    end if;
  end if;

  insert into public.user_presence(
    user_id,is_online,last_seen,updated_at,current_room_id,online_started_at,total_online_seconds
  ) values(
    v_uid,v_effective_online,now(),now(),
    case when v_effective_online then p_current_room_id else null end,
    case when v_effective_online then now() else null end,
    v_elapsed
  )
  on conflict(user_id) do update set
    is_online=excluded.is_online,
    last_seen=now(),
    updated_at=now(),
    current_room_id=excluded.current_room_id,
    online_started_at=case
      when excluded.is_online and not public.user_presence.is_online then now()
      when excluded.is_online then coalesce(public.user_presence.online_started_at,now())
      else null
    end,
    total_online_seconds=public.user_presence.total_online_seconds+excluded.total_online_seconds;
end;
$$;

create or replace function public.send_public_chat_message_v2(
  p_room_id uuid,
  p_message text,
  p_kind text default 'text',
  p_attachment_url text default null,
  p_reply_to_id uuid default null,
  p_reply_to_sender_uid uuid default null,
  p_reply_to_preview text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_request_id uuid default gen_random_uuid()
)
returns public.public_chat_messages
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.public_chat_messages;
  v_room public.chat_rooms;
  v_meta jsonb := coalesce(p_metadata,'{}'::jsonb);
  v_existing uuid;
  v_identity jsonb;
  v_display text;
  v_username text;
  v_avatar text;
  v_activity_xp bigint := 0;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_room_id is null then raise exception 'ROOM_REQUIRED'; end if;
  if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
  if nullif(trim(coalesce(p_message,'')),'') is null and p_attachment_url is null then raise exception 'EMPTY_MESSAGE'; end if;
  if p_kind not in ('text','emoji','gif','image','video','audio','file','gift') then raise exception 'INVALID_MESSAGE_TYPE'; end if;

  select * into v_room
  from public.chat_rooms
  where id=p_room_id and is_active=true;
  if v_room.id is null then raise exception 'ROOM_NOT_FOUND'; end if;

  perform public.sync_chat_member_ban_state(p_room_id,v_uid);

  if not v_room.is_public and not exists(
    select 1 from public.chat_room_members m
    where m.room_id=p_room_id and m.user_id=v_uid and coalesce(m.is_banned,false)=false
  ) then raise exception 'FORBIDDEN'; end if;

  if exists(
    select 1 from public.chat_room_penalties cp
    where cp.room_id=p_room_id and cp.user_id=v_uid and cp.is_active=true
      and cp.penalty_type in ('ban','mute','kick')
      and (cp.expires_at is null or cp.expires_at>now())
  ) then raise exception 'CHAT_RESTRICTED'; end if;

  select m.id into v_existing
  from public.public_chat_messages m
  where m.room_id=p_room_id and m.metadata->>'request_id'=p_request_id::text
  limit 1;
  if v_existing is not null then
    select * into v_row from public.public_chat_messages where id=v_existing;
    return v_row;
  end if;

  if p_reply_to_id is not null and not exists(
    select 1 from public.public_chat_messages m
    where m.id=p_reply_to_id and m.room_id=p_room_id
  ) then raise exception 'REPLY_TARGET_NOT_FOUND'; end if;

  select
    coalesce(nullif(trim(p.display_name),''),nullif(trim(p.username),''),'عضو'),
    p.username,p.avatar_url
  into v_display,v_username,v_avatar
  from public.profiles p where p.id=v_uid;

  v_identity := public.get_user_chat_identity(v_uid,p_room_id);
  v_meta := jsonb_set(v_meta,'{request_id}',to_jsonb(p_request_id::text),true);
  v_meta := jsonb_set(v_meta,'{username_color}',coalesce(v_identity->'username_color','null'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{username_shine}',coalesce(v_identity->'username_shine','false'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{username_font_size}',coalesce(v_identity->'username_font_size','16'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{username_effect}',coalesce(v_identity->'username_effect','"none"'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{avatar_frame_key}',coalesce(v_identity->'avatar_frame_key','""'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{username_background_key}',coalesce(v_identity->'username_background_key','""'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{username_background_mode}',coalesce(v_identity->'username_background_mode','""'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{username_background_color1}',coalesce(v_identity->'username_background_color1','""'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{username_background_color2}',coalesce(v_identity->'username_background_color2','""'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{username_background_opacity}',coalesce(v_identity->'username_background_opacity','0.82'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{username_background_external_effect}',coalesce(v_identity->'username_background_external_effect','""'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{chat_badge_url}',coalesce(v_identity->'chat_badge_url','null'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{achievement_badges}',coalesce(v_identity->'achievement_badges','[]'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{role}',coalesce(v_identity->'role','{}'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{rank}',coalesce(v_identity->'rank','{}'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{mention_user_ids}',coalesce(v_meta->'mention_user_ids','[]'::jsonb),true);
  v_meta := jsonb_set(v_meta,'{mention_user_names}',coalesce(v_meta->'mention_user_names','[]'::jsonb),true);

  insert into public.public_chat_messages(
    user_id,room_id,username,display_name,avatar_url,message,body,kind,
    attachment_url,reply_to_id,reply_to_sender_uid,reply_to_preview,metadata
  ) values(
    v_uid,p_room_id,v_username,v_display,v_avatar,
    trim(coalesce(p_message,'')),trim(coalesce(p_message,'')),p_kind,p_attachment_url,
    p_reply_to_id,p_reply_to_sender_uid,left(p_reply_to_preview,1000),v_meta
  ) returning * into v_row;

  if not public._is_platform_owner(v_uid) then
    v_activity_xp := case when p_kind='text' then 3 else 4 end;
    perform public.grant_xp_internal(
      v_uid,v_activity_xp,'chat_message','room_message',v_row.id::text,p_request_id
    );
  end if;

  return v_row;
end;
$$;

create or replace function private.award_purchase_xp_from_wallet_tx()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_purchase_xp bigint;
  v_reference text;
begin
  if new.amount >= 0 then return new; end if;
  if public._is_platform_owner(new.user_id) then return new; end if;

  if lower(coalesce(new.transaction_type,'')) like '%purchase%'
    or lower(coalesce(new.reference_type,'')) in (
      'store_item','profile_cosmetic','profile_product','profile_pattern','profile_service','profile_mini_store'
    ) then
    v_purchase_xp := greatest(5, least(1000, ceil(abs(new.amount)::numeric / 5)::bigint));
    v_reference := coalesce(new.reference_type || ':', '') || coalesce(new.reference_id, new.id::text);
    perform public.grant_xp_internal(
      new.user_id,v_purchase_xp,'purchase',coalesce(new.reference_type,'purchase'),v_reference,new.idempotency_key
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_wallet_purchase_xp on public.wallet_transactions;
create trigger trg_wallet_purchase_xp
after insert on public.wallet_transactions
for each row execute function private.award_purchase_xp_from_wallet_tx();

create or replace function public.purchase_membership(
  p_tier_id text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_tier jsonb;
  v_account jsonb;
  v_price bigint:=0;
  v_role_priority integer;
  v_existing jsonb;
  v_started timestamptz:=now();
  v_expires timestamptz;
  v_purchase_xp bigint:=0;
  v_response jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;

  select response into v_existing
  from public.idempotency_requests
  where request_id=p_request_id and user_id=v_uid;
  if v_existing is not null then return v_existing; end if;

  select data into v_tier
  from public.app_documents
  where collection_path='subscription_tiers' and doc_id=p_tier_id;
  if v_tier is null then raise exception 'TIER_NOT_FOUND'; end if;

  v_price:=coalesce((v_tier->>'priceMinorUnits')::bigint,0);
  v_expires:=now()+make_interval(days=>greatest(coalesce((v_tier->>'durationDays')::integer,30),1));

  select coalesce(max(r.priority),0) into v_role_priority
  from public.user_roles ur join public.roles r on r.id=ur.role_id
  where ur.user_id=v_uid;

  select data into v_account
  from public.app_documents
  where collection_path='accounts' and doc_id=v_uid::text
  for update;
  if v_account is null then v_account:='{}'::jsonb; end if;

  if v_role_priority < 500 and v_price > 0 then
    if coalesce((v_account->'wallet'->>'shamCashMinorUnits')::bigint,0) < v_price then raise exception 'INSUFFICIENT_BALANCE'; end if;
    v_account:=jsonb_set(v_account,'{wallet,shamCashMinorUnits}',to_jsonb((v_account->'wallet'->>'shamCashMinorUnits')::bigint-v_price),true);
  end if;

  v_account:=jsonb_set(v_account,'{subscription}',jsonb_build_object('tierId',p_tier_id,'startedAt',v_started,'expiresAt',v_expires),true);
  insert into public.app_documents(collection_path,doc_id,owner_id,data)
  values('accounts',v_uid::text,v_uid,v_account)
  on conflict(collection_path,doc_id) do update set owner_id=v_uid,data=excluded.data,updated_at=now();

  v_response:=jsonb_build_object('ok',true,'tierId',p_tier_id,'expiresAt',v_expires);
  insert into public.idempotency_requests(request_id,user_id,operation,response)
  values(p_request_id,v_uid,'purchase_membership',v_response);

  -- Membership purchase is intentionally weighted higher than routine activity.
  if not public._is_platform_owner(v_uid) and v_price > 0 then
    v_purchase_xp:=greatest(20,least(1000,ceil(v_price::numeric/100)::bigint));
    perform public.grant_xp_internal(v_uid,v_purchase_xp,'purchase','membership',p_tier_id,p_request_id);
  end if;

  perform public.write_audit('purchase_membership',p_tier_id,p_request_id,'success',jsonb_build_object('priceMinorUnits',v_price,'expiresAt',v_expires));
  return v_response;
end;
$$;

create or replace function public.announce_chat_welcome(
  p_room_id uuid,
  p_request_id uuid default gen_random_uuid()
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_message_id uuid;
  v_existing uuid;
  v_username text;
  v_avatar text;
  v_template text;
  v_image_url text;
  v_enabled boolean;
  v_text text;
  v_effect text;
  v_font double precision;
  v_color bigint;
  v_shine boolean;
  v_frame_key text;
  v_bg_key text;
  v_bg_mode text;
  v_bg_c1 text;
  v_bg_c2 text;
  v_bg_opacity double precision;
  v_bg_outer text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
  if not exists(select 1 from public.chat_rooms r where r.id=p_room_id and r.is_active=true) then raise exception 'ROOM_NOT_FOUND'; end if;
  if not exists(select 1 from public.chat_room_members m where m.room_id=p_room_id and m.user_id=v_uid and coalesce(m.is_banned,false)=false)
     and not coalesce((select r.is_public from public.chat_rooms r where r.id=p_room_id),false) then raise exception 'FORBIDDEN'; end if;

  select m.id into v_existing
  from public.public_chat_messages m
  where m.room_id=p_room_id and m.metadata->>'welcome_request_id'=p_request_id::text
  limit 1;
  if v_existing is not null then return v_existing; end if;

  insert into public.chat_welcome_settings(room_id) values(p_room_id) on conflict(room_id) do nothing;
  select message_template,image_url,is_enabled into v_template,v_image_url,v_enabled
  from public.chat_welcome_settings where room_id=p_room_id;
  if coalesce(v_enabled,true)=false then return null; end if;

  select coalesce(nullif(trim(p.username),''),nullif(trim(p.display_name),''),'عضو'),
         p.avatar_url,coalesce(gs.username_effect,'none'),p.username_font_size,p.username_color,
         p.username_shine,p.avatar_frame_key,p.username_background_key,p.username_background_mode,
         p.username_background_color1,p.username_background_color2,p.username_background_opacity,
         p.username_background_external_effect
  into v_username,v_avatar,v_effect,v_font,v_color,v_shine,v_frame_key,v_bg_key,v_bg_mode,v_bg_c1,v_bg_c2,v_bg_opacity,v_bg_outer
  from public.profiles p
  left join public.gamification_stats gs on gs.user_id=p.id
  where p.id=v_uid;

  if position('{username}' in coalesce(v_template,'')) = 0 then
    v_text := 'أهلًا وسهلًا يا {username}، ' || coalesce(nullif(trim(v_template),''),'نورت شات الخياطين نتمنى لك وقتًا جميلًا معنا');
  else
    v_text := coalesce(nullif(trim(v_template),''),'أهلًا وسهلًا يا {username}، نورت شات الخياطين نتمنى لك وقتًا جميلًا معنا');
  end if;
  v_text:=replace(v_text,'{username}',coalesce(v_username,'عضو'));

  insert into public.public_chat_messages(
    user_id,room_id,display_name,username,avatar_url,message,body,kind,metadata
  ) values(
    v_uid,p_room_id,'بوت الترحيب','welcome_bot',null,v_text,v_text,'system',
    jsonb_build_object(
      'system_event','welcome_bot','welcome_request_id',p_request_id::text,
      'target_user_id',v_uid::text,'target_username',v_username,
      'image_url',coalesce(v_image_url,''),'username_effect',coalesce(v_effect,'none'),
      'username_font_size',coalesce(v_font,16),'username_color',v_color,'username_shine',coalesce(v_shine,false),
      'avatar_frame_key',coalesce(v_frame_key,''),'username_background_key',coalesce(v_bg_key,''),
      'username_background_mode',coalesce(v_bg_mode,''),'username_background_color1',coalesce(v_bg_c1,''),
      'username_background_color2',coalesce(v_bg_c2,''),'username_background_opacity',coalesce(v_bg_opacity,.82),
      'username_background_external_effect',coalesce(v_bg_outer,'')
    )
  ) returning id into v_message_id;

  insert into public.chat_global_events(event_type,actor_uid,room_id,payload,expires_at)
  values(
    'welcome_bot',v_uid,p_room_id,
    jsonb_build_object(
      'message',v_text,'target_user_id',v_uid::text,'target_username',v_username,'actor_name',v_username,
      'image_url',coalesce(v_image_url,''),'username_effect',coalesce(v_effect,'none'),
      'username_font_size',coalesce(v_font,16),'username_color',v_color,'username_shine',coalesce(v_shine,false),
      'avatar_frame_key',coalesce(v_frame_key,''),'username_background_key',coalesce(v_bg_key,''),
      'username_background_mode',coalesce(v_bg_mode,''),'username_background_color1',coalesce(v_bg_c1,''),
      'username_background_color2',coalesce(v_bg_c2,''),'username_background_opacity',coalesce(v_bg_opacity,.82),
      'username_background_external_effect',coalesce(v_bg_outer,''),'duration_seconds',6
    ),
    now()+interval '6 seconds'
  );

  if public.is_my_profile_service('hide_join_announcement') then
    perform public.record_profile_service_use('hide_join_announcement',jsonb_build_object('action','welcome_announcement','room_id',p_room_id));
  end if;
  return v_message_id;
end;
$$;

-- Keep legacy rank APIs consistent with the canonical progression source.
create or replace function public.get_live_chat_rank_display(p_uid uuid)
returns jsonb
language sql
stable
set search_path to 'public'
as $$
select case
  when p_uid is null then jsonb_build_object('display_name','عضو','badge_url',null,'verified',false,'role_name','عضو','role_code','user','role_priority',0,'rank',0,'rank_level',1,'rank_id','rookie')
  when public._is_platform_owner(p_uid) then jsonb_build_object(
    'display_name',coalesce(p.display_name,p.username,'عضو'),'badge_url',p.chat_badge_url,'verified',p.verified,
    'role_name','مالك المنصة','role_code','dragon','role_priority',1000,'rank',0,'rank_level',null,'rank_id',null
  )
  else jsonb_build_object(
    'display_name',coalesce(p.display_name,p.username,'عضو'),'badge_url',p.chat_badge_url,'verified',p.verified,
    'role_name',coalesce(r.name,'عضو'),'role_code',coalesce(r.code,'user'),'role_priority',coalesce(r.priority,0),
    'rank',coalesce(gs.rank_level,1),'rank_level',coalesce(gs.rank_level,1),'rank_id',coalesce(gs.rank_id,'rookie')
  )
end
from public.profiles p
left join lateral (
  select r.name,r.code,r.priority
  from public.user_roles ur join public.roles r on r.id=ur.role_id
  where ur.user_id=p_uid
  order by r.priority desc limit 1
) r on true
left join public.gamification_stats gs on gs.user_id=p_uid
where p.id=p_uid;
$$;


create or replace function public.get_user_display_rank(
  p_user_id uuid,
  p_room_id uuid default null
)
returns jsonb
language sql
stable
set search_path to 'public'
as $$
select case
  when p_user_id is null then jsonb_build_object(
    'id','visitor','code','visitor','name','زائر','priority',0,'rank',0,
    'rank_level',1,'rank_id','rookie','scope','global','room_id',p_room_id
  )
  when public._is_platform_owner(p_user_id) then jsonb_build_object(
    'id','dragon','code','dragon','name','مالك المنصة','priority',1000,
    'rank',0,'rank_level',null,'rank_id',null,'scope','global','room_id',p_room_id
  )
  else jsonb_build_object(
    'id',coalesce(rr.code,'visitor'),'code',coalesce(rr.code,'visitor'),
    'name',coalesce(rr.name,'عضو'),'priority',coalesce(rr.priority,0),
    'rank',coalesce(gs.rank_level,1),'rank_level',coalesce(gs.rank_level,1),
    'rank_id',coalesce(gs.rank_id,'rookie'),
    'scope',case when cr.user_id is not null then 'room' else 'global' end,
    'room_id',p_room_id
  )
end
from (select p_user_id as user_id) x
left join public.gamification_stats gs on gs.user_id=x.user_id
left join lateral (
  select r.code,r.name,r.priority
  from public.user_roles ur join public.roles r on r.id=ur.role_id
  where ur.user_id=x.user_id
  order by coalesce(r.priority,0) desc
  limit 1
) rr on true
left join lateral (
  select m.user_id
  from public.chat_room_members m
  join public.chat_room_roles r2 on r2.id=m.role_id
  where p_room_id is not null and m.room_id=p_room_id and m.user_id=x.user_id
  order by coalesce(r2.priority,0) desc
  limit 1
) cr on true;
$$;
