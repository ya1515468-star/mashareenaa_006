-- Forward RPC privilege hardening applied to Supabase on 2026-09-08.
BEGIN;
DO $$ DECLARE r record; BEGIN FOR r IN SELECT n.nspname schema_name,p.proname function_name,pg_get_function_identity_arguments(p.oid) args FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname=''public'' AND p.prosecdef=true LOOP EXECUTE format(''REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM PUBLIC'',r.schema_name,r.function_name,r.args); EXECUTE format(''REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM anon'',r.schema_name,r.function_name,r.args); EXECUTE format(''GRANT EXECUTE ON FUNCTION %I.%I(%s) TO authenticated'',r.schema_name,r.function_name,r.args); END LOOP; END $$;
COMMIT;
