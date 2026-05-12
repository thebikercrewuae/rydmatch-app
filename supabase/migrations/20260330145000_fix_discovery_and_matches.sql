-- Fix 1: Auto-create user_profiles row when a new auth user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
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

-- Fix 2: Ensure RLS is enabled on matches and add all required policies
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own matches
DROP POLICY IF EXISTS "users_can_read_own_matches" ON public.matches;
CREATE POLICY "users_can_read_own_matches"
ON public.matches
FOR SELECT
TO authenticated
USING (user_id = auth.uid() OR matched_user_id = auth.uid());

-- Allow users to create matches
DROP POLICY IF EXISTS "users_can_insert_matches" ON public.matches;
CREATE POLICY "users_can_insert_matches"
ON public.matches
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid() OR matched_user_id = auth.uid());

-- Allow users to delete their own matches
DROP POLICY IF EXISTS "users_can_delete_own_matches" ON public.matches;
CREATE POLICY "users_can_delete_own_matches"
ON public.matches
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- Fix 3: Ensure user_profiles SELECT policy exists (re-apply idempotently)
DROP POLICY IF EXISTS "users_can_read_all_profiles" ON public.user_profiles;
CREATE POLICY "users_can_read_all_profiles"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (true);

-- Fix 4: Backfill any existing auth users that don't have a profile row yet
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
        RAISE NOTICE 'Backfill failed: %', SQLERRM;
END $$;
