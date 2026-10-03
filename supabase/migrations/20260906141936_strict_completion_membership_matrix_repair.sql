-- Repair membership mapping against the sparse 1..16 / 101..120 catalog ordering.
begin;
with tiers as (select * from (values ('bronze',5),('silver',10),('gold',15),('diamond',20),('royal',25),('vip',30),('legendary',34),('ultimate',36)) t(tier_id,max_services)), ranked as (select feature_key,row_number() over(order by sort_order,feature_key) rn from public.profile_service_catalog where is_active=true)
delete from public.subscription_tier_service_rules where tier_id in (select tier_id from tiers);
with tiers as (select * from (values ('bronze',5),('silver',10),('gold',15),('diamond',20),('royal',25),('vip',30),('legendary',34),('ultimate',36)) t(tier_id,max_services)), ranked as (select feature_key,row_number() over(order by sort_order,feature_key) rn from public.profile_service_catalog where is_active=true)
insert into public.subscription_tier_service_rules(tier_id,feature_key,included,purchase_separately,temporary,enabled)
select t.tier_id,r.feature_key,true,false,true,true from tiers t join ranked r on r.rn<=t.max_services;
commit;
