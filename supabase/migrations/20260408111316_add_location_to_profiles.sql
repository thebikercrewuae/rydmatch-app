-- Add location columns to user_profiles for proximity-based discovery

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMPTZ;

-- Index for faster location-based queries
CREATE INDEX IF NOT EXISTS idx_user_profiles_location
  ON public.user_profiles(latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
