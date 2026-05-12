-- Complete discovery overhaul: use a SECURITY DEFINER RPC function
-- that bypasses RLS entirely so all users are always visible.

-- 1. Ensure required columns exist on user_profiles
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

-- 2. Drop any conflicting RLS policies and recreate clean ones
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_can_read_all_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "users_manage_own_user_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "allow_read_all_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "allow_own_profile_write" ON public.user_profiles;
DROP POLICY IF EXISTS "profiles_select_policy" ON public.user_profiles;
DROP POLICY IF EXISTS "profiles_insert_policy" ON public.user_profiles;
DROP POLICY IF EXISTS "profiles_update_policy" ON public.user_profiles;

-- Allow any authenticated user to read any profile
CREATE POLICY "profiles_select_all"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (true);

-- Allow users to insert their own profile
CREATE POLICY "profiles_insert_own"
ON public.user_profiles
FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- Allow users to update their own profile
CREATE POLICY "profiles_update_own"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- 3. Create a SECURITY DEFINER function that returns all profiles
--    except the calling user and any blocked users.
--    This bypasses RLS completely so discovery always works.
CREATE OR REPLACE FUNCTION public.get_discovery_profiles(
  p_current_user_id UUID,
  p_excluded_ids UUID[] DEFAULT ARRAY[]::UUID[]
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email TEXT,
  skill_levels TEXT[],
  bike_types TEXT[],
  preferred_roads TEXT[],
  riding_speed DOUBLE PRECISION,
  gender TEXT,
  avatar_url TEXT,
  bio TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    up.id,
    up.full_name,
    up.email,
    COALESCE(up.skill_levels, ARRAY[]::TEXT[]),
    COALESCE(up.bike_types, ARRAY[]::TEXT[]),
    COALESCE(up.preferred_roads, ARRAY[]::TEXT[]),
    COALESCE(up.riding_speed, 60.0),
    up.gender,
    up.avatar_url,
    COALESCE(up.bio, ''),
    up.latitude,
    up.longitude
  FROM public.user_profiles up
  WHERE up.id != p_current_user_id
    AND up.id != ALL(p_excluded_ids)
  ORDER BY up.id
  LIMIT 500;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_discovery_profiles(UUID, UUID[]) TO authenticated;

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
