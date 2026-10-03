-- MASHAREENA strict document finalization
-- Server-authoritative visual contract used by the Flutter renderer.
create or replace function public.get_active_name_animation(p_user_id uuid)
returns jsonb language sql stable security definer set search_path to '' as $$
  select case when c.effect_key is null then null else jsonb_build_object(
    'effect_key',c.effect_key,'name_ar',c.name_ar,'category',c.category,'asset_path',c.asset_path,
    'asset_url',c.asset_url,'storage_path',c.storage_path,'size_bytes',c.size_bytes,
    'animation_type',c.animation_type,'fps',c.fps,'duration_ms',c.duration_ms,'max_width',c.max_width,
    'max_height',c.max_height,'transparent',c.transparent,'loop',c.loop,'price_points',c.price_points,
    'price_gems',c.price_gems,'owner_free',c.owner_free,'is_active',c.is_active,'sort_order',c.sort_order,
    'metadata',c.metadata,'animation_json',c.animation_json
  ) end
  from public.user_name_animation_effects e
  join public.name_animation_catalog c on c.effect_key=e.effect_key and c.is_active=true
  where e.user_id=p_user_id and e.is_active=true limit 1;
$$;

update public.name_animation_catalog
set asset_path='catalog://name-animations/'||effect_key||'.json',
    size_bytes=greatest(size_bytes,octet_length(coalesce(animation_json::text,''))),
    updated_at=now()
where is_active=true and animation_json is not null;

create or replace function public.admin_lookup_user_identity(p_identifier text,p_identifier_type text default 'uid')
returns jsonb language plpgsql security definer set search_path to '' as $$
declare v_uid uuid; v_identifier text:=trim(coalesce(p_identifier,'')); v_type text:=lower(trim(coalesce(p_identifier_type,'uid'))); v_profile record; v_identity jsonb; v_title text; v_title_key text;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 if not (public.is_platform_owner(auth.uid()) or private.has_permission('users.read')) then raise exception 'FORBIDDEN'; end if;
 if v_identifier='' then raise exception 'IDENTIFIER_REQUIRED'; end if;
 if v_type not in ('uid','id') then raise exception 'INVALID_IDENTIFIER_TYPE'; end if;
 begin v_uid:=v_identifier::uuid; exception when invalid_text_representation then raise exception 'INVALID_UID_ID'; end;
 select p.* into v_profile from public.profiles p where p.id=v_uid;
 if not found then raise exception 'USER_NOT_FOUND'; end if;
 v_identity:=public.get_user_chat_identity(v_uid,null);
 select c.title_key,c.name_ar into v_title_key,v_title from public.user_titles u join public.user_title_catalog c on c.title_key=u.title_key where u.user_id=v_uid and u.is_active=true and c.is_active=true limit 1;
 return jsonb_build_object('user_id',v_profile.id,'auth_uid',v_profile.id,'username',v_profile.username,'display_name',v_profile.display_name,'avatar_url',v_profile.avatar_url,'rank',coalesce(v_identity->'rank'->>'name','مبتدئ'),'role',coalesce(v_identity->'role'->>'name','زائر'),'title_key',v_title_key,'title',v_title,'country',v_profile.country,'city',v_profile.city,'latitude',v_profile.location_latitude,'longitude',v_profile.location_longitude,'location_updated_at',v_profile.location_updated_at,'username_font_size',v_profile.username_font_size,'username_color',v_profile.username_color,'username_effect',coalesce(v_identity->>'username_effect','none'));
end; $$;

create or replace function public.get_user_visual_profile(p_user_id uuid)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare v_identity jsonb; v_animal jsonb; v_profile record; v_title record;
begin
 if p_user_id is null then raise exception 'USER_ID_REQUIRED'; end if;
 select p.* into v_profile from public.profiles p where p.id=p_user_id and p.is_active=true and p.is_suspended=false;
 if not found then return null; end if;
 v_identity:=public.get_user_chat_identity(p_user_id,null);
 select c.title_key,c.name_ar,c.icon_url into v_title from public.user_titles u join public.user_title_catalog c on c.title_key=u.title_key where u.user_id=p_user_id and u.is_active=true and c.is_active=true limit 1;
 v_animal:=public.get_active_name_animation(p_user_id);
 return jsonb_build_object('id',v_profile.id,'uid',v_profile.id,'username',v_profile.username,'displayName',v_profile.display_name,'avatarUrl',v_profile.avatar_url,'usernameColor',v_profile.username_color,'usernameGlow',coalesce(v_profile.username_shine,false),'usernameFontSize',v_profile.username_font_size,'usernameAnimalEffectKey',case when v_animal is null then null else v_animal->>'effect_key' end,'usernameAnimal',v_animal,'title',case when v_title.title_key is null then null else jsonb_build_object('key',v_title.title_key,'name_ar',v_title.name_ar,'icon_url',v_title.icon_url) end,'rank',coalesce(v_identity->'rank',jsonb_build_object('name','مبتدئ')),'country',v_profile.country,'city',v_profile.city,'latitude',v_profile.location_latitude,'longitude',v_profile.location_longitude,'locationUpdatedAt',v_profile.location_updated_at);
end; $$;

grant execute on function public.get_user_visual_profile(uuid) to authenticated;
grant execute on function public.admin_lookup_user_identity(text,text) to authenticated;
grant execute on function public.get_active_name_animation(uuid) to authenticated;
