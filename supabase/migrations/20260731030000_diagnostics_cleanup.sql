-- Auto-cleanup helpers for old diagnostics and stale live-ride locations.
-- Called by the daily AI diagnostics reviewer (runSafeMaintenance) so these
-- tables don't grow unbounded. Only the service role invokes them.
CREATE OR REPLACE FUNCTION public.cleanup_old_app_errors(retention_days integer DEFAULT 90)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count integer;
BEGIN
  DELETE FROM public.app_errors
  WHERE created_at < now() - (retention_days * interval '1 day');
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.cleanup_stale_live_ride_locations(retention_minutes integer DEFAULT 360)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count integer;
BEGIN
  DELETE FROM public.live_ride_locations
  WHERE updated_at < now() - (retention_minutes * interval '1 minute');
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

REVOKE ALL ON FUNCTION public.cleanup_old_app_errors(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cleanup_stale_live_ride_locations(integer) FROM PUBLIC;