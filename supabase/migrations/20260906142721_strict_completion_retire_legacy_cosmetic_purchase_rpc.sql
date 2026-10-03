-- Strict completion: retire the obsolete client-priced cosmetic purchase RPC.
-- The canonical purchase path is purchase_profile_cosmetic(p_item_key,p_currency,p_request_id).
begin;
revoke all on function public.purchase_and_equip_vip_cosmetic(text,integer,integer) from public,anon,authenticated,service_role;
commit;
