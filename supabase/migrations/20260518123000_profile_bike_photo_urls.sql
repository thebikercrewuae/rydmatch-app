-- Persist profile setup bike photos as Supabase Storage URLs instead of local app paths.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS bike_photo_urls TEXT[] DEFAULT ARRAY[]::TEXT[];
