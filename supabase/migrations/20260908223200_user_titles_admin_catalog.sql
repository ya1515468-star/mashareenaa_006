create or replace function public.create_user_title(
  p_title_key text,p_name_ar text,p_request_id uuid,p_icon_url text default null,p_sort_order integer default 0
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_id uuid;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
 if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
 if exists(select 1 from public.audit_logs where action='user_title_catalog_create' and request_id=p_request_id and result='success') then
   select nullif(resource_id,'')::uuid into v_id from public.audit_logs where action='user_title_catalog_create' and request_id=p_request_id and result='success' limit 1;
   return v_id;
 end if;
 if nullif(trim(p_title_key),'') is null then raise exception 'TITLE_KEY_REQUIRED'; end if;
 if nullif(trim(p_name_ar),'') is null then raise exception 'NAME_REQUIRED'; end if;
 if exists(select 1 from public.user_title_catalog where title_key=lower(trim(p_title_key))) then raise exception 'TITLE_KEY_EXISTS'; end if;
 insert into public.user_title_catalog(title_key,name_ar,icon_url,is_active,sort_order,created_by)
 values(lower(trim(p_title_key)),left(trim(p_name_ar),80),nullif(trim(p_icon_url),''),true,greatest(0,coalesce(p_sort_order,0)),v_uid)
 returning id into v_id;
 insert into public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
 values(v_uid,v_uid,'user_title_catalog_create','user_title_catalog',v_id::text,v_id::text,p_request_id,'success',jsonb_build_object('title_key',lower(trim(p_title_key))));
 return v_id;
end; $$;

create or replace function public.update_user_title_catalog(
  p_title_id uuid,p_title_key text,p_name_ar text,p_icon_url text,p_sort_order integer,p_request_id uuid
) returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
 if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
 if exists(select 1 from public.audit_logs where action='user_title_catalog_update' and request_id=p_request_id and result='success') then return; end if;
 update public.user_title_catalog set title_key=lower(trim(p_title_key)),name_ar=left(trim(p_name_ar),80),icon_url=nullif(trim(p_icon_url),''),sort_order=greatest(0,coalesce(p_sort_order,0)),updated_at=now() where id=p_title_id;
 if not found then raise exception 'TITLE_NOT_FOUND'; end if;
 insert into public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
 values(v_uid,v_uid,'user_title_catalog_update','user_title_catalog',p_title_id::text,p_title_id::text,p_request_id,'success',jsonb_build_object('title_key',lower(trim(p_title_key))));
end; $$;

create or replace function public.set_user_title_catalog_active(p_title_id uuid,p_is_active boolean,p_request_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
 if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
 update public.user_title_catalog set is_active=coalesce(p_is_active,false),updated_at=now() where id=p_title_id;
 if not found then raise exception 'TITLE_NOT_FOUND'; end if;
 if not coalesce(p_is_active,false) then update public.user_titles set is_active=false,updated_at=now() where title_key=(select title_key from public.user_title_catalog where id=p_title_id) and is_active=true; end if;
 insert into public.audit_logs(actor_user_id,actor_id,action,resource_type,resource_id,target_id,request_id,result,metadata)
 values(v_uid,v_uid,case when p_is_active then 'user_title_catalog_activate' else 'user_title_catalog_archive' end,'user_title_catalog',p_title_id::text,p_title_id::text,p_request_id,'success','{}'::jsonb);
end; $$;

create or replace function public.list_user_titles_for_admin()
returns setof public.user_title_catalog language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
 return query select * from public.user_title_catalog order by sort_order,created_at desc;
end; $$;

revoke execute on function public.create_user_title(text,text,uuid,text,integer) from public,anon; grant execute on function public.create_user_title(text,text,uuid,text,integer) to authenticated;
revoke execute on function public.update_user_title_catalog(uuid,text,text,text,integer,uuid) from public,anon; grant execute on function public.update_user_title_catalog(uuid,text,text,text,integer,uuid) to authenticated;
revoke execute on function public.set_user_title_catalog_active(uuid,boolean,uuid) from public,anon; grant execute on function public.set_user_title_catalog_active(uuid,boolean,uuid) to authenticated;
revoke execute on function public.list_user_titles_for_admin() from public,anon; grant execute on function public.list_user_titles_for_admin() to authenticated;
