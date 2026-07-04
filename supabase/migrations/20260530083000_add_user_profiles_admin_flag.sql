-- Admin authorization is referenced by diagnostics migrations that follow.
-- Keep this migration before those policies so clean environments can bootstrap.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_user_profiles_is_admin
  ON public.user_profiles (is_admin)
  WHERE is_admin = TRUE;
