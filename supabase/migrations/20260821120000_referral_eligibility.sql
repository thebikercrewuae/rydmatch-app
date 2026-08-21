-- Referral Eligibility: Only pioneers and paid subscribers get referral codes.
-- Users who signed up via a referral code (on a 7-day trial) do NOT get their
-- own referral code until they subscribe.
--
-- Key changes:
--   1. get_or_create_referral_code now checks eligibility before creating a code
--   2. apply_referral_code restored to dual-reward logic with premium_trial_expires_at
--   3. Referred users get is_premium=true + premium_trial_expires_at (marks them as trial)
--   4. Paid subscribers have premium_trial_expires_at = NULL (eligible for own code)

-- 1. Update get_or_create_referral_code to check eligibility
CREATE OR REPLACE FUNCTION public.get_or_create_referral_code(user_uuid UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    existing_code TEXT;
    new_code TEXT;
    is_pioneer BOOLEAN;
    is_paid_subscriber BOOLEAN;
BEGIN
    -- Return existing code if one already exists
    SELECT code INTO existing_code FROM public.referral_codes WHERE user_id = user_uuid LIMIT 1;
    IF existing_code IS NOT NULL THEN
        RETURN existing_code;
    END IF;

    -- Check eligibility: pioneer OR paid subscriber (not on trial)
    SELECT EXISTS(
        SELECT 1 FROM public.pioneer_members
        WHERE user_id = user_uuid AND early_access_enabled = true
    ) INTO is_pioneer;

    SELECT (is_premium = true AND premium_trial_expires_at IS NULL)
    INTO is_paid_subscriber
    FROM public.user_profiles WHERE id = user_uuid;

    IF NOT (COALESCE(is_pioneer, false) OR COALESCE(is_paid_subscriber, false)) THEN
        RETURN NULL;
    END IF;

    new_code := public.generate_referral_code(user_uuid);
    INSERT INTO public.referral_codes (user_id, code)
    VALUES (user_uuid, new_code)
    ON CONFLICT (code) DO NOTHING;
    RETURN new_code;
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_create_referral_code(UUID) FROM public;
GRANT EXECUTE ON FUNCTION public.get_or_create_referral_code(UUID) TO authenticated;

-- 2. Restore dual-reward apply_referral_code with trial expiry tracking
--    Referred user: gets 7 days premium trial (premium_trial_expires_at set)
--    Referrer: gets 7 days extended IF they are on a trial (paid subscribers
--    and pioneers don't need extension — their premium doesn't expire)
CREATE OR REPLACE FUNCTION public.apply_referral_code(referred_uuid UUID, referral_code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    ref_code_row public.referral_codes%ROWTYPE;
    trial_days INTEGER;
    trial_expiry TIMESTAMPTZ;
BEGIN
    -- Find the referral code (exact match to preserve prefix casing)
    SELECT * INTO ref_code_row FROM public.referral_codes WHERE code = referral_code LIMIT 1;
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
    -- Setting premium_trial_expires_at marks them as a trial user —
    -- they will NOT be eligible for their own referral code until they subscribe
    UPDATE public.user_profiles
    SET
        is_premium = TRUE,
        premium_activated_at = COALESCE(premium_activated_at, CURRENT_TIMESTAMP),
        premium_trial_expires_at = trial_expiry,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = referred_uuid;

    -- Grant/extend premium trial to the REFERRER
    -- Only extend if they already have a trial expiry (trial users).
    -- Paid subscribers and pioneers have NULL trial expiry — their premium
    -- doesn't expire, so no extension needed.
    UPDATE public.user_profiles
    SET
        is_premium = TRUE,
        premium_activated_at = COALESCE(premium_activated_at, CURRENT_TIMESTAMP),
        premium_trial_expires_at = GREATEST(
            COALESCE(premium_trial_expires_at, CURRENT_TIMESTAMP),
            CURRENT_TIMESTAMP
        ) + (trial_days || ' days')::INTERVAL,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = ref_code_row.user_id
      AND premium_trial_expires_at IS NOT NULL;

    -- Update total referrals count
    UPDATE public.referral_codes
    SET total_referrals = total_referrals + 1, updated_at = CURRENT_TIMESTAMP
    WHERE id = ref_code_row.id;

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.apply_referral_code(UUID, TEXT) FROM public;
GRANT EXECUTE ON FUNCTION public.apply_referral_code(UUID, TEXT) TO authenticated;
