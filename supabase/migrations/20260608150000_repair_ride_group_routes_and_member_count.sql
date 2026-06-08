-- Repair schema used by planned group routes and make invitation acceptance
-- update member_count idempotently.

ALTER TABLE public.ride_groups
  ADD COLUMN IF NOT EXISTS route_polyline JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS route_waypoints JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE OR REPLACE FUNCTION public.increment_group_member_count(
  group_id_param UUID
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  next_member_count INTEGER;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.ride_groups rg
    WHERE rg.id = group_id_param
      AND (
        rg.creator_id = auth.uid()
        OR EXISTS (
          SELECT 1
          FROM public.ride_group_invites rgi
          WHERE rgi.group_id = rg.id
            AND rgi.invitee_id = auth.uid()
            AND rgi.status = 'accepted'
        )
      )
  ) THEN
    RAISE EXCEPTION 'Accepted ride group invitation not found';
  END IF;

  SELECT 1 + COUNT(DISTINCT rgi.invitee_id)::INTEGER
  INTO next_member_count
  FROM public.ride_group_invites rgi
  WHERE rgi.group_id = group_id_param
    AND rgi.status = 'accepted';

  UPDATE public.ride_groups rg
  SET member_count = LEAST(rg.max_riders, next_member_count),
      updated_at = CURRENT_TIMESTAMP
  WHERE rg.id = group_id_param
  RETURNING rg.member_count INTO next_member_count;

  RETURN next_member_count;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_group_member_count(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_group_member_count(UUID)
TO authenticated;

NOTIFY pgrst, 'reload schema';
