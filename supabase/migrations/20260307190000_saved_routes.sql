-- Migration: saved_routes table for Route Planner feature
-- Timestamp: 20260307190000

CREATE TABLE IF NOT EXISTS public.saved_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    waypoints JSONB NOT NULL DEFAULT '[]'::jsonb,
    distance_km DOUBLE PRECISION DEFAULT 0,
    estimated_minutes INTEGER DEFAULT 0,
    route_type TEXT DEFAULT 'fastest',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_saved_routes_user_id ON public.saved_routes(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_routes_created_at ON public.saved_routes(created_at);

ALTER TABLE public.saved_routes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_manage_own_saved_routes" ON public.saved_routes;
CREATE POLICY "users_manage_own_saved_routes"
ON public.saved_routes
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
