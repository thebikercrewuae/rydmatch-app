-- Live ride group chat messages + restore the helper that live-ride RLS depends on.
-- The is_live_ride_member helper was defined in 20260604110000 but was missing on
-- the live database, so it is (re)created here idempotently.

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

CREATE TABLE IF NOT EXISTS public.live_ride_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.live_ride_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.live_ride_messages ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_live_ride_messages_session_created
  ON public.live_ride_messages (session_id, created_at DESC);

DROP POLICY IF EXISTS "live_ride_messages_member_read" ON public.live_ride_messages;
CREATE POLICY "live_ride_messages_member_read"
  ON public.live_ride_messages FOR SELECT TO authenticated
  USING (public.is_live_ride_member(session_id));

DROP POLICY IF EXISTS "live_ride_messages_member_insert" ON public.live_ride_messages;
CREATE POLICY "live_ride_messages_member_insert"
  ON public.live_ride_messages FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND public.is_live_ride_member(session_id));

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.live_ride_messages;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

GRANT SELECT, INSERT ON public.live_ride_messages TO authenticated;