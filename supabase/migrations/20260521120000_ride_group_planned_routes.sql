-- Persist the planned Route Planner path for group rides so live rides can
-- show the route as well as member locations.

ALTER TABLE public.ride_groups
  ADD COLUMN IF NOT EXISTS route_polyline JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS route_waypoints JSONB NOT NULL DEFAULT '[]'::jsonb;
