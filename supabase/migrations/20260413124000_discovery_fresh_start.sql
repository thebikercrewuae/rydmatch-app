-- Fresh start for discovery: clean slate on policies and RPC function

-- 1. Ensure RLS is enabled
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- 2. Drop ALL existing policies on user_profiles to eliminate conflicts
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE tablename = 'user_profiles' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.user_profiles', pol.policyname);
  END LOOP;
END $$;

-- 3. Create clean, minimal policies
-- Any authenticated user can read any profile (required for discovery)
CREATE POLICY "discovery_select_all"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (true);

-- Users can insert their own profile
CREATE POLICY "discovery_insert_own"
ON public.user_profiles
FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- Users can update their own profile
CREATE POLICY "discovery_update_own"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Users can delete their own profile
CREATE POLICY "discovery_delete_own"
ON public.user_profiles
FOR DELETE
TO authenticated
USING (id = auth.uid());

-- 4. Drop and recreate the discovery RPC function cleanly
DROP FUNCTION IF EXISTS public.get_discovery_profiles(UUID, UUID[]);
DROP FUNCTION IF EXISTS public.get_discovery_profiles(UUID, TEXT[]);

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
  -- Ensure the calling user has a profile row (belt-and-suspenders)
  INSERT INTO public.user_profiles (id)
  VALUES (p_current_user_id)
  ON CONFLICT (id) DO NOTHING;

  RETURN QUERY
  SELECT
    up.id,
    COALESCE(up.full_name, split_part(COALESCE(up.email, ''), '@', 1))::TEXT,
    COALESCE(up.email, '')::TEXT,
    COALESCE(up.skill_levels, ARRAY[]::TEXT[]),
    COALESCE(up.bike_types, ARRAY[]::TEXT[]),
    COALESCE(up.preferred_roads, ARRAY[]::TEXT[]),
    COALESCE(up.riding_speed, 60.0)::DOUBLE PRECISION,
    up.gender::TEXT,
    up.avatar_url::TEXT,
    COALESCE(up.bio, '')::TEXT,
    up.latitude::DOUBLE PRECISION,
    up.longitude::DOUBLE PRECISION
  FROM public.user_profiles up
  WHERE up.id != p_current_user_id
    AND (array_length(p_excluded_ids, 1) IS NULL OR up.id != ALL(p_excluded_ids))
  ORDER BY up.created_at DESC NULLS LAST
  LIMIT 500;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.get_discovery_profiles(UUID, UUID[]) TO authenticated;

-- 5. Ensure handle_new_user trigger exists and is correct
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 6. Backfill ALL existing auth users that don't have a profile row
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
      COALESCE(auth_user.raw_user_meta_data->>'full_name', split_part(COALESCE(auth_user.email, ''), '@', 1))
    )
    ON CONFLICT (id) DO NOTHING;
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Backfill error: %', SQLERRM;
END $$;
