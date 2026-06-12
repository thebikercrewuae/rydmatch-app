ALTER TABLE public.motion_telemetry_samples
  ADD COLUMN IF NOT EXISTS elapsed_ms integer;

CREATE INDEX IF NOT EXISTS motion_telemetry_samples_session_elapsed_idx
  ON public.motion_telemetry_samples(session_id, elapsed_ms);
