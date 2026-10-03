create or replace function public.create_member_badge(p_badge_key text,p_name_ar text,p_category text,p_description text,p_asset_path text,p_asset_url text,p_file_size_bytes bigint,p_width integer,p_height integer,p_metadata jsonb default '{}'::jsonb,p_sort_order integer default 0,p_request_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_uid uuid:=auth.uid(); v_existing text;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
 if p_request_id is not null then
   select resource_id into v_existing from public.audit_logs where action='member_badge_create' and request_id=p_request_id and result='success' limit 1;
   if v_existing is not null then return v_existing::uuid; end if;
 end if;
 if nullif(trim(p_badge_key),'') is null then raise exception 'BADGE_KEY_REQUIRED'; end if;
 if nullif(trim(p_name_ar),'') is null then raise exception 'NAME_REQUIRED'; end if;
 if lower(trim(p_asset_path)) not like 'badges/v1/%.gif' then raise exception 'GIF_REQUIRED'; end if;
 if nullif(trim(p_asset_url),'') is null then raise exception 'ASSET_URL_REQUIRED'; end if;
 if coalesce(p_file_size_bytes,0) <= 0 or p_file_size_bytes > 524288 then raise exception 'GIF_TOO_LARGE'; end if;
 if exists(select 1 from public.member_badge_catalog where badge_key=lower(trim(p_badge_key))) then raise exception 'BADGE_KEY_EXISTS'; end if;
 insert into public.member_badge_catalog(badge_key,name_ar,category,description,asset_path,asset_url,mime_type,file_size_bytes,width,height,is_active,sort_order,metadata,created_by)
 values(lower(trim(p_badge_key)),left(trim(p_name_ar),80),coalesce(nullif(trim(p_category),''),'general'),nullif(trim(p_description),''),trim(p_asset_path),left(trim(p_asset_url),2048),'image/gif',p_file_size_bytes,p_width,p_height,true,greatest(0,coalesce(p_sort_order,0)),coalesce(p_metadata,'{}'::jsonb),v_uid)
 returning id into v_id;
 insert into public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
 values(v_uid,v_uid,'member_badge_create','member_badge_catalog',v_id::text,v_id::text,p_request_id,'success',jsonb_build_object('badge_key',lower(trim(p_badge_key))));
 return v_id;
end; $$;

create or replace function public.update_member_badge_catalog(p_badge_id uuid,p_badge_key text,p_name_ar text,p_category text,p_description text,p_asset_path text,p_asset_url text,p_file_size_bytes bigint,p_width integer,p_height integer,p_metadata jsonb default '{}'::jsonb,p_sort_order integer default 0,p_request_id uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
 if p_request_id is not null and exists(select 1 from public.audit_logs where action='member_badge_update' and request_id=p_request_id and result='success') then return; end if;
 if p_badge_id is null then raise exception 'BADGE_REQUIRED'; end if;
 if nullif(trim(p_badge_key),'') is null then raise exception 'BADGE_KEY_REQUIRED'; end if;
 if lower(trim(p_asset_path)) not like 'badges/v1/%.gif' then raise exception 'GIF_REQUIRED'; end if;
 if nullif(trim(p_asset_url),'') is null then raise exception 'ASSET_URL_REQUIRED'; end if;
 if coalesce(p_file_size_bytes,0) <= 0 or p_file_size_bytes > 524288 then raise exception 'GIF_TOO_LARGE'; end if;
 update public.member_badge_catalog set badge_key=lower(trim(p_badge_key)),name_ar=left(trim(p_name_ar),80),category=coalesce(nullif(trim(p_category),''),'general'),description=nullif(trim(p_description),''),asset_path=trim(p_asset_path),asset_url=left(trim(p_asset_url),2048),mime_type='image/gif',file_size_bytes=p_file_size_bytes,width=p_width,height=p_height,sort_order=greatest(0,coalesce(p_sort_order,0)),metadata=coalesce(p_metadata,'{}'::jsonb),updated_at=now() where id=p_badge_id;
 if not found then raise exception 'BADGE_NOT_FOUND'; end if;
 update public.profiles p set chat_badge_url=b.asset_url,updated_at=now() from public.user_member_badges u join public.member_badge_catalog b on b.id=u.badge_id where u.user_id=p.id and u.badge_id=p_badge_id and u.is_active=true;
 insert into public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata) values(v_uid,v_uid,'member_badge_update','member_badge_catalog',p_badge_id::text,p_badge_id::text,p_request_id,'success',jsonb_build_object('badge_key',lower(trim(p_badge_key))));
end; $$;

create or replace function public.set_member_badge_active(p_badge_id uuid,p_is_active boolean,p_request_id uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_action text;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
 v_action:=case when coalesce(p_is_active,false) then 'member_badge_activate' else 'member_badge_archive' end;
 if p_request_id is not null and exists(select 1 from public.audit_logs where action=v_action and request_id=p_request_id and result='success') then return; end if;
 update public.member_badge_catalog set is_active=coalesce(p_is_active,false),updated_at=now() where id=p_badge_id;
 if not found then raise exception 'BADGE_NOT_FOUND'; end if;
 if not coalesce(p_is_active,false) then
   update public.user_member_badges set is_active=false,updated_at=now() where badge_id=p_badge_id and is_active=true;
   update public.profiles set chat_badge_id=null,chat_badge_url=null,updated_at=now() where chat_badge_id=p_badge_id;
 end if;
 insert into public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata) values(v_uid,v_uid,v_action,'member_badge_catalog',p_badge_id::text,p_badge_id::text,p_request_id,'success','{}'::jsonb);
end; $$;

create or replace function public.clear_user_member_badge(p_user_id uuid,p_request_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
 if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
 if exists(select 1 from public.audit_logs where action='member_badge_clear' and request_id=p_request_id and result='success') then return; end if;
 perform pg_advisory_xact_lock(hashtextextended(coalesce(p_user_id::text,''),0));
 update public.user_member_badges set is_active=false,updated_at=now() where user_id=p_user_id and is_active=true;
 update public.profiles set chat_badge_id=null,chat_badge_url=null,updated_at=now() where id=p_user_id;
 insert into public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
 values(v_uid,v_uid,'member_badge_clear','user_member_badges',p_user_id::text,p_user_id::text,p_request_id,'success','{}'::jsonb);
end; $$;
