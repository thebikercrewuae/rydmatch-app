-- Analytics Events Table
-- Tracks key user events: profile creation, swipes, matches, message sends, SOS triggers, premium conversions

CREATE TABLE IF NOT EXISTS public.analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    event_data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id ON public.analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_event_type ON public.analytics_events(event_type);
CREATE INDEX IF NOT EXISTS idx_analytics_events_created_at ON public.analytics_events(created_at);

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_insert_own_analytics_events" ON public.analytics_events;
CREATE POLICY "users_insert_own_analytics_events"
ON public.analytics_events
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "users_select_own_analytics_events" ON public.analytics_events;
CREATE POLICY "users_select_own_analytics_events"
ON public.analytics_events
FOR SELECT
TO authenticated
USING (user_id = auth.uid());
