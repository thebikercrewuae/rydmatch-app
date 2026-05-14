-- Phase 1: broaden RydMatch from motorcycle-only matching to ride communities.
-- Existing users remain motorcycle riders by default.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS ride_mode TEXT NOT NULL DEFAULT 'motorcycle',
  ADD COLUMN IF NOT EXISTS mixed_community_matching BOOLEAN NOT NULL DEFAULT FALSE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'user_profiles_ride_mode_check'
  ) THEN
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_ride_mode_check
      CHECK (ride_mode IN ('motorcycle', 'bicycle'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_profiles_ride_mode
  ON public.user_profiles(ride_mode);

CREATE INDEX IF NOT EXISTS idx_user_profiles_mixed_community_matching
  ON public.user_profiles(mixed_community_matching);
