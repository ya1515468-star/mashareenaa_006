-- MASHAREENA strict completion hardening
-- Membership catalog + 36-service entitlement resolution + server-side security.
begin;

create table if not exists public.subscription_tier_service_rules (
  tier_id text not null,
  feature_key text not null references public.profile_service_catalog(feature_key) on delete cascade,
  included boolean not null default false,
  purchase_separately boolean not null default true,
  owner_only boolean not null default false,
  vip_only boolean not null default false,
  temporary boolean not null default true,
  event_only boolean not null default false,
  duration_days integer,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (tier_id, feature_key)
);

alter table public.subscription_tier_service_rules enable row level security;
revoke all on table public.subscription_tier_service_rules from public, anon, authenticated;

-- Canonical server catalog. These values are the default production plans; owner RPCs may change them.
insert into public.app_documents(collection_path, doc_id, owner_id, data)
values
('subscription_tiers','bronze',null,'{"name":"البرونزية","description":"عضوية البرونزية لمدة 30 يومًا","priceMinorUnits":5000,"currency":"sham_cash","durationDays":30,"enabled":true,"displayOrder":1,"trial":false,"trialDays":0,"autoRenew":false,"level":1,"unlockedServiceCount":5}'::jsonb),
('subscription_tiers','silver',null,'{"name":"الفضية","description":"عضوية الفضية لمدة 30 يومًا","priceMinorUnits":10000,"currency":"sham_cash","durationDays":30,"enabled":true,"displayOrder":2,"trial":false,"trialDays":0,"autoRenew":false,"level":2,"unlockedServiceCount":10}'::jsonb),
('subscription_tiers','gold',null,'{"name":"الذهبية","description":"عضوية الذهبية لمدة 30 يومًا","priceMinorUnits":15000,"currency":"sham_cash","durationDays":30,"enabled":true,"displayOrder":3,"trial":false,"trialDays":0,"autoRenew":false,"level":3,"unlockedServiceCount":15}'::jsonb),
('subscription_tiers','diamond',null,'{"name":"الماسية","description":"عضوية الماسية لمدة 30 يومًا","priceMinorUnits":22000,"currency":"sham_cash","durationDays":30,"enabled":true,"displayOrder":4,"trial":false,"trialDays":0,"autoRenew":false,"level":4,"unlockedServiceCount":20}'::jsonb),
('subscription_tiers','royal',null,'{"name":"الملكية","description":"عضوية ملكية لمدة 30 يومًا","priceMinorUnits":30000,"currency":"sham_cash","durationDays":30,"enabled":true,"displayOrder":5,"trial":false,"trialDays":0,"autoRenew":false,"level":5,"unlockedServiceCount":25}'::jsonb),
('subscription_tiers','vip',null,'{"name":"VIP","description":"عضوية VIP لمدة 30 يومًا","priceMinorUnits":40000,"currency":"sham_cash","durationDays":30,"enabled":true,"displayOrder":6,"trial":false,"trialDays":0,"autoRenew":false,"level":6,"unlockedServiceCount":30}'::jsonb),
('subscription_tiers','legendary',null,'{"name":"النخبة الأسطورية","description":"عضوية النخبة الأسطورية لمدة 30 يومًا","priceMinorUnits":60000,"currency":"sham_cash","durationDays":30,"enabled":true,"displayOrder":7,"trial":false,"trialDays":0,"autoRenew":false,"level":7,"unlockedServiceCount":34}'::jsonb),
('subscription_tiers','ultimate',null,'{"name":"Ultimate","description":"عضوية Ultimate لمدة 30 يومًا","priceMinorUnits":85000,"currency":"sham_cash","durationDays":30,"enabled":true,"displayOrder":8,"trial":false,"trialDays":0,"autoRenew":false,"level":8,"unlockedServiceCount":36}'::jsonb)
on conflict (collection_path, doc_id) do update set data = public.app_documents.data || excluded.data, updated_at = now();

