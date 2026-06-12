ALTER TABLE public.motion_laps
  ADD COLUMN IF NOT EXISTS start_elapsed_ms integer,
  ADD COLUMN IF NOT EXISTS end_elapsed_ms integer;
