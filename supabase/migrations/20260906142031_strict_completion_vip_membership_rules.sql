-- Strict completion: owner-controlled per-membership VIP rules + membership-aware VIP purchase.
begin;

create or replace function public.admin_set_membership_service_rule(
  p_tier_id text,
  p_feature_key text,
  p_included boolean,
  p_purchase_separately boolean default true,
  p_owner_only boolean default false,
  p_vip_only boolean default false,
  p_temporary boolean default true,
  p_event_only boolean default false,
  p_duration_days integer default null,
  p_enabled boolean default true
) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null or not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
  if not exists(select 1 from public.app_documents where collection_path='subscription_tiers' and doc_id=trim(p_tier_id) and coalesce((data->>'enabled')::boolean,false)) then raise exception 'TIER_NOT_FOUND'; end if;
  if not exists(select 1 from public.profile_service_catalog where feature_key=trim(p_feature_key) and is_active=true) then raise exception 'ITEM_NOT_FOUND'; end if;
  if p_duration_days is not null and (p_duration_days<1 or p_duration_days>3650) then raise exception 'INVALID_REQUEST'; end if;
  insert into public.subscription_tier_service_rules(tier_id,feature_key,included,purchase_separately,owner_only,vip_only,temporary,event_only,duration_days,enabled)
  values(trim(p_tier_id),trim(p_feature_key),p_included,p_purchase_separately,p_owner_only,p_vip_only,p_temporary,p_event_only,p_duration_days,p_enabled)
  on conflict(tier_id,feature_key) do update set included=excluded.included,purchase_separately=excluded.purchase_separately,owner_only=excluded.owner_only,vip_only=excluded.vip_only,temporary=excluded.temporary,event_only=excluded.event_only,duration_days=excluded.duration_days,enabled=excluded.enabled,updated_at=pg_catalog.now();
  return jsonb_build_object('ok',true,'tierId',trim(p_tier_id),'featureKey',trim(p_feature_key),'included',p_included,'purchaseSeparately',p_purchase_separately,'enabled',p_enabled);
end;
$$;

