-- Keep one mutable location row per active rider for the live map.
-- The existing live_ride_locations table remains the sampled ride-history trail.

CREATE TABLE IF NOT EXISTS public.live_ride_current_locations (
  session_id UUID NOT NULL
    REFERENCES public.live_ride_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL
    REFERENCES auth.users(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  heading DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  accuracy DOUBLE PRECISION,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (session_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_live_ride_current_locations_session_updated
  ON public.live_ride_current_locations(session_id, updated_at DESC);

ALTER TABLE public.live_ride_current_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_ride_current_locations REPLICA IDENTITY FULL;

DROP POLICY IF EXISTS live_current_locations_select_participants
  ON public.live_ride_current_locations;
CREATE POLICY live_current_locations_select_participants
  ON public.live_ride_current_locations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.live_ride_participants participant
      WHERE participant.session_id =
            live_ride_current_locations.session_id
        AND participant.user_id = auth.uid()
        AND participant.status = 'active'
    )
  );

DROP POLICY IF EXISTS live_current_locations_insert_own
  ON public.live_ride_current_locations;
CREATE POLICY live_current_locations_insert_own
  ON public.live_ride_current_locations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.live_ride_participants participant
      WHERE participant.session_id =
            live_ride_current_locations.session_id
        AND participant.user_id = auth.uid()
        AND participant.status = 'active'
        AND COALESCE(participant.is_sharing_location, TRUE)
    )
  );

DROP POLICY IF EXISTS live_current_locations_update_own
  ON public.live_ride_current_locations;
CREATE POLICY live_current_locations_update_own
  ON public.live_ride_current_locations
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.live_ride_participants participant
      WHERE participant.session_id =
            live_ride_current_locations.session_id
        AND participant.user_id = auth.uid()
        AND participant.status = 'active'
        AND COALESCE(participant.is_sharing_location, TRUE)
    )
  );

DROP POLICY IF EXISTS live_current_locations_delete_own
  ON public.live_ride_current_locations;
CREATE POLICY live_current_locations_delete_own
  ON public.live_ride_current_locations
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.live_ride_current_locations
  TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'live_ride_current_locations'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.live_ride_current_locations;
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.clear_completed_live_ride_locations()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status
     AND NEW.status <> 'active' THEN
    DELETE FROM public.live_ride_current_locations
    WHERE session_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS clear_completed_live_ride_locations_trigger
  ON public.live_ride_sessions;
CREATE TRIGGER clear_completed_live_ride_locations_trigger
AFTER UPDATE OF status ON public.live_ride_sessions
FOR EACH ROW
EXECUTE FUNCTION public.clear_completed_live_ride_locations();

NOTIFY pgrst, 'reload schema';
