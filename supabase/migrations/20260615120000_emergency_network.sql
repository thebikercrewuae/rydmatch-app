-- SMS-independent RydMatch Emergency Network.

ALTER TYPE public.notification_type ADD VALUE IF NOT EXISTS 'emergency_sos';

CREATE TABLE IF NOT EXISTS public.emergency_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  rider_name TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accuracy DOUBLE PRECISION,
  phone_number TEXT,
  live_ride_session_id UUID,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'resolved', 'cancelled')),
  is_test BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.emergency_alert_recipients (
  alert_id UUID NOT NULL REFERENCES public.emergency_alerts(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  source TEXT NOT NULL CHECK (source IN ('live_ride', 'match', 'self_test')),
  acknowledged_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (alert_id, recipient_id)
);

CREATE INDEX IF NOT EXISTS idx_emergency_alerts_rider_created
  ON public.emergency_alerts(rider_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_emergency_alerts_status_created
  ON public.emergency_alerts(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_emergency_alert_recipients_user_created
  ON public.emergency_alert_recipients(recipient_id, created_at DESC);

ALTER TABLE public.emergency_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_alert_recipients ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_emergency_alert_involved(alert_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.emergency_alerts alert
    WHERE alert.id = alert_uuid
      AND (
        alert.rider_id = auth.uid()
        OR EXISTS (
          SELECT 1
          FROM public.emergency_alert_recipients recipient
          WHERE recipient.alert_id = alert_uuid
            AND recipient.recipient_id = auth.uid()
        )
      )
  );
$$;

REVOKE ALL ON FUNCTION public.is_emergency_alert_involved(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_emergency_alert_involved(UUID) TO authenticated;

DROP POLICY IF EXISTS "emergency_alerts_read_involved" ON public.emergency_alerts;
CREATE POLICY "emergency_alerts_read_involved"
ON public.emergency_alerts
FOR SELECT
TO authenticated
USING (public.is_emergency_alert_involved(id));

DROP POLICY IF EXISTS "emergency_alerts_update_own" ON public.emergency_alerts;
CREATE POLICY "emergency_alerts_update_own"
ON public.emergency_alerts
FOR UPDATE
TO authenticated
USING (rider_id = auth.uid())
WITH CHECK (rider_id = auth.uid());

DROP POLICY IF EXISTS "emergency_recipients_read_involved"
ON public.emergency_alert_recipients;
CREATE POLICY "emergency_recipients_read_involved"
ON public.emergency_alert_recipients
FOR SELECT
TO authenticated
USING (public.is_emergency_alert_involved(alert_id));

DROP POLICY IF EXISTS "emergency_recipients_acknowledge_own"
ON public.emergency_alert_recipients;
CREATE POLICY "emergency_recipients_acknowledge_own"
ON public.emergency_alert_recipients
FOR UPDATE
TO authenticated
USING (recipient_id = auth.uid())
WITH CHECK (recipient_id = auth.uid());

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.emergency_alerts;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.emergency_alert_recipients;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
