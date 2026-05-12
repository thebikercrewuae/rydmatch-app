-- Referral System Migration
-- Tables: referral_codes, referral_tracking

-- 1. Create referral_codes table
CREATE TABLE IF NOT EXISTS public.referral_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    code TEXT NOT NULL UNIQUE,
    premium_trial_days INTEGER NOT NULL DEFAULT 7,
    total_referrals INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create referral_tracking table
CREATE TABLE IF NOT EXISTS public.referral_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referral_code_id UUID NOT NULL REFERENCES public.referral_codes(id) ON DELETE CASCADE,
    referrer_user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    referred_user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending',
    trial_days_awarded INTEGER NOT NULL DEFAULT 7,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_referred_user UNIQUE (referred_user_id)
);

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_referral_codes_user_id ON public.referral_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON public.referral_codes(code);
CREATE INDEX IF NOT EXISTS idx_referral_tracking_referrer ON public.referral_tracking(referrer_user_id);
CREATE INDEX IF NOT EXISTS idx_referral_tracking_referred ON public.referral_tracking(referred_user_id);

-- 4. Function: generate unique referral code
CREATE OR REPLACE FUNCTION public.generate_referral_code(user_uuid UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_code TEXT;
    code_exists BOOLEAN;
    attempts INTEGER := 0;
BEGIN
    LOOP
        -- Generate a 8-char alphanumeric code from user UUID + random
        new_code := UPPER(SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 8));
        SELECT EXISTS(SELECT 1 FROM public.referral_codes WHERE code = new_code) INTO code_exists;
        EXIT WHEN NOT code_exists OR attempts > 10;
        attempts := attempts + 1;
    END LOOP;
    RETURN new_code;
END;
$$;

-- 5. Function: create referral code for user (idempotent)
CREATE OR REPLACE FUNCTION public.get_or_create_referral_code(user_uuid UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    existing_code TEXT;
    new_code TEXT;
BEGIN
    SELECT code INTO existing_code FROM public.referral_codes WHERE user_id = user_uuid LIMIT 1;
    IF existing_code IS NOT NULL THEN
        RETURN existing_code;
    END IF;
    new_code := public.generate_referral_code(user_uuid);
    INSERT INTO public.referral_codes (user_id, code)
    VALUES (user_uuid, new_code)
    ON CONFLICT (code) DO NOTHING;
    RETURN new_code;
END;
$$;

-- 6. Function: apply referral code on signup
CREATE OR REPLACE FUNCTION public.apply_referral_code(referred_uuid UUID, referral_code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    ref_code_row public.referral_codes%ROWTYPE;
BEGIN
    -- Find the referral code
    SELECT * INTO ref_code_row FROM public.referral_codes WHERE code = UPPER(referral_code) LIMIT 1;
    IF ref_code_row.id IS NULL THEN
        RETURN FALSE;
    END IF;
    -- Prevent self-referral
    IF ref_code_row.user_id = referred_uuid THEN
        RETURN FALSE;
    END IF;
    -- Insert tracking record (ignore if already referred)
    INSERT INTO public.referral_tracking (
        referral_code_id, referrer_user_id, referred_user_id, status, trial_days_awarded
    ) VALUES (
        ref_code_row.id, ref_code_row.user_id, referred_uuid, 'completed', ref_code_row.premium_trial_days
    ) ON CONFLICT (referred_user_id) DO NOTHING;
    -- Update total referrals count
    UPDATE public.referral_codes
    SET total_referrals = total_referrals + 1, updated_at = CURRENT_TIMESTAMP
    WHERE id = ref_code_row.id;
    RETURN TRUE;
END;
$$;

-- 7. Enable RLS
ALTER TABLE public.referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_tracking ENABLE ROW LEVEL SECURITY;

-- 8. RLS Policies for referral_codes
DROP POLICY IF EXISTS "users_manage_own_referral_codes" ON public.referral_codes;
CREATE POLICY "users_manage_own_referral_codes"
ON public.referral_codes
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "users_read_any_referral_code" ON public.referral_codes;
CREATE POLICY "users_read_any_referral_code"
ON public.referral_codes
FOR SELECT
TO authenticated
USING (true);

-- 9. RLS Policies for referral_tracking
DROP POLICY IF EXISTS "users_view_own_referral_tracking" ON public.referral_tracking;
CREATE POLICY "users_view_own_referral_tracking"
ON public.referral_tracking
FOR SELECT
TO authenticated
USING (referrer_user_id = auth.uid() OR referred_user_id = auth.uid());

DROP POLICY IF EXISTS "service_insert_referral_tracking" ON public.referral_tracking;
CREATE POLICY "service_insert_referral_tracking"
ON public.referral_tracking
FOR INSERT
TO authenticated
WITH CHECK (referred_user_id = auth.uid());
