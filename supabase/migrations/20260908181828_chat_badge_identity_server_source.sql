-- Keep the existing server identity contract and add the explicit badge relation.
drop function if exists public.get_user_chat_identity(uuid,uuid);
create function public.get_user_chat_identity(p_user_id uuid,p_room_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=''
as $function$
declare
  v_profile record; v_stats record; v_badge record;
  v_global_role_code text; v_global_role_name text; v_global_role_priority integer:=0;
  v_room_role_code text; v_room_role_name text; v_room_role_priority integer:=0;
  v_role_code text; v_role_name text; v_role_priority integer:=0;
  v_rank_id text; v_rank_level integer:=1; v_manual_rank integer:=0; v_xp bigint:=0;
  v_rank_name text; v_rank_badge_key text; v_badges jsonb:='[]'::jsonb;
begin
  select p.id,p.username,p.display_name,p.avatar_url,p.animated_avatar_url,p.chat_badge_url,p.chat_badge_id,
    p.username_color,p.username_shine,p.username_font_size,p.username_font_family,p.message_color,p.message_font_family,
    p.status_text,p.status_color,p.status_font_size,p.status_bold,p.status_italic,p.username_background_key,p.username_background_mode,
    p.username_background_color1,p.username_background_color2,p.username_background_opacity,p.username_background_external_effect,
    p.avatar_frame_key,p.username_template_key
  into v_profile from public.profiles p where p.id=p_user_id and p.is_active=true and p.is_suspended=false;

  if p_user_id is null or v_profile.id is null then
    return jsonb_build_object('user_id',p_user_id,'username','عضو','display_name','عضو',
      'role',jsonb_build_object('code','visitor','name','زائر','priority',0,'scope','fallback','room_id',p_room_id),
      'rank',jsonb_build_object('id','rookie','level',1,'xp',0,'manual_rank',0,'name','مبتدئ','badge_key','rank_rookie'),
      'chat_badge',null,'chat_badge_url',null,'chat_badge_id',null,'chat_badge_name',null,'achievement_badges','[]'::jsonb,
      'status_text','','status_color',null,'status_font_size',12.5,'status_bold',false,'status_italic',false,
      'username_color',null,'username_shine',false,'username_font_size',22,'username_effect','none','username_template_key',null,
      'username_font_family','noto_kufi_arabic','message_color',4294967295,'message_font_family','cairo',
      'username_background_key',null,'username_background_mode',null,'username_background_color1',null,'username_background_color2',null,
      'username_background_opacity',0.82,'username_background_external_effect',null,'avatar_url',null,'animated_avatar_url',null,'avatar_frame_key',null);
  end if;

  select gs.xp,gs.rank_level,gs.rank_id,gs.manual_rank,gs.badges,gs.username_effect into v_stats
  from public.gamification_stats gs where gs.user_id=p_user_id;

  select b.id,b.name_ar,b.image_url,b.storage_path,b.is_active into v_badge
  from public.animated_chat_badges b where b.id=v_profile.chat_badge_id and b.is_active=true;

  if v_badge.id is null and nullif(trim(v_profile.chat_badge_url),'') is not null then
    select b.id,b.name_ar,b.image_url,b.storage_path,b.is_active into v_badge
    from public.animated_chat_badges b where b.image_url=v_profile.chat_badge_url and b.is_active=true
    order by b.created_at desc limit 1;
  end if;

  v_xp:=coalesce(v_stats.xp,0); v_rank_level:=greatest(coalesce(v_stats.rank_level,1),1);
  v_rank_id:=lower(coalesce(nullif(trim(v_stats.rank_id),''),'rookie')); v_manual_rank:=greatest(coalesce(v_stats.manual_rank,0),0);
  v_badges:=case when jsonb_typeof(coalesce(v_stats.badges,'[]'::jsonb))='array' then coalesce(v_stats.badges,'[]'::jsonb) else '[]'::jsonb end;

  if public._is_platform_owner(p_user_id) then
    v_role_code:='dragon'; v_role_name:='مالك المنصة'; v_role_priority:=1000;
  else
    if p_room_id is not null then
      select r.role_key,r.name,coalesce(r.priority,0) into v_room_role_code,v_room_role_name,v_room_role_priority
      from public.chat_room_members m join public.chat_room_roles r on r.id=m.role_id
      where m.room_id=p_room_id and m.user_id=p_user_id order by coalesce(r.priority,0) desc limit 1;
    end if;
    select r.code,r.name,coalesce(r.priority,0) into v_global_role_code,v_global_role_name,v_global_role_priority
    from public.user_roles ur join public.roles r on r.id=ur.role_id where ur.user_id=p_user_id
    order by coalesce(r.priority,0) desc limit 1;
    if v_room_role_code is not null then
      v_role_code:=v_room_role_code; v_role_name:=v_room_role_name; v_role_priority:=v_room_role_priority;
    elsif v_global_role_code is not null then
      v_role_code:=v_global_role_code; v_role_name:=v_global_role_name; v_role_priority:=v_global_role_priority;
    else v_role_code:='user'; v_role_name:='عضو'; v_role_priority:=0; end if;
  end if;

  if v_rank_id not in ('rookie','bronze','silver','gold','platinum','diamond','legend') then v_rank_id:='rookie'; end if;
  v_rank_name:=case v_rank_id when 'bronze' then 'برونزي' when 'silver' then 'فضي' when 'gold' then 'ذهبي' when 'platinum' then 'بلاتيني' when 'diamond' then 'ماسي' when 'legend' then 'أسطورة' else 'مبتدئ' end;
  v_rank_badge_key:='rank_'||v_rank_id;

  return jsonb_build_object('user_id',p_user_id,'username',v_profile.username,'display_name',v_profile.display_name,
    'role',jsonb_build_object('code',v_role_code,'name',v_role_name,'priority',v_role_priority,'scope',case when v_room_role_code is not null and v_role_code<>'dragon' then 'room' else 'global' end,'room_id',p_room_id),
    'rank',jsonb_build_object('id',v_rank_id,'level',v_rank_level,'xp',v_xp,'manual_rank',v_manual_rank,'name',v_rank_name,'badge_key',v_rank_badge_key),
    'chat_badge',case when v_badge.id is null then null else jsonb_build_object('id',v_badge.id::text,'name_ar',v_badge.name_ar,'url',v_badge.image_url,'storage_path',v_badge.storage_path) end,
    'chat_badge_url',case when v_badge.id is null then null else v_badge.image_url end,
    'chat_badge_id',case when v_badge.id is null then null else v_badge.id::text end,
    'chat_badge_name',case when v_badge.id is null then null else v_badge.name_ar end,
    'achievement_badges',v_badges,'status_text',coalesce(v_profile.status_text,''),'status_color',v_profile.status_color,
    'status_font_size',coalesce(v_profile.status_font_size,12.5),'status_bold',coalesce(v_profile.status_bold,false),'status_italic',coalesce(v_profile.status_italic,false),
    'username_color',v_profile.username_color,'username_shine',coalesce(v_profile.username_shine,false),'username_font_size',coalesce(v_profile.username_font_size,22),
    'username_effect',coalesce(nullif(trim(v_stats.username_effect),''),'none'),'username_template_key',v_profile.username_template_key,
    'username_font_family',coalesce(nullif(trim(v_profile.username_font_family),''),'noto_kufi_arabic'),'message_color',coalesce(v_profile.message_color,4294967295),
    'message_font_family',coalesce(nullif(trim(v_profile.message_font_family),''),'cairo'),'username_background_key',v_profile.username_background_key,
    'username_background_mode',v_profile.username_background_mode,'username_background_color1',v_profile.username_background_color1,'username_background_color2',v_profile.username_background_color2,
    'username_background_opacity',coalesce(v_profile.username_background_opacity,.82),'username_background_external_effect',v_profile.username_background_external_effect,
    'avatar_url',v_profile.avatar_url,'animated_avatar_url',v_profile.animated_avatar_url,'avatar_frame_key',v_profile.avatar_frame_key);
end;
$function$;

revoke execute on function public.list_chat_badges_for_admin() from public,anon;
grant execute on function public.list_chat_badges_for_admin() to authenticated;
revoke execute on function public.create_animated_chat_badge(text,text,text,integer) from public,anon;
grant execute on function public.create_animated_chat_badge(text,text,text,integer) to authenticated;
revoke execute on function public.update_animated_chat_badge(uuid,text,text,text,integer) from public,anon;
grant execute on function public.update_animated_chat_badge(uuid,text,text,text,integer) to authenticated;
revoke execute on function public.assign_chat_badge_to_user(uuid,uuid) from public,anon;
grant execute on function public.assign_chat_badge_to_user(uuid,uuid) to authenticated;
revoke execute on function public.set_my_chat_badge(uuid) from public,anon;
grant execute on function public.set_my_chat_badge(uuid) to authenticated;
revoke execute on function public.get_my_chat_badge() from public,anon;
grant execute on function public.get_my_chat_badge() to authenticated;
revoke execute on function public.get_user_chat_identity(uuid,uuid) from public,anon;
grant execute on function public.get_user_chat_identity(uuid,uuid) to authenticated;
