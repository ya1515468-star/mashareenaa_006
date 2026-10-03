-- MASHAREENA — baseline prerequisite bootstrap
--
-- WHAT THIS IS
-- Across the migrations in this folder, 52+ statements (going back to
-- 20260829035156) call `public.is_platform_owner(uuid)` — the one-argument
-- overload. That function is never created by any file in this
-- migrations/ folder. It almost certainly already exists on your live
-- production database (created directly via the SQL editor at some point,
-- before migrations were tracked), which is why production has been
-- working. But it means the migration history in this repo cannot rebuild
-- the project from an empty database: replaying these migrations in order
-- against a fresh Supabase project (new environment, staging, disaster
-- recovery) will fail at the very first CREATE POLICY that references it.
--
-- HOW TO USE THIS FILE
-- Run this ONCE, manually, against any environment BEFORE your first
-- `supabase db push` / migration replay:
--   - Existing production project: this is a guarded no-op. It checks
--     whether the function already exists (by signature) and does nothing
--     if so, so it will not override or change your current live
--     behavior. Safe to run, but not required, since production already
--     has it.
--   - Fresh/new project (staging, CI, disaster recovery): this creates a
--     minimal, safe version so the rest of the migration history can
--     apply cleanly.
--
-- WHY THIS IMPLEMENTATION
-- `public.is_platform_owner()` (zero-arg) already exists in the exported
-- migrations (see supabase/final_consolidated_production_reconciliation.sql)
-- and is itself defined as `SELECT public._is_platform_owner(auth.uid())`.
-- Every one of the 52+ call sites for the one-argument form passes an
-- explicit uid (auth.uid(), or a row's own user_id) where the zero-arg form
-- would only ever check the CURRENT caller. The only implementation
-- consistent with that existing convention is a thin parameterised wrapper
-- around the same underlying `_is_platform_owner`.
--
-- IMPORTANT — please double-check this against your live database
-- Because `_is_platform_owner`'s own source is not present anywhere in
-- this export either, this bootstrap cannot be 100% certain it matches
-- whatever your production database currently does. If you have database
-- access, we recommend confirming with:
--   SELECT pg_get_functiondef(oid) FROM pg_proc
--   WHERE proname IN ('is_platform_owner','_is_platform_owner');
-- and reconciling this file with the real definition before relying on it
-- for a fresh environment. We also recommend running a full
-- `supabase db pull` (or `pg_dump --schema-only`) at some point so this gap
-- (and the similar one for points_wallets / gems_wallets / wallet_transactions
-- / idempotency_requests — also referenced everywhere but never created in
-- this migrations/ folder) is closed permanently. See
-- NAME_ANIMATION_EXECUTION_REPORT.md for the full list.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'is_platform_owner' AND p.pronargs = 1
  ) THEN
    CREATE FUNCTION public.is_platform_owner(p_uid uuid)
    RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
    AS $fn$ SELECT public._is_platform_owner(p_uid) $fn$;

    REVOKE ALL ON FUNCTION public.is_platform_owner(uuid) FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.is_platform_owner(uuid) TO authenticated;

    RAISE NOTICE 'Created public.is_platform_owner(uuid) — this environment did not have it yet.';
  ELSE
    RAISE NOTICE 'public.is_platform_owner(uuid) already exists — no change made.';
  END IF;
END $$;
