-- Store age-gate confirmation without exposing full date of birth on profiles.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS minimum_age_confirmed INTEGER,
  ADD COLUMN IF NOT EXISTS age_verified_at TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'user_profiles_minimum_age_confirmed_check'
  ) THEN
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_minimum_age_confirmed_check
      CHECK (
        minimum_age_confirmed IS NULL
        OR minimum_age_confirmed IN (16, 18)
      );
  END IF;
END $$;
