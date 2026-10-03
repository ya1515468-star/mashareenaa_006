alter table public.profiles add column if not exists member_badge_id uuid;
do $$ begin
  if not exists (select 1 from pg_constraint where conname='profiles_member_badge_id_fkey' and conrelid='public.profiles'::regclass) then
    alter table public.profiles add constraint profiles_member_badge_id_fkey foreign key(member_badge_id) references public.member_badge_catalog(id) on delete set null;
  end if;
end $$;
create index if not exists profiles_member_badge_id_idx on public.profiles(member_badge_id);
-- New member badges use member_badge_id; legacy chat_badge_id remains reserved for the legacy catalog.
