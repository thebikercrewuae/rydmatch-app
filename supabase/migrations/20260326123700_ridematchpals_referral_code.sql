-- Update referral code generation to use MotoMatchPals prefix
-- New format: MotoMatchPals-XXXX (4 alphanumeric chars)

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
        -- Generate a 4-char alphanumeric suffix with MotoMatchPals prefix
        new_code := 'MotoMatchPals-' || UPPER(SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 4));
        SELECT EXISTS(SELECT 1 FROM public.referral_codes WHERE code = new_code) INTO code_exists;
        EXIT WHEN NOT code_exists OR attempts > 20;
        attempts := attempts + 1;
    END LOOP;
    RETURN new_code;
END;
$$;

-- Update get_or_create_referral_code to use new format
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

-- Update apply_referral_code to match exact code (case-sensitive for MotoMatchPals prefix)
CREATE OR REPLACE FUNCTION public.apply_referral_code(referred_uuid UUID, referral_code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    ref_code_row public.referral_codes%ROWTYPE;
BEGIN
    -- Find the referral code (exact match to preserve MotoMatchPals casing)
    SELECT * INTO ref_code_row FROM public.referral_codes WHERE code = referral_code LIMIT 1;
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
