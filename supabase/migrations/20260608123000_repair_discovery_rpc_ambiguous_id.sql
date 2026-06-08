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
  WHERE sw.swiper_id = p_current_user_id;

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
