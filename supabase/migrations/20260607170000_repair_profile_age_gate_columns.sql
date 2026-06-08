ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS minimum_age_confirmed INTEGER,
  ADD COLUMN IF NOT EXISTS age_verified_at TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'user_profiles_minimum_age_confirmed_check'
      AND conrelid = 'public.user_profiles'::regclass
  ) THEN
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_minimum_age_confirmed_check
      CHECK (
        minimum_age_confirmed IS NULL
        OR minimum_age_confirmed IN (16, 18)
      );
  END IF;
END
$$;

NOTIFY pgrst, 'reload schema';
