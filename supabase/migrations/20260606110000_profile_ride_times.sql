ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS ride_times JSONB DEFAULT '{}'::JSONB;
