ALTER TABLE public.motion_sessions
  ADD COLUMN IF NOT EXISTS track_name text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS vehicle_name text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS import_source text NOT NULL DEFAULT 'manual';
