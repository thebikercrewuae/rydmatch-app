-- Fix user discovery: add profile columns + RLS policies so users can find each other

-- 1. Add rider profile columns to user_profiles (idempotent)
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS skill_levels TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS bike_types TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS preferred_roads TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS riding_speed DOUBLE PRECISION DEFAULT 60.0,
  ADD COLUMN IF NOT EXISTS gender TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS is_profile_complete BOOLEAN DEFAULT false;

-- 2. RLS: allow authenticated users to read any profile (needed for discovery)
DROP POLICY IF EXISTS "users_can_read_all_profiles" ON public.user_profiles;
CREATE POLICY "users_can_read_all_profiles"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (true);

-- 3. RLS: allow users to insert/update their own profile
DROP POLICY IF EXISTS "users_manage_own_user_profiles" ON public.user_profiles;
CREATE POLICY "users_manage_own_user_profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- 4. Index for faster discovery queries
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_profile_complete
  ON public.user_profiles(is_profile_complete);
