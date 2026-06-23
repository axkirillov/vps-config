-- Fix ownership of auth schema objects so GoTrue can manage them
-- The supabase/postgres image creates some auth objects as 'postgres',
-- but GoTrue connects as supabase_auth_admin and needs to be the owner.
DO $$
DECLARE
  r RECORD;
BEGIN
  -- Tables
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'auth'
  LOOP
    EXECUTE format('ALTER TABLE auth.%I OWNER TO supabase_auth_admin', r.tablename);
  END LOOP;
  -- Sequences
  FOR r IN SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = 'auth'
  LOOP
    EXECUTE format('ALTER SEQUENCE auth.%I OWNER TO supabase_auth_admin', r.sequence_name);
  END LOOP;
  -- Functions
  FOR r IN SELECT proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'auth'
  LOOP
    EXECUTE format('ALTER FUNCTION auth.%I(%s) OWNER TO supabase_auth_admin', r.proname, r.args);
  END LOOP;
END
$$;
ALTER SCHEMA auth OWNER TO supabase_auth_admin;

-- Ensure supabase_auth_admin has correct search_path
ALTER ROLE supabase_auth_admin SET search_path TO auth, public, extensions;
