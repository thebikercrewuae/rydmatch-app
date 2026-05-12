-- Boost Profile table
CREATE TABLE IF NOT EXISTS public.profile_boosts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  boosted_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS idx_profile_boosts_user_id ON public.profile_boosts(user_id);
CREATE INDEX IF NOT EXISTS idx_profile_boosts_expires_at ON public.profile_boosts(expires_at);

-- Enable RLS
ALTER TABLE public.profile_boosts ENABLE ROW LEVEL SECURITY;

-- Users can read their own boosts
CREATE POLICY "Users can read own boosts"
  ON public.profile_boosts
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own boosts
CREATE POLICY "Users can insert own boosts"
  ON public.profile_boosts
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own boosts
CREATE POLICY "Users can delete own boosts"
  ON public.profile_boosts
  FOR DELETE
  USING (auth.uid() = user_id);
