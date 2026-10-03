-- Compatibility migration matching the production reconciliation history.
-- The legacy client-priced RPC is revoked again before its definitive removal.
begin;
revoke all on function public.purchase_and_equip_vip_cosmetic(text,integer,integer) from public,anon,authenticated,service_role;
commit;