-- Default membership/service matrix. Owner can later override row-by-row through the RPC below.
with tiers as (
  select * from (values
    ('bronze',5),('silver',10),('gold',15),('diamond',20),('royal',25),('vip',30),('legendary',34),('ultimate',36)
  ) t(tier_id,max_services)
), services as (
  select feature_key, sort_order from public.profile_service_catalog where is_active=true
)
insert into public.subscription_tier_service_rules(tier_id,feature_key,included,purchase_separately,temporary,enabled)
select t.tier_id,s.feature_key,true,false,true,true
from tiers t join services s on s.sort_order <= t.max_services
on conflict (tier_id,feature_key) do update
set included=excluded.included,purchase_separately=excluded.purchase_separately,temporary=excluded.temporary,enabled=excluded.enabled,updated_at=now();

-- Authoritative active membership resolver. Expiration is evaluated from server time, not the client.
create or replace function public._active_membership_tier_id(p_uid uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when (a.data->'subscription'->>'tierId') is null then null
    when nullif(a.data->'subscription'->>'expiresAt','') is null then null
    when (a.data->'subscription'->>'expiresAt')::timestamptz <= pg_catalog.now() then null
    when coalesce((select (t.data->>'enabled')::boolean from public.app_documents t where t.collection_path='subscription_tiers' and t.doc_id=a.data->'subscription'->>'tierId'),false) = false then null
    else a.data->'subscription'->>'tierId'
  end
  from public.app_documents a
  where a.collection_path='accounts' and a.doc_id=p_uid::text
  limit 1
$$;

create or replace function public._membership_includes_service(p_uid uuid, p_feature_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.subscription_tier_service_rules r
    where r.tier_id = public._active_membership_tier_id(p_uid)
      and r.feature_key = trim(p_feature_key)
      and r.included = true
      and r.enabled = true
  )
$$;

-- Runtime authority: direct entitlement OR active membership OR platform owner.
create or replace function public.is_my_profile_service(p_feature_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.is_my_platform_owner(),false)
      or exists(select 1 from public.user_profile_services s where s.user_id=auth.uid() and s.feature_key=trim(p_feature_key) and s.enabled=true)
      or public._membership_includes_service(auth.uid(),p_feature_key)
$$;

create or replace function public.has_profile_service_for_user(p_user_id uuid, p_feature_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.is_my_platform_owner() and auth.uid()=p_user_id,false)
      or exists(select 1 from public.user_profile_services s where s.user_id=p_user_id and s.feature_key=trim(p_feature_key) and s.enabled=true)
      or public._membership_includes_service(p_user_id,p_feature_key)
$$;

create or replace function public.get_my_profile_services()
returns table(feature_key text,purchased_at timestamptz,currency text,amount bigint,enabled boolean,settings jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select feature_key,purchased_at,currency,amount,enabled,settings
  from public.user_profile_services
  where user_id=auth.uid()
  union
  select r.feature_key,
         coalesce((a.data->'subscription'->>'startedAt')::timestamptz,pg_catalog.now()),
         'membership',0,true,
         jsonb_build_object('source','membership','tierId',r.tier_id,'expiresAt',a.data->'subscription'->>'expiresAt')
  from public.subscription_tier_service_rules r
  join public.app_documents a
    on a.collection_path='accounts' and a.doc_id=auth.uid()::text
  where r.tier_id=public._active_membership_tier_id(auth.uid()) and r.included=true and r.enabled=true
  order by feature_key
$$;

create or replace function public.get_profile_service_runtime(p_feature_key text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid:=auth.uid(); v_key text:=trim(p_feature_key); v_owned boolean:=false; v_enabled boolean:=false;
  v_use_count bigint:=0; v_last_used_at timestamptz; v_settings jsonb:='{}'::jsonb; v_tier text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public._vip_feature_key_is_valid(v_key) then raise exception 'ITEM_NOT_FOUND'; end if;
  v_tier:=public._active_membership_tier_id(v_uid);
  v_owned:=public.is_my_platform_owner() or exists(select 1 from public.user_profile_services s where s.user_id=v_uid and s.feature_key=v_key)
            or public._membership_includes_service(v_uid,v_key);
  v_enabled:=public.is_my_platform_owner() or exists(select 1 from public.user_profile_services s where s.user_id=v_uid and s.feature_key=v_key and s.enabled=true)
            or public._membership_includes_service(v_uid,v_key);
  select coalesce(s.use_count,0),s.last_used_at,coalesce(s.settings,'{}'::jsonb)
    into v_use_count,v_last_used_at,v_settings
  from public.user_profile_services s where s.user_id=v_uid and s.feature_key=v_key;
  return jsonb_build_object('feature_key',v_key,'owned',v_owned,'enabled',v_enabled,'use_count',v_use_count,
      'last_used_at',v_last_used_at,'settings',v_settings,'membership_tier',v_tier);
end;
$$;

-- Server-authoritative membership purchase. Handles initial purchase, renewal, upgrade/downgrade,
-- idempotency and owner exemption without trusting client price or expiration.
create or replace function public.purchase_membership(p_tier_id text,p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid:=auth.uid(); v_tier jsonb; v_existing public.idempotency_requests%rowtype; v_account jsonb;
  v_price bigint; v_duration integer; v_old_tier text; v_old_expires timestamptz; v_started timestamptz; v_expires timestamptz;
  v_before bigint; v_after bigint; v_owner boolean:=false; v_response jsonb; v_same_active boolean:=false;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'REQUEST_ID_REQUIRED'; end if;
  select * into v_existing from public.idempotency_requests where request_id=p_request_id for update;
  if found then
    if v_existing.user_id<>v_uid or v_existing.operation<>'purchase_membership' then raise exception 'REQUEST_ID_REPLAY_FORBIDDEN'; end if;
    return v_existing.response;
  end if;
  select data into v_tier from public.app_documents where collection_path='subscription_tiers' and doc_id=trim(p_tier_id);
  if v_tier is null then raise exception 'TIER_NOT_FOUND'; end if;
  if coalesce((v_tier->>'enabled')::boolean,false)=false then raise exception 'SERVICE_DISABLED'; end if;
  v_price:=coalesce((v_tier->>'priceMinorUnits')::bigint,0);
  v_duration:=greatest(coalesce((v_tier->>'durationDays')::integer,30),1);
  if v_price<0 then raise exception 'INVALID_PRICE'; end if;
  select data into v_account from public.app_documents where collection_path='accounts' and doc_id=v_uid::text for update;
  if v_account is null then v_account:='{}'::jsonb; end if;
  v_old_tier:=v_account->'subscription'->>'tierId';
  v_old_expires:=nullif(v_account->'subscription'->>'expiresAt','')::timestamptz;
  v_same_active:=v_old_tier=trim(p_tier_id) and v_old_expires is not null and v_old_expires>pg_catalog.now();
  v_started:=case when v_same_active then v_old_expires else pg_catalog.now() end;
  v_expires:=v_started + (v_duration || ' days')::interval;
  v_owner:=public.is_platform_owner(v_uid);

  if not v_owner and v_price>0 then
    perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':membership:sham_cash',0));
    if not (v_account ? 'wallet') then v_account:=jsonb_set(v_account,'{wallet}','{}'::jsonb,true); end if;
    v_before:=coalesce((v_account->'wallet'->>'shamCashMinorUnits')::bigint,0);
    if v_before<v_price then raise exception 'INSUFFICIENT_BALANCE'; end if;
    v_after:=v_before-v_price;
    v_account:=jsonb_set(v_account,'{wallet,shamCashMinorUnits}',to_jsonb(v_after),true);
  end if;

  v_account:=jsonb_set(v_account,'{subscription}',jsonb_build_object('tierId',trim(p_tier_id),'startedAt',v_started,'expiresAt',v_expires,'status','active'),true);
  insert into public.app_documents(collection_path,doc_id,owner_id,data) values('accounts',v_uid::text,v_uid,v_account)
  on conflict(collection_path,doc_id) do update set owner_id=v_uid,data=excluded.data,updated_at=pg_catalog.now();

  if not v_owner and v_price>0 then
    insert into public.wallet_transactions(user_id,currency,amount,balance_before,balance_after,transaction_type,reference_type,reference_id,idempotency_key,metadata,created_by)
    values(v_uid,'sham_cash',-v_price,v_before,v_after,'membership_purchase','membership',trim(p_tier_id),p_request_id,
           jsonb_build_object('tier_id',trim(p_tier_id),'previous_tier',v_old_tier,'renewal',v_same_active),v_uid);
  end if;

  v_response:=jsonb_build_object('ok',true,'tierId',trim(p_tier_id),'expiresAt',v_expires,'startedAt',v_started,
     'renewal',v_same_active,'owner',v_owner,'requestId',p_request_id);
  insert into public.idempotency_requests(request_id,user_id,operation,response) values(p_request_id,v_uid,'purchase_membership',v_response);
  return v_response;
end;
$$;

-- Owner-only plan management; the caller never supplies authority or pricing to a purchase path.
create or replace function public.admin_upsert_membership_tier(
  p_tier_id text,p_name text,p_description text,p_price_minor_units bigint,p_currency text,
  p_duration_days integer,p_enabled boolean,p_display_order integer,p_trial boolean,p_trial_days integer,
  p_auto_renew boolean,p_level integer,p_unlocked_service_count integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid:=auth.uid(); v_data jsonb;
begin
  if v_uid is null or not public.is_my_platform_owner() then raise exception 'FORBIDDEN'; end if;
  if p_tier_id is null or trim(p_tier_id) !~ '^[a-z0-9][a-z0-9_-]{1,63}$' then raise exception 'INVALID_REQUEST'; end if;
  if nullif(trim(p_name),'') is null then raise exception 'INVALID_REQUEST'; end if;
  if p_price_minor_units<0 or p_price_minor_units>1000000000 then raise exception 'INVALID_PRICE'; end if;
  if lower(trim(p_currency))<>'sham_cash' then raise exception 'INVALID_CURRENCY'; end if;
  if p_duration_days<1 or p_duration_days>3650 then raise exception 'INVALID_REQUEST'; end if;
  if p_display_order<0 or p_display_order>10000 then raise exception 'INVALID_REQUEST'; end if;
  if p_trial_days<0 or p_trial_days>365 then raise exception 'INVALID_REQUEST'; end if;
  if p_level<1 or p_level>1000 then raise exception 'INVALID_REQUEST'; end if;
  if p_unlocked_service_count<0 or p_unlocked_service_count>36 then raise exception 'INVALID_REQUEST'; end if;
  v_data:=jsonb_build_object('name',trim(p_name),'description',coalesce(trim(p_description),''),'priceMinorUnits',p_price_minor_units,
    'currency','sham_cash','durationDays',p_duration_days,'enabled',p_enabled,'displayOrder',p_display_order,
    'trial',p_trial,'trialDays',p_trial_days,'autoRenew',p_auto_renew,'level',p_level,'unlockedServiceCount',p_unlocked_service_count,
    'updatedBy',v_uid::text);
  insert into public.app_documents(collection_path,doc_id,owner_id,data) values('subscription_tiers',trim(p_tier_id),null,v_data)
  on conflict(collection_path,doc_id) do update set data=excluded.data,updated_at=pg_catalog.now();
  -- Rebuild its default included-service matrix when requested.
  delete from public.subscription_tier_service_rules where tier_id=trim(p_tier_id);
  insert into public.subscription_tier_service_rules(tier_id,feature_key,included,purchase_separately,temporary,enabled)
  select trim(p_tier_id),c.feature_key,true,false,true,true
  from public.profile_service_catalog c where c.is_active=true and c.sort_order<=p_unlocked_service_count;
  return jsonb_build_object('ok',true,'tierId',trim(p_tier_id));
end;
$$;

-- Harden sensitive RPC execution surface: authenticated users only.
revoke all on function public.purchase_membership(text,uuid) from public,anon;
grant execute on function public.purchase_membership(text,uuid) to authenticated;
revoke all on function public.admin_upsert_membership_tier(text,text,text,bigint,text,integer,boolean,integer,boolean,integer,boolean,integer,integer) from public,anon,authenticated;
grant execute on function public.admin_upsert_membership_tier(text,text,text,bigint,text,integer,boolean,integer,boolean,integer,boolean,integer,integer) to authenticated;
revoke all on function public.purchase_and_equip_vip_cosmetic(text,integer,integer) from public,anon;
revoke all on function public.set_avatar_frame(text) from public,anon;
revoke all on function public.set_visual_effect(text,text) from public,anon;
revoke all on function public.purchase_profile_service(text,text,uuid) from public,anon;
revoke all on function public.activate_profile_service(text) from public,anon;
revoke all on function public.set_profile_service_enabled(text,boolean) from public,anon;
grant execute on function public.purchase_and_equip_vip_cosmetic(text,integer,integer),public.set_avatar_frame(text),public.set_visual_effect(text,text),public.purchase_profile_service(text,text,uuid),public.activate_profile_service(text),public.set_profile_service_enabled(text,boolean) to authenticated;

commit;
