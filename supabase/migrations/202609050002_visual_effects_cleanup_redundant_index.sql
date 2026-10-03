-- Remove only the redundant index introduced by the first live deployment.
-- The ownership table already has the required unique primary key (user_id,item_key).
begin;
drop index if exists public.profile_cosmetic_purchases_user_item_uidx;
commit;
