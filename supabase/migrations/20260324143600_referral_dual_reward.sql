-- Referral Dual Reward Migration
-- Adds premium_trial_expires_at to user_profiles
-- Updates apply_referral_code to reward BOTH the referrer and the new user

-- 1. Add premium_trial_expires_at column to user_profiles (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'user_profiles'
          AND column_name = 'premium_trial_expires_at'
    ) THEN
        ALTER TABLE public.user_profiles
        ADD COLUMN premium_trial_expires_at TIMESTAMPTZ DEFAULT NULL;
    END IF;
END;
$$;

-- 2. Add referred_user_trial_days_awarded to referral_tracking (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'referral_tracking'
          AND column_name = 'referred_user_trial_days_awarded'
    ) THEN
        ALTER TABLE public.referral_tracking
        ADD COLUMN referred_user_trial_days_awarded INTEGER NOT NULL DEFAULT 7;
    END IF;
END;
$$;

-- 3. Updated apply_referral_code: rewards BOTH referrer and referred user
CREATE OR REPLACE FUNCTION public.apply_referral_code(referred_uuid UUID, referral_code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    ref_code_row public.referral_codes%ROWTYPE;
    trial_days INTEGER;
    trial_expiry TIMESTAMPTZ;
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

    trial_days := COALESCE(ref_code_row.premium_trial_days, 7);
    trial_expiry := CURRENT_TIMESTAMP + (trial_days || ' days')::INTERVAL;

    -- Insert tracking record (ignore if already referred)
    INSERT INTO public.referral_tracking (
        referral_code_id,
        referrer_user_id,
        referred_user_id,
        status,
        trial_days_awarded,
        referred_user_trial_days_awarded
    ) VALUES (
        ref_code_row.id,
        ref_code_row.user_id,
        referred_uuid,
        'completed',
        trial_days,
        trial_days
    ) ON CONFLICT (referred_user_id) DO NOTHING;

    -- If the insert was skipped (already referred), return false
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- Grant premium trial to the NEW USER (referred)
    UPDATE public.user_profiles
    SET
        is_premium = TRUE,
        premium_activated_at = CURRENT_TIMESTAMP,
        premium_trial_expires_at = trial_expiry,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = referred_uuid;

    -- Grant premium trial to the REFERRER
    -- Extend existing trial if they already have one, otherwise set fresh trial
    UPDATE public.user_profiles
    SET
        is_premium = TRUE,
        premium_activated_at = COALESCE(premium_activated_at, CURRENT_TIMESTAMP),
        premium_trial_expires_at = GREATEST(
            COALESCE(premium_trial_expires_at, CURRENT_TIMESTAMP),
            CURRENT_TIMESTAMP
        ) + (trial_days || ' days')::INTERVAL,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = ref_code_row.user_id;

    -- Update total referrals count
    UPDATE public.referral_codes
    SET total_referrals = total_referrals + 1, updated_at = CURRENT_TIMESTAMP
    WHERE id = ref_code_row.id;

    RETURN TRUE;
END;
$$;

-- 4. Helper function: check if a user's premium trial is still active
CREATE OR REPLACE FUNCTION public.check_premium_trial_active(user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    trial_expiry TIMESTAMPTZ;
    is_prem BOOLEAN;
BEGIN
    SELECT is_premium, premium_trial_expires_at
    INTO is_prem, trial_expiry
    FROM public.user_profiles
    WHERE id = user_uuid;

    IF NOT is_prem THEN
        RETURN FALSE;
    END IF;

    -- If no expiry set, it's a paid subscription (always active)
    IF trial_expiry IS NULL THEN
        RETURN TRUE;
    END IF;

    -- Check if trial is still valid
    IF trial_expiry > CURRENT_TIMESTAMP THEN
        RETURN TRUE;
    END IF;

    -- Trial expired — revoke premium
    UPDATE public.user_profiles
    SET is_premium = FALSE, updated_at = CURRENT_TIMESTAMP
    WHERE id = user_uuid;

    RETURN FALSE;
END;
$$;
