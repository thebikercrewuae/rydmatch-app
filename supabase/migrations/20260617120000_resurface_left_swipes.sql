-- Let passed profiles return to discovery while keeping right-swiped profiles
-- hidden. If a user later right-swipes someone they previously passed on,
-- upgrade that swipe so mutual matching can work.

CREATE OR REPLACE FUNCTION public.record_swipe(
  p_swiped_id UUID,
  p_direction TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_swiper_id UUID := auth.uid();
  v_is_match BOOLEAN := false;
  v_match_id UUID;
BEGIN
  IF v_swiper_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_swiped_id IS NULL OR p_swiped_id = v_swiper_id THEN
    RAISE EXCEPTION 'Invalid swiped profile';
  END IF;

  IF p_direction NOT IN ('left', 'right') THEN
    RAISE EXCEPTION 'Invalid swipe direction';
  END IF;

  INSERT INTO public.swipes (swiper_id, swiped_id, direction)
  VALUES (v_swiper_id, p_swiped_id, p_direction)
  ON CONFLICT (swiper_id, swiped_id) DO UPDATE
    SET direction = EXCLUDED.direction,
        created_at = now()
    WHERE public.swipes.direction = 'left'
      AND EXCLUDED.direction = 'right';

  IF p_direction = 'right' THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.swipes sw
      WHERE sw.swiper_id = p_swiped_id
        AND sw.swiped_id = v_swiper_id
        AND sw.direction = 'right'
    ) INTO v_is_match;

    IF v_is_match THEN
      INSERT INTO public.rider_matches (user1_id, user2_id)
      VALUES (
        LEAST(v_swiper_id::TEXT, p_swiped_id::TEXT)::UUID,
        GREATEST(v_swiper_id::TEXT, p_swiped_id::TEXT)::UUID
      )
      ON CONFLICT DO NOTHING
      RETURNING id INTO v_match_id;

      IF v_match_id IS NULL THEN
        SELECT rm.id
        INTO v_match_id
        FROM public.rider_matches rm
        WHERE LEAST(rm.user1_id::TEXT, rm.user2_id::TEXT) =
              LEAST(v_swiper_id::TEXT, p_swiped_id::TEXT)
          AND GREATEST(rm.user1_id::TEXT, rm.user2_id::TEXT) =
              GREATEST(v_swiper_id::TEXT, p_swiped_id::TEXT)
        LIMIT 1;
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'is_match', v_is_match,
    'match_id', v_match_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_swipe(UUID, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_swiped_ids()
RETURNS UUID[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(ARRAY_AGG(sw.swiped_id), ARRAY[]::UUID[])
  FROM public.swipes sw
  WHERE sw.swiper_id = auth.uid()
    AND sw.direction = 'right';
$$;

GRANT EXECUTE ON FUNCTION public.get_swiped_ids() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_discovery_profiles(
  p_current_user_id UUID,
  p_excluded_ids UUID[] DEFAULT ARRAY[]::UUID[]
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email TEXT,
  skill_levels TEXT[],
  bike_types TEXT[],
  preferred_roads TEXT[],
  riding_speed DOUBLE PRECISION,
  gender TEXT,
  same_gender_matching BOOLEAN,
  avatar_url TEXT,
  bio TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  ride_mode TEXT,
  mixed_community_matching BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_ride_mode TEXT;
  v_current_mixed BOOLEAN;
  v_current_gender TEXT;
  v_current_same_gender BOOLEAN;
  v_all_excluded UUID[];
BEGIN
  INSERT INTO public.user_profiles (id)
  VALUES (p_current_user_id)
  ON CONFLICT ON CONSTRAINT user_profiles_pkey DO NOTHING;

  SELECT
    COALESCE(up.ride_mode, 'motorcycle'),
    COALESCE(up.mixed_community_matching, FALSE),
    up.gender,
    COALESCE(up.same_gender_matching, FALSE)
  INTO
    v_current_ride_mode,
    v_current_mixed,
    v_current_gender,
    v_current_same_gender
  FROM public.user_profiles up
  WHERE up.id = p_current_user_id;

  SELECT COALESCE(ARRAY_AGG(sw.swiped_id), ARRAY[]::UUID[])
  INTO v_all_excluded
  FROM public.swipes sw
  WHERE sw.swiper_id = p_current_user_id
    AND sw.direction = 'right';

  v_all_excluded := COALESCE(v_all_excluded, ARRAY[]::UUID[])
    || COALESCE(p_excluded_ids, ARRAY[]::UUID[]);

  RETURN QUERY
  SELECT
    up.id,
    COALESCE(up.full_name, split_part(COALESCE(up.email, ''), '@', 1))::TEXT,
    COALESCE(up.email, '')::TEXT,
    COALESCE(up.skill_levels, ARRAY[]::TEXT[]),
    COALESCE(up.bike_types, ARRAY[]::TEXT[]),
    COALESCE(up.preferred_roads, ARRAY[]::TEXT[]),
    COALESCE(up.riding_speed, 60.0)::DOUBLE PRECISION,
    up.gender::TEXT,
    COALESCE(up.same_gender_matching, FALSE)::BOOLEAN,
    up.avatar_url::TEXT,
    COALESCE(up.bio, '')::TEXT,
    up.latitude::DOUBLE PRECISION,
    up.longitude::DOUBLE PRECISION,
    COALESCE(up.ride_mode, 'motorcycle')::TEXT,
    COALESCE(up.mixed_community_matching, FALSE)::BOOLEAN
  FROM public.user_profiles up
  WHERE up.id != p_current_user_id
    AND NOT EXISTS (
      SELECT 1
      FROM public.user_blocks ub
      WHERE ub.blocker_id = p_current_user_id
        AND ub.blocked_id = up.id
    )
    AND (array_length(v_all_excluded, 1) IS NULL OR up.id != ALL(v_all_excluded))
    AND (
      COALESCE(up.ride_mode, 'motorcycle') = v_current_ride_mode
      OR (
        v_current_mixed
        AND COALESCE(up.mixed_community_matching, FALSE)
      )
    )
    AND (
      NOT v_current_same_gender
      OR (
        v_current_gender IS NOT NULL
        AND v_current_gender <> ''
        AND v_current_gender <> 'prefer_not_to_say'
        AND up.gender = v_current_gender
      )
    )
    AND (
      NOT COALESCE(up.same_gender_matching, FALSE)
      OR (
        v_current_gender IS NOT NULL
        AND v_current_gender <> ''
        AND v_current_gender <> 'prefer_not_to_say'
        AND up.gender = v_current_gender
      )
    )
  ORDER BY up.location_updated_at DESC NULLS LAST, up.created_at DESC NULLS LAST
  LIMIT 150;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_discovery_profiles(UUID, UUID[])
  TO authenticated;

NOTIFY pgrst, 'reload schema';
