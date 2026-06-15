-- Repair deployments where the profile bike photo migration was not applied.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS bike_photo_urls TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

COMMENT ON COLUMN public.user_profiles.bike_photo_urls IS
  'Public Supabase Storage URLs for motorcycle or bicycle profile photos.';

NOTIFY pgrst, 'reload schema';
