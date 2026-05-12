-- Create swipes table
CREATE TABLE IF NOT EXISTS public.swipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  swiper_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  swiped_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  direction TEXT NOT NULL CHECK (direction IN ('left', 'right')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Unique constraint: a user can only swipe on the same person once
CREATE UNIQUE INDEX IF NOT EXISTS idx_swipes_unique_pair
  ON public.swipes (swiper_id, swiped_id);

CREATE INDEX IF NOT EXISTS idx_swipes_swiper_id ON public.swipes (swiper_id);
CREATE INDEX IF NOT EXISTS idx_swipes_swiped_id ON public.swipes (swiped_id);

-- Create new matches table (replaces old schema if needed)
-- The old matches table used user_id/matched_user_id; we create a symmetric one
CREATE TABLE IF NOT EXISTS public.rider_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  user2_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Unique constraint: no duplicate matches (enforce canonical ordering user1 < user2)
CREATE UNIQUE INDEX IF NOT EXISTS idx_rider_matches_unique_pair
  ON public.rider_matches (
    LEAST(user1_id::TEXT, user2_id::TEXT),
    GREATEST(user1_id::TEXT, user2_id::TEXT)
  );

CREATE INDEX IF NOT EXISTS idx_rider_matches_user1 ON public.rider_matches (user1_id);
CREATE INDEX IF NOT EXISTS idx_rider_matches_user2 ON public.rider_matches (user2_id);

-- Enable RLS
ALTER TABLE public.swipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rider_matches ENABLE ROW LEVEL SECURITY;

-- RLS: swipes
DROP POLICY IF EXISTS "swipes_insert_own" ON public.swipes;
CREATE POLICY "swipes_insert_own"
  ON public.swipes
  FOR INSERT
  TO authenticated
  WITH CHECK (swiper_id = auth.uid());

DROP POLICY IF EXISTS "swipes_select_own" ON public.swipes;
CREATE POLICY "swipes_select_own"
  ON public.swipes
  FOR SELECT
  TO authenticated
  USING (swiper_id = auth.uid());

-- RLS: rider_matches — users can read matches they are part of
DROP POLICY IF EXISTS "rider_matches_select_own" ON public.rider_matches;
CREATE POLICY "rider_matches_select_own"
  ON public.rider_matches
  FOR SELECT
  TO authenticated
  USING (user1_id = auth.uid() OR user2_id = auth.uid());

-- Allow service role / security definer functions to insert matches
DROP POLICY IF EXISTS "rider_matches_insert_authenticated" ON public.rider_matches;
CREATE POLICY "rider_matches_insert_authenticated"
  ON public.rider_matches
  FOR INSERT
  TO authenticated
  WITH CHECK (user1_id = auth.uid() OR user2_id = auth.uid());

-- RPC: record a swipe and return whether it created a mutual match
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
  -- Insert swipe (ignore if already exists)
  INSERT INTO public.swipes (swiper_id, swiped_id, direction)
  VALUES (v_swiper_id, p_swiped_id, p_direction)
  ON CONFLICT (swiper_id, swiped_id) DO NOTHING;

  -- If right swipe, check for mutual match
  IF p_direction = 'right' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.swipes
      WHERE swiper_id = p_swiped_id
        AND swiped_id = v_swiper_id
        AND direction = 'right'
    ) INTO v_is_match;

    IF v_is_match THEN
      -- Insert match with canonical ordering to satisfy unique index
      INSERT INTO public.rider_matches (user1_id, user2_id)
      VALUES (
        LEAST(v_swiper_id::TEXT, p_swiped_id::TEXT)::UUID,
        GREATEST(v_swiper_id::TEXT, p_swiped_id::TEXT)::UUID
      )
      ON CONFLICT DO NOTHING
      RETURNING id INTO v_match_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'is_match', v_is_match,
    'match_id', v_match_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_swipe(UUID, TEXT) TO authenticated;

-- RPC: get already-swiped profile IDs for the current user (for filtering discovery)
CREATE OR REPLACE FUNCTION public.get_swiped_ids()
RETURNS UUID[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(ARRAY_AGG(swiped_id), ARRAY[]::UUID[])
  FROM public.swipes
  WHERE swiper_id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.get_swiped_ids() TO authenticated;

-- Update the discovery RPC to also accept swiped IDs exclusion
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
  avatar_url TEXT,
  bio TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_all_excluded UUID[];
BEGIN
  -- Merge explicitly excluded IDs with already-swiped IDs
  SELECT COALESCE(ARRAY_AGG(swiped_id), ARRAY[]::UUID[])
  INTO v_all_excluded
  FROM public.swipes
  WHERE swiper_id = p_current_user_id;

  v_all_excluded := v_all_excluded || p_excluded_ids;

  -- Ensure the calling user has a profile row
  INSERT INTO public.user_profiles (id)
  VALUES (p_current_user_id)
  ON CONFLICT (id) DO NOTHING;

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
    up.avatar_url::TEXT,
    COALESCE(up.bio, '')::TEXT,
    up.latitude::DOUBLE PRECISION,
    up.longitude::DOUBLE PRECISION
  FROM public.user_profiles up
  WHERE up.id != p_current_user_id
    AND (array_length(v_all_excluded, 1) IS NULL OR up.id != ALL(v_all_excluded))
  ORDER BY up.created_at DESC NULLS LAST
  LIMIT 500;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_discovery_profiles(UUID, UUID[]) TO authenticated;
