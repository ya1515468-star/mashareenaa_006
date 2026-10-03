-- Strict completion: keep helper functions non-public while sensitive RPCs stay authenticated-only.
begin;
revoke all on function public._active_membership_tier_id(uuid) from public,anon,authenticated;
revoke all on function public._membership_includes_service(uuid,text) from public,anon,authenticated;
revoke all on function public.purchase_profile_service(text,text,uuid) from public,anon;
grant execute on function public.purchase_profile_service(text,text,uuid) to authenticated;
commit;