create or replace function public.purchase_profile_service(p_feature_key text,p_currency text,p_request_id uuid default gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_key text:=trim(coalesce(p_feature_key,''));v_currency text:=lower(trim(coalesce(p_currency,'')));v_price bigint;v_before bigint;v_after bigint;v_owner uuid;v_existing record;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
 if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED';end if;
 if v_currency not in ('points','gems') then raise exception 'INVALID_CURRENCY';end if;
 if not exists(select 1 from public.profile_service_catalog c where c.feature_key=v_key and c.is_active=true) then raise exception 'ITEM_NOT_FOUND';end if;
 if public._membership_includes_service(v_uid,v_key) then return jsonb_build_object('ok',true,'feature_key',v_key,'amount',0,'currency','membership','included',true,'tierId',public._active_membership_tier_id(v_uid),'request_id',p_request_id);end if;
 select owner_id into v_owner from public.platform_owners order by owner_id limit 1;if v_owner is null then raise exception 'PLATFORM_OWNER_NOT_CONFIGURED';end if;
 select * into v_existing from public.profile_service_orders where request_id=p_request_id;
 if found then
   if v_existing.buyer_uid<>v_uid or v_existing.feature_key<>v_key or v_existing.currency<>v_currency then raise exception 'REQUEST_ID_REPLAY_FORBIDDEN';end if;
   return jsonb_build_object('ok',true,'feature_key',v_key,'amount',v_existing.amount,'currency',v_currency,'request_id',p_request_id,'idempotent',true);
 end if;
 perform pg_advisory_xact_lock(hashtextextended(v_uid::text||':vip:'||v_key,0));
 if public._is_platform_owner(v_uid) then
   insert into public.user_profile_services(user_id,feature_key,enabled,settings,purchased_at,updated_at,currency,amount) values(v_uid,v_key,true,case when v_key='self_destruct_chat' then jsonb_build_object('seconds',10) else '{}'::jsonb end,pg_catalog.now(),pg_catalog.now(),'owner_access',0)
   on conflict(user_id,feature_key) do update set enabled=true,updated_at=pg_catalog.now();
   return jsonb_build_object('ok',true,'feature_key',v_key,'owner_free',true,'request_id',p_request_id);
 end if;
 if exists(select 1 from public.user_profile_services where user_id=v_uid and feature_key=v_key) then update public.user_profile_services set enabled=true,updated_at=pg_catalog.now() where user_id=v_uid and feature_key=v_key;return jsonb_build_object('ok',true,'feature_key',v_key,'reactivated',true,'request_id',p_request_id);end if;
 select case when v_currency='points' then price_points else price_gems end into v_price from public.profile_service_catalog where feature_key=v_key and is_active=true;if v_price is null or v_price<=0 then raise exception 'PRICE_NOT_SET';end if;
 perform pg_advisory_xact_lock(hashtextextended(v_uid::text||':wallet:'||v_currency,0));
 if v_currency='points' then
  insert into public.points_wallets(user_id,balance) values(v_uid,0) on conflict(user_id) do nothing;select balance into v_before from public.points_wallets where user_id=v_uid for update;if coalesce(v_before,0)<v_price then raise exception 'INSUFFICIENT_POINTS';end if;v_after:=v_before-v_price;update public.points_wallets set balance=v_after,lifetime_spent=lifetime_spent+v_price,version=version+1,updated_at=pg_catalog.now() where user_id=v_uid;insert into public.points_wallets(user_id,balance) values(v_owner,0) on conflict(user_id) do nothing;update public.points_wallets set balance=balance+v_price,lifetime_earned=lifetime_earned+v_price,version=version+1,updated_at=pg_catalog.now() where user_id=v_owner;
 else
  insert into public.gems_wallets(user_id,balance) values(v_uid,0) on conflict(user_id) do nothing;select balance into v_before from public.gems_wallets where user_id=v_uid for update;if coalesce(v_before,0)<v_price then raise exception 'INSUFFICIENT_GEMS';end if;v_after:=v_before-v_price;update public.gems_wallets set balance=v_after,lifetime_spent=lifetime_spent+v_price,version=version+1,updated_at=pg_catalog.now() where user_id=v_uid;insert into public.gems_wallets(user_id,balance) values(v_owner,0) on conflict(user_id) do nothing;update public.gems_wallets set balance=balance+v_price,lifetime_earned=lifetime_earned+v_price,version=version+1,updated_at=pg_catalog.now() where user_id=v_owner;
 end if;
 insert into public.user_profile_services(user_id,feature_key,enabled,settings,purchased_at,updated_at,currency,amount) values(v_uid,v_key,true,case when v_key='self_destruct_chat' then jsonb_build_object('seconds',10) else '{}'::jsonb end,pg_catalog.now(),pg_catalog.now(),v_currency,v_price);
 insert into public.profile_service_orders(buyer_uid,feature_key,currency,amount,request_id) values(v_uid,v_key,v_currency,v_price,p_request_id);
 insert into public.wallet_transactions(user_id,currency,amount,balance_before,balance_after,transaction_type,reference_type,reference_id,idempotency_key,metadata,created_by) values(v_uid,v_currency,-v_price,v_before,v_after,'profile_service_purchase','profile_service',v_key,p_request_id,jsonb_build_object('feature_key',v_key),v_uid);
 return jsonb_build_object('ok',true,'feature_key',v_key,'amount',v_price,'currency',v_currency,'request_id',p_request_id,'owner_uid',v_owner::text);
end;
$$;

revoke all on function public.admin_set_membership_service_rule(text,text,boolean,boolean,boolean,boolean,boolean,boolean,integer,boolean) from public,anon,authenticated;
grant execute on function public.admin_set_membership_service_rule(text,text,boolean,boolean,boolean,boolean,boolean,boolean,integer,boolean) to authenticated;
revoke all on function public.purchase_profile_service(text,text,uuid) from public,anon;
grant execute on function public.purchase_profile_service(text,text,uuid) to authenticated;

commit;
