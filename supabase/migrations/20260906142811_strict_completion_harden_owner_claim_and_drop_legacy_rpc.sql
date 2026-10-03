-- Strict completion: harden owner-claim helper and remove obsolete client-priced purchase RPC.
begin;
create or replace function public.is_platform_owner_claim() returns boolean
language sql stable set search_path=''
as $$
 select (auth.jwt() ->> 'user_role') = 'dragon'
    and (auth.jwt() ->> 'platform_owner') = 'true';
$$;
drop function if exists public.purchase_and_equip_vip_cosmetic(text,integer,integer);
commit;
