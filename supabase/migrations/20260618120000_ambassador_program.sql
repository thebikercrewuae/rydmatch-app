-- Ambassador Program
-- Grants reviewed riders temporary Premium access without changing RevenueCat billing.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS is_ambassador BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS ambassador_expires_at TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS ambassador_code TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS ambassador_notes TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS ambassador_granted_at TIMESTAMPTZ DEFAULT NULL;

ALTER TABLE public.referral_codes
  ADD COLUMN IF NOT EXISTS is_ambassador_code BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS ambassador_tier TEXT DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_user_profiles_ambassador_active
  ON public.user_profiles (is_ambassador, ambassador_expires_at);

CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_profiles
    WHERE id = auth.uid()
      AND is_admin = TRUE
  );
$$;

CREATE OR REPLACE FUNCTION public.grant_ambassador_access(
  target_user_uuid UUID,
  grant_days INTEGER DEFAULT 90,
  requested_ambassador_code TEXT DEFAULT NULL,
  notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_code TEXT;
  existing_referral_code TEXT;
BEGIN
  IF public.is_admin_user() IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  IF target_user_uuid IS NULL THEN
    RETURN FALSE;
  END IF;

  normalized_code := NULLIF(UPPER(TRIM(requested_ambassador_code)), '');

  UPDATE public.user_profiles
  SET
    is_ambassador = TRUE,
    ambassador_granted_at = CURRENT_TIMESTAMP,
    ambassador_expires_at = CASE
      WHEN grant_days IS NULL OR grant_days <= 0 THEN NULL
      ELSE CURRENT_TIMESTAMP + (grant_days || ' days')::INTERVAL
    END,
    ambassador_code = normalized_code,
    ambassador_notes = notes,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = target_user_uuid;

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  SELECT code
  INTO existing_referral_code
  FROM public.referral_codes
  WHERE user_id = target_user_uuid
  ORDER BY updated_at DESC, created_at DESC
  LIMIT 1;

  IF existing_referral_code IS NULL THEN
    existing_referral_code := public.get_or_create_referral_code(target_user_uuid);
  END IF;

  UPDATE public.referral_codes
  SET
    is_ambassador_code = TRUE,
    ambassador_tier = 'ambassador',
    updated_at = CURRENT_TIMESTAMP
  WHERE user_id = target_user_uuid;

  RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_ambassador_access(
  target_user_uuid UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.is_admin_user() IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  UPDATE public.user_profiles
  SET
    is_ambassador = FALSE,
    ambassador_expires_at = NULL,
    ambassador_code = NULL,
    ambassador_notes = NULL,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = target_user_uuid;

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  UPDATE public.referral_codes
  SET
    is_ambassador_code = FALSE,
    ambassador_tier = NULL,
    updated_at = CURRENT_TIMESTAMP
  WHERE user_id = target_user_uuid;

  RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.expire_ambassador_access()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  expired_count INTEGER := 0;
BEGIN
  UPDATE public.user_profiles
  SET
    is_ambassador = FALSE,
    ambassador_code = NULL,
    ambassador_notes = NULL,
    updated_at = CURRENT_TIMESTAMP
  WHERE is_ambassador = TRUE
    AND ambassador_expires_at IS NOT NULL
    AND ambassador_expires_at <= CURRENT_TIMESTAMP;

  GET DIAGNOSTICS expired_count = ROW_COUNT;
  RETURN expired_count;
END;
$$;
