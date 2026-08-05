-- Allow a rider who JOINED a ride group to remove a completed ride from their
-- own page. This does NOT delete the ride group itself -- the creator's copy
-- and other riders' copies are unaffected. Only the calling user's accepted
-- invite and membership/"I'm home" rows are removed.
--
-- Restriction: only works once the ride date has passed (completed rides),
-- and the caller must not be the ride's creator (creators use the existing
-- delete_old_ride_group flow that fully removes the group).

CREATE OR REPLACE FUNCTION public.leave_completed_ride_group(p_group_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_ride_date timestamptz;
  v_is_creator boolean;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT g.ride_date, (g.creator_id = v_user)
  INTO v_ride_date, v_is_creator
  FROM public.ride_groups g
  WHERE g.id = p_group_id;

  IF v_ride_date IS NULL THEN
    RAISE EXCEPTION 'Ride not found';
  END IF;

  IF v_is_creator THEN
    RAISE EXCEPTION 'Creators must delete the ride from the ride management screen';
  END IF;

  -- Only completed rides can be removed from a joiner's page.
  IF v_ride_date > now() THEN
    RAISE EXCEPTION 'You can only remove a ride from your page after it is complete';
  END IF;

  -- Remove the caller's accepted (or pending) invite for this group.
  DELETE FROM public.ride_group_invites
  WHERE group_id = p_group_id
    AND invitee_id = v_user;

  -- Remove the caller's membership / "I'm home" row, if any.
  DELETE FROM public.ride_group_members
  WHERE group_id = p_group_id
    AND user_id = v_user;
END;
$$;

REVOKE ALL ON FUNCTION public.leave_completed_ride_group(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.leave_completed_ride_group(uuid) TO authenticated;