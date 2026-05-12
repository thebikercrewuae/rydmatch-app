-- Complete discovery fix: ensure all users are visible in discovery

-- 1. Ensure RLS is enabled on user_profiles
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- 2. Drop and recreate the SELECT policy to guarantee all authenticated users can read all profiles
DROP POLICY IF EXISTS "users_can_read_all_profiles" ON public.user_profiles;
CREATE POLICY "users_can_read_all_profiles"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (true);

-- 3. Ensure upsert (INSERT + UPDATE) policy exists for own profile
DROP POLICY IF EXISTS "users_manage_own_user_profiles" ON public.user_profiles;
CREATE POLICY "users_manage_own_user_profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- 4. Backfill any auth users missing a profile row
DO $$
DECLARE
    auth_user RECORD;
BEGIN
    FOR auth_user IN
        SELECT au.id, au.email, au.raw_user_meta_data
        FROM auth.users au
        LEFT JOIN public.user_profiles up ON au.id = up.id
        WHERE up.id IS NULL
    LOOP
        INSERT INTO public.user_profiles (id, email, full_name)
        VALUES (
            auth_user.id,
            auth_user.email,
            COALESCE(auth_user.raw_user_meta_data->>'full_name', split_part(auth_user.email, '@', 1))
        )
        ON CONFLICT (id) DO NOTHING;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Backfill skipped: %', SQLERRM;
END $$;

-- 5. Add missing columns if not present (idempotent)
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS skill_levels TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS bike_types TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS preferred_roads TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS riding_speed DOUBLE PRECISION DEFAULT 60.0,
  ADD COLUMN IF NOT EXISTS gender TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMPTZ;

-- 6. Index for discovery queries
CREATE INDEX IF NOT EXISTS idx_user_profiles_discovery
  ON public.user_profiles(id)
  WHERE id IS NOT NULL;
