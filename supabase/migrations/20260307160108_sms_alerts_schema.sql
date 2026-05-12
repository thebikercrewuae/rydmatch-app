-- SMS Alerts Schema: matches, ride_group_invites, urgent message tracking

-- 1. user_profiles table (if not exists) to store phone numbers
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    phone_number TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Add phone_number column if user_profiles already exists without it
ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- 2. matches table
CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    matched_user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    sms_sent BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_matches_user_id ON public.matches(user_id);
CREATE INDEX IF NOT EXISTS idx_matches_matched_user_id ON public.matches(matched_user_id);
CREATE INDEX IF NOT EXISTS idx_matches_created_at ON public.matches(created_at);

-- 3. ride_group_invites table
CREATE TABLE IF NOT EXISTS public.ride_group_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL,
    inviter_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    group_name TEXT NOT NULL DEFAULT 'Group Ride',
    sms_sent BOOLEAN DEFAULT false,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ride_group_invites_invitee_id ON public.ride_group_invites(invitee_id);
CREATE INDEX IF NOT EXISTS idx_ride_group_invites_group_id ON public.ride_group_invites(group_id);
CREATE INDEX IF NOT EXISTS idx_ride_group_invites_created_at ON public.ride_group_invites(created_at);

-- 4. Add is_urgent and sms_alert_sent columns to chat_messages (if not exists)
ALTER TABLE public.chat_messages
    ADD COLUMN IF NOT EXISTS is_urgent BOOLEAN DEFAULT false;

ALTER TABLE public.chat_messages
    ADD COLUMN IF NOT EXISTS sms_alert_sent BOOLEAN DEFAULT false;

-- 5. Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_group_invites ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies for user_profiles
DROP POLICY IF EXISTS "users_manage_own_user_profiles" ON public.user_profiles;
CREATE POLICY "users_manage_own_user_profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "service_role_all_user_profiles" ON public.user_profiles;
CREATE POLICY "service_role_all_user_profiles"
ON public.user_profiles
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- 7. RLS Policies for matches
DROP POLICY IF EXISTS "users_read_own_matches" ON public.matches;
CREATE POLICY "users_read_own_matches"
ON public.matches
FOR SELECT
TO authenticated
USING (user_id = auth.uid() OR matched_user_id = auth.uid());

DROP POLICY IF EXISTS "users_insert_matches" ON public.matches;
CREATE POLICY "users_insert_matches"
ON public.matches
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "service_role_all_matches" ON public.matches;
CREATE POLICY "service_role_all_matches"
ON public.matches
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- 8. RLS Policies for ride_group_invites
DROP POLICY IF EXISTS "users_read_own_invites" ON public.ride_group_invites;
CREATE POLICY "users_read_own_invites"
ON public.ride_group_invites
FOR SELECT
TO authenticated
USING (invitee_id = auth.uid() OR inviter_id = auth.uid());

DROP POLICY IF EXISTS "users_insert_invites" ON public.ride_group_invites;
CREATE POLICY "users_insert_invites"
ON public.ride_group_invites
FOR INSERT
TO authenticated
WITH CHECK (inviter_id = auth.uid());

DROP POLICY IF EXISTS "service_role_all_invites" ON public.ride_group_invites;
CREATE POLICY "service_role_all_invites"
ON public.ride_group_invites
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- 9. Trigger to auto-create user_profiles on new auth user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1))
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
