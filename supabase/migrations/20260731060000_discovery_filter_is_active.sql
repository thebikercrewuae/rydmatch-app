-- Add is_active filter to discovery so deactivated users are hidden.
-- Enforce discovery radius in PostgreSQL and index the spatial lookup.
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

CREATE INDEX IF NOT EXISTS idx_user_profiles_discovery_location
ON public.user_profiles
USING gist (((extensions.st_setsrid(extensions.st_makepoint(longitude, latitude), 4326))::extensions.geography))
WHERE latitude BETWEEN -90 AND 90
  AND longitude BETWEEN -180 AND 180;

CREATE OR REPLACE FUNCTION public.get_discovery_profiles(
  p_current_user_id UUID,
  p_excluded_ids UUID[] DEFAULT ARRAY[]::UUID[],
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL,
  p_radius_meters DOUBLE PRECISION DEFAULT 500000,
  p_limit INTEGER DEFAULT 150,
  p_offset INTEGER DEFAULT 0
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
SET search_path = public, extensions
AS $$
DECLARE
  v_current_ride_mode TEXT;
  v_current_mixed BOOLEAN;
  v_current_gender TEXT;
  v_current_same_gender BOOLEAN;
  v_all_excluded UUID[];
  v_viewer_location extensions.geography;
  v_radius_meters DOUBLE PRECISION;
  v_limit INTEGER;
  v_offset INTEGER;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_current_user_id THEN
    RAISE EXCEPTION 'Not authorized to load discovery profiles';
  END IF;

  IF p_latitude IS NULL OR p_longitude IS NULL
     OR p_latitude NOT BETWEEN -90 AND 90
     OR p_longitude NOT BETWEEN -180 AND 180 THEN
    RETURN;
  END IF;

  v_radius_meters := LEAST(GREATEST(COALESCE(p_radius_meters, 0), 1), 804672);
  v_limit := LEAST(GREATEST(COALESCE(p_limit, 150), 1), 150);
  v_offset := GREATEST(COALESCE(p_offset, 0), 0);
  v_viewer_location := extensions.st_setsrid(
    extensions.st_makepoint(p_longitude, p_latitude), 4326
  )::extensions.geography;

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
  WHERE up.id <> p_current_user_id
    AND COALESCE(up.is_active, true) = true
    AND up.latitude BETWEEN -90 AND 90
    AND up.longitude BETWEEN -180 AND 180
    AND extensions.st_dwithin(
      extensions.st_setsrid(
        extensions.st_makepoint(up.longitude, up.latitude), 4326
      )::extensions.geography,
      v_viewer_location,
      v_radius_meters
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.user_blocks ub
      WHERE (ub.blocker_id = p_current_user_id AND ub.blocked_id = up.id)
         OR (ub.blocker_id = up.id AND ub.blocked_id = p_current_user_id)
    )
    AND (array_length(v_all_excluded, 1) IS NULL OR up.id <> ALL(v_all_excluded))
    AND (
      COALESCE(up.ride_mode, 'motorcycle') = v_current_ride_mode
      OR (v_current_mixed AND COALESCE(up.mixed_community_matching, FALSE))
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
  ORDER BY
    extensions.st_distance(
      extensions.st_setsrid(
        extensions.st_makepoint(up.longitude, up.latitude), 4326
      )::extensions.geography,
      v_viewer_location
    ),
    up.location_updated_at DESC NULLS LAST,
    up.created_at DESC NULLS LAST
  LIMIT v_limit OFFSET v_offset;
END;
$$;

REVOKE ALL ON FUNCTION public.get_discovery_profiles(
  UUID, UUID[], DOUBLE PRECISION, DOUBLE PRECISION,
  DOUBLE PRECISION, INTEGER, INTEGER
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_discovery_profiles(
  UUID, UUID[], DOUBLE PRECISION, DOUBLE PRECISION,
  DOUBLE PRECISION, INTEGER, INTEGER
) TO authenticated;

NOTIFY pgrst, 'reload schema';
