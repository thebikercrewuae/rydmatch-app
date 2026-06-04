-- Active live-ride participants need the planned group route so every rider
-- sees the same navigation path after joining. The security-definer helper
-- avoids RLS recursion while checking live session membership.

CREATE OR REPLACE FUNCTION public.can_view_live_ride_group_route(group_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.live_ride_sessions session
    JOIN public.live_ride_participants participant
      ON participant.session_id = session.id
    WHERE session.ride_group_id = group_id
      AND session.status = 'active'
      AND participant.user_id = auth.uid()
      AND participant.status = 'active'
  );
$$;

REVOKE ALL ON FUNCTION public.can_view_live_ride_group_route(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_view_live_ride_group_route(UUID)
TO authenticated;

DROP POLICY IF EXISTS "live_ride_participants_view_group_routes"
ON public.ride_groups;

CREATE POLICY "live_ride_participants_view_group_routes"
ON public.ride_groups
FOR SELECT
TO authenticated
USING (
  public.can_view_live_ride_group_route(id)
);
