-- Strict completion: owner-only rule read, robust rank-based initial seeding, and helper execute hardening.
begin;
create or replace function public.admin_get_membership_service_rules(p_tier_id text)
returns table(feature_key text,included boolean,purchase_separately boolean,owner_only boolean,vip_only boolean,temporary boolean,event_only boolean,duration_days integer,enabled boolean)
language sql stable security definer set search_path='' as $$
 select r.feature_key,r.included,r.purchase_separately,r.owner_only,r.vip_only,r.temporary,r.event_only,r.duration_days,r.enabled
 from public.subscription_tier_service_rules r
 where r.tier_id=trim(p_tier_id)
   and public.is_my_platform_owner();
$$;
revoke all on function public.admin_get_membership_service_rules(text) from public,anon,authenticated;
grant execute on function public.admin_get_membership_service_rules(text) to authenticated;

create or replace function public.admin_upsert_membership_tier(p_tier_id text,p_name text,p_description text,p_price_minor_units bigint,p_currency text,p_duration_days integer,p_enabled boolean,p_display_order integer,p_trial boolean,p_trial_days integer,p_auto_renew boolean,p_level integer,p_unlocked_service_count integer default 0) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_data jsonb;v_exists boolean;
begin
 if v_uid is null or not public.is_my_platform_owner() then raise exception 'FORBIDDEN';end if;
 if p_tier_id is null or trim(p_tier_id)!~'^[a-z0-9][a-z0-9_-]{1,63}$' then raise exception 'INVALID_REQUEST';end if;
 if nullif(trim(p_name),'') is null then raise exception 'INVALID_REQUEST';end if;
 if p_price_minor_units<0 or p_price_minor_units>1000000000 then raise exception 'INVALID_PRICE';end if;
 if lower(trim(p_currency))<>'sham_cash' then raise exception 'INVALID_CURRENCY';end if;
 if p_duration_days<1 or p_duration_days>3650 or p_display_order<0 or p_display_order>10000 or p_trial_days<0 or p_trial_days>365 or p_level<1 or p_level>1000 or p_unlocked_service_count<0 or p_unlocked_service_count>36 then raise exception 'INVALID_REQUEST';end if;
 select exists(select 1 from public.app_documents where collection_path='subscription_tiers' and doc_id=trim(p_tier_id)) into v_exists;
 v_data:=jsonb_build_object('name',trim(p_name),'description',coalesce(trim(p_description),''),'priceMinorUnits',p_price_minor_units,'currency','sham_cash','durationDays',p_duration_days,'enabled',p_enabled,'displayOrder',p_display_order,'trial',p_trial,'trialDays',p_trial_days,'autoRenew',p_auto_renew,'level',p_level,'unlockedServiceCount',p_unlocked_service_count,'updatedBy',v_uid::text);
 insert into public.app_documents(collection_path,doc_id,owner_id,data) values('subscription_tiers',trim(p_tier_id),null,v_data) on conflict(collection_path,doc_id) do update set data=excluded.data,updated_at=pg_catalog.now();
 if not v_exists then
   insert into public.subscription_tier_service_rules(tier_id,feature_key,included,purchase_separately,temporary,enabled)
   select trim(p_tier_id),c.feature_key,true,false,true,true
   from (select feature_key,row_number() over(order by sort_order,feature_key) rn from public.profile_service_catalog where is_active=true) c
   where c.rn<=p_unlocked_service_count;
 end if;
 return jsonb_build_object('ok',true,'tierId',trim(p_tier_id),'created',not v_exists);
end; $$;
revoke all on function public.admin_upsert_membership_tier(text,text,text,bigint,text,integer,boolean,integer,boolean,integer,boolean,integer,integer) from public,anon,authenticated;grant execute on function public.admin_upsert_membership_tier(text,text,text,bigint,text,integer,boolean,integer,boolean,integer,boolean,integer,integer) to authenticated;

revoke all on function public._active_membership_tier_id(uuid) from public,anon,authenticated;
revoke all on function public._membership_includes_service(uuid,text) from public,anon,authenticated;
revoke all on function public.purchase_profile_service(text,text,uuid) from public,anon;
grant execute on function public.purchase_profile_service(text,text,uuid) to authenticated;
commit;
