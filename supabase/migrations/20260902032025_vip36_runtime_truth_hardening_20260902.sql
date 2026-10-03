-- VIP36 runtime truth hardening
-- 1) hide_join_announcement suppresses creation of the welcome message itself.
-- 2) profile_visitor_alerts creates a real notification after a visitor is recorded.

create or replace function public.announce_chat_welcome(p_room_id uuid, p_request_id uuid default gen_random_uuid())
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid:=auth.uid(); v_message_id uuid; v_existing uuid; v_display_name text; v_avatar text;
  v_template text; v_image_url text; v_enabled boolean; v_text text; v_effect text; v_font double precision;
  v_color bigint; v_shine boolean; v_frame_key text; v_bg_key text; v_bg_mode text; v_bg_c1 text;
  v_bg_c2 text; v_bg_opacity double precision; v_bg_outer text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
  if not exists(select 1 from public.chat_rooms r where r.id=p_room_id and r.is_active=true) then raise exception 'ROOM_NOT_FOUND'; end if;
  if not exists(select 1 from public.chat_room_members m where m.room_id=p_room_id and m.user_id=v_uid and coalesce(m.is_banned,false)=false)
     and not coalesce((select r.is_public from public.chat_rooms r where r.id=p_room_id),false) then raise exception 'FORBIDDEN'; end if;
  select m.id into v_existing from public.public_chat_messages m where m.room_id=p_room_id and m.metadata->>'welcome_request_id'=p_request_id::text limit 1;
  if v_existing is not null then return v_existing; end if;

  if public.is_my_profile_service('hide_join_announcement') then
    perform public.record_profile_service_use('hide_join_announcement',jsonb_build_object('action','welcome_announcement_suppressed','room_id',p_room_id));
    return null;
  end if;

  insert into public.chat_welcome_settings(room_id) values(p_room_id) on conflict(room_id) do nothing;
  select message_template,image_url,is_enabled into v_template,v_image_url,v_enabled from public.chat_welcome_settings where room_id=p_room_id;
  if coalesce(v_enabled,true)=false then return null; end if;
  select coalesce(nullif(trim(p.display_name),''),nullif(trim(p.username),''),'عضو'), p.avatar_url,coalesce(gs.username_effect,'none'),p.username_font_size,p.username_color,p.username_shine,p.avatar_frame_key,p.username_background_key,p.username_background_mode,p.username_background_color1,p.username_background_color2,p.username_background_opacity,p.username_background_external_effect into v_display_name,v_avatar,v_effect,v_font,v_color,v_shine,v_frame_key,v_bg_key,v_bg_mode,v_bg_c1,v_bg_c2,v_bg_opacity,v_bg_outer from public.profiles p left join public.gamification_stats gs on gs.user_id=p.id where p.id=v_uid;
  if position('{username}' in coalesce(v_template,'')) > 0 then v_text := replace(v_template,'{username}',coalesce(v_display_name,'عضو')); elsif nullif(trim(v_template),'') is not null then v_text := '✨ أهلًا وسهلًا يا ' || coalesce(v_display_name,'عضو') || ' في MASHAREENA 👑، ' || trim(v_template); else v_text := '✨ أهلًا وسهلًا يا ' || coalesce(v_display_name,'عضو') || ' في MASHAREENA 👑، نورت الغرفة. 🌟 نتمنى لك حضورًا جميلًا ووقتًا مليئًا بالمتعة والأصدقاء. 💎'; end if;
  insert into public.public_chat_messages(user_id,room_id,display_name,username,avatar_url,message,body,kind,metadata) values(v_uid,p_room_id,'بوت الترحيب','welcome_bot',null,v_text,v_text,'system',jsonb_build_object('system_event','welcome_bot','welcome_request_id',p_request_id::text,'target_user_id',v_uid::text,'target_username',v_display_name,'image_url',coalesce(v_image_url,''),'username_effect',coalesce(v_effect,'none'),'username_font_size',coalesce(v_font,16),'username_color',v_color,'username_shine',coalesce(v_shine,false),'avatar_frame_key',coalesce(v_frame_key,''),'username_background_key',coalesce(v_bg_key,''),'username_background_mode',coalesce(v_bg_mode,''),'username_background_color1',coalesce(v_bg_c1,''),'username_background_color2',coalesce(v_bg_c2,''),'username_background_opacity',coalesce(v_bg_opacity,.82),'username_background_external_effect',coalesce(v_bg_outer,''))) returning id into v_message_id;
  insert into public.chat_global_events(event_type,actor_uid,room_id,payload,expires_at) values('welcome_bot',v_uid,p_room_id,jsonb_build_object('message',v_text,'target_user_id',v_uid::text,'target_username',v_display_name,'actor_name',v_display_name,'image_url',coalesce(v_image_url,''),'username_effect',coalesce(v_effect,'none'),'username_font_size',coalesce(v_font,16),'username_color',v_color,'username_shine',coalesce(v_shine,false),'avatar_frame_key',coalesce(v_frame_key,''),'username_background_key',coalesce(v_bg_key,''),'username_background_mode',coalesce(v_bg_mode,''),'username_background_color1',coalesce(v_bg_c1,''),'username_background_color2',coalesce(v_bg_c2,''),'username_background_opacity',coalesce(v_bg_opacity,.82),'username_background_external_effect',coalesce(v_bg_outer,''),'duration_seconds',8),now()+interval '8 seconds');
  return v_message_id;
end;
$function$;

create or replace function public.notify_profile_visitor_vip()
returns trigger language plpgsql security definer set search_path to 'public' as $function$
declare v_name text;
begin
  select coalesce(nullif(trim(p.display_name),''),nullif(trim(p.username),''),'عضو') into v_name from public.profiles p where p.id=new.visitor_uid;
  insert into public.notifications(uid,type,title,body,related_id,actor_uid,is_read) values(new.profile_uid,'system','زائر جديد لملفك',coalesce(v_name,'عضو') || ' زار ملفك الشخصي عبر خدمة تنبيهات الزوار VIP.',new.visitor_uid::text,new.visitor_uid,false);
  return new;
end;
$function$;

drop trigger if exists trg_profile_visitor_vip_notification on public.profile_visitors;
create trigger trg_profile_visitor_vip_notification after insert on public.profile_visitors for each row execute function public.notify_profile_visitor_vip();
