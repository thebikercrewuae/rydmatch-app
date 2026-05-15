-- Phase 3: support motorcycle and bicycle ride groups.
-- Existing ride groups remain motorcycle groups by default.

ALTER TABLE public.ride_groups
  ADD COLUMN IF NOT EXISTS ride_community TEXT NOT NULL DEFAULT 'motorcycle';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ride_groups_ride_community_check'
  ) THEN
    ALTER TABLE public.ride_groups
      ADD CONSTRAINT ride_groups_ride_community_check
        CHECK (ride_community IN ('motorcycle', 'bicycle'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ride_groups_ride_community
  ON public.ride_groups(ride_community);
