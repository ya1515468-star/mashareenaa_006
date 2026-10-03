-- Message colors: free starter palette + premium store palette.
-- Server-authoritative selection is exposed through set_my_message_color().
alter table public.profile_cosmetic_catalog drop constraint if exists profile_cosmetic_catalog_category_check;
alter table public.profile_cosmetic_catalog add constraint profile_cosmetic_catalog_category_check check (category = any (array['frame','background','name_effect','message_color']));
alter table public.profiles add column if not exists message_color bigint default 4294967295;
update public.profiles set message_color=4294967295 where message_color is null or message_color=4278190080;
alter table public.profiles alter column message_color set default 4294967295;

create or replace function public.set_my_message_color(p_item_key text)
returns void language plpgsql security definer set search_path=public as $function$
declare v_uid uuid:=auth.uid(); v_key text:=nullif(trim(coalesce(p_item_key,'')),''); v_item record; v_color bigint; v_owner boolean:=coalesce(public.is_my_platform_owner(),false);
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if v_key is null then update public.profiles set message_color=4294967295,updated_at=now() where id=v_uid; return; end if;
 select item_key,color1,price_points,price_gems,owner_free,is_active into v_item from public.profile_cosmetic_catalog where item_key=v_key and category='message_color' and is_active=true;
 if not found then raise exception 'MESSAGE_COLOR_NOT_AVAILABLE'; end if;
 begin v_color:=('x'||lpad(replace(v_item.color1,'#',''),8,'F'))::bit(32)::bigint; exception when others then raise exception 'INVALID_MESSAGE_COLOR'; end;
 if not v_owner and not coalesce(v_item.owner_free,false) and not exists(select 1 from public.profile_cosmetic_purchases p where p.user_id=v_uid and p.item_key=v_key) then raise exception 'ITEM_NOT_OWNED'; end if;
 update public.profiles set message_color=v_color,updated_at=now() where id=v_uid;
 if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
end;$function$;

grant execute on function public.set_my_message_color(text) to authenticated;

create or replace function public.get_message_color_catalog()
returns setof public.profile_cosmetic_catalog language sql stable security definer set search_path=public as $function$
 select * from public.profile_cosmetic_catalog where category='message_color' and is_active=true order by sort_order,item_key;
$function$;
grant execute on function public.get_message_color_catalog() to anon,authenticated;
