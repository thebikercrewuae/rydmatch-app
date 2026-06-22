-- Converge newer profile fields on deployments where earlier migrations
-- were skipped or applied out of order.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS skill_levels TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS bike_types TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS preferred_roads TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS riding_speed DOUBLE PRECISION NOT NULL DEFAULT 60.0,
  ADD COLUMN IF NOT EXISTS bio TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS is_profile_complete BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS bike_photo_urls TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS minimum_age_confirmed INTEGER,
  ADD COLUMN IF NOT EXISTS age_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS same_gender_matching BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS ride_times JSONB NOT NULL DEFAULT '{}'::JSONB,
  ADD COLUMN IF NOT EXISTS ride_mode TEXT NOT NULL DEFAULT 'motorcycle',
  ADD COLUMN IF NOT EXISTS mixed_community_matching BOOLEAN NOT NULL DEFAULT FALSE;

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

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'user_profiles_ride_mode_check'
      AND conrelid = 'public.user_profiles'::regclass
  ) THEN
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_ride_mode_check
      CHECK (ride_mode IN ('motorcycle', 'bicycle'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_profiles_same_gender_matching
  ON public.user_profiles(gender, same_gender_matching);

NOTIFY pgrst, 'reload schema';
