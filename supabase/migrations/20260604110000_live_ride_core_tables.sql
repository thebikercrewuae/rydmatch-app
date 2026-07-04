-- Core live-ride schema. This must precede policies and location-pipeline migrations.

CREATE TABLE IF NOT EXISTS public.live_ride_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_group_id UUID REFERENCES public.ride_groups(id) ON DELETE SET NULL,
  route_id UUID REFERENCES public.saved_routes(id) ON DELETE SET NULL,
  started_by UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'completed', 'cancelled')),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ,
  auto_stop_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '8 hours'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.live_ride_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.live_ride_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'left')),
  is_sharing_location BOOLEAN NOT NULL DEFAULT TRUE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at TIMESTAMPTZ,
  UNIQUE (session_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.live_ride_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.live_ride_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  heading DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  accuracy DOUBLE PRECISION,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_live_ride_sessions_group_status
  ON public.live_ride_sessions (ride_group_id, status, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_ride_sessions_starter
  ON public.live_ride_sessions (started_by, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_ride_participants_user_status
  ON public.live_ride_participants (user_id, status, joined_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_ride_participants_session_status
  ON public.live_ride_participants (session_id, status);
CREATE INDEX IF NOT EXISTS idx_live_ride_locations_session_user_created
  ON public.live_ride_locations (session_id, user_id, created_at);

ALTER TABLE public.live_ride_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_ride_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_ride_locations ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_live_ride_member(target_session_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.live_ride_sessions session
    WHERE session.id = target_session_id
      AND (
        session.started_by = auth.uid()
        OR EXISTS (
          SELECT 1
          FROM public.live_ride_participants participant
          WHERE participant.session_id = target_session_id
            AND participant.user_id = auth.uid()
        )
      )
  );
$$;

REVOKE ALL ON FUNCTION public.is_live_ride_member(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_live_ride_member(UUID) TO authenticated;

DROP POLICY IF EXISTS live_ride_sessions_select_members ON public.live_ride_sessions;
CREATE POLICY live_ride_sessions_select_members
  ON public.live_ride_sessions FOR SELECT TO authenticated
  USING (started_by = auth.uid() OR public.is_live_ride_member(id));

DROP POLICY IF EXISTS live_ride_sessions_insert_starter ON public.live_ride_sessions;
CREATE POLICY live_ride_sessions_insert_starter
  ON public.live_ride_sessions FOR INSERT TO authenticated
  WITH CHECK (started_by = auth.uid());

DROP POLICY IF EXISTS live_ride_sessions_update_starter ON public.live_ride_sessions;
CREATE POLICY live_ride_sessions_update_starter
  ON public.live_ride_sessions FOR UPDATE TO authenticated
  USING (started_by = auth.uid())
  WITH CHECK (started_by = auth.uid());

DROP POLICY IF EXISTS live_ride_participants_select_members ON public.live_ride_participants;
CREATE POLICY live_ride_participants_select_members
  ON public.live_ride_participants FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_live_ride_member(session_id));

DROP POLICY IF EXISTS live_ride_participants_insert_self ON public.live_ride_participants;
CREATE POLICY live_ride_participants_insert_self
  ON public.live_ride_participants FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS live_ride_participants_update_self ON public.live_ride_participants;
CREATE POLICY live_ride_participants_update_self
  ON public.live_ride_participants FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS live_ride_locations_select_members ON public.live_ride_locations;
CREATE POLICY live_ride_locations_select_members
  ON public.live_ride_locations FOR SELECT TO authenticated
  USING (public.is_live_ride_member(session_id));

DROP POLICY IF EXISTS live_ride_locations_insert_self ON public.live_ride_locations;
CREATE POLICY live_ride_locations_insert_self
  ON public.live_ride_locations FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND public.is_live_ride_member(session_id));

GRANT SELECT, INSERT, UPDATE ON public.live_ride_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.live_ride_participants TO authenticated;
GRANT SELECT, INSERT ON public.live_ride_locations TO authenticated;

DO $$
DECLARE
  table_name TEXT;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'live_ride_sessions',
    'live_ride_participants',
    'live_ride_locations'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = table_name
    ) THEN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        table_name
      );
    END IF;
  END LOOP;
END
$$;

NOTIFY pgrst, 'reload schema';