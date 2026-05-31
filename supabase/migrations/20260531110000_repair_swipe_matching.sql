-- Repair mutual swipe matching so all match-dependent app areas agree.
-- The app now reads rider_matches first, but some older features still read matches.

ALTER TABLE public.swipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rider_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_swipes_mutual_lookup
  ON public.swipes(swiper_id, swiped_id, direction);

CREATE INDEX IF NOT EXISTS idx_rider_matches_user_pair
  ON public.rider_matches(user1_id, user2_id);

CREATE INDEX IF NOT EXISTS idx_matches_user_pair
  ON public.matches(user_id, matched_user_id);

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
  v_is_match BOOLEAN := FALSE;
  v_match_id UUID;
  v_user1 UUID;
  v_user2 UUID;
BEGIN
  IF v_swiper_id IS NULL THEN
    RAISE EXCEPTION 'record_swipe requires an authenticated user';
  END IF;

  IF p_swiped_id IS NULL OR p_swiped_id = v_swiper_id THEN
    RAISE EXCEPTION 'invalid swiped user';
  END IF;

  IF p_direction NOT IN ('left', 'right') THEN
    RAISE EXCEPTION 'invalid swipe direction: %', p_direction;
  END IF;

  INSERT INTO public.swipes (swiper_id, swiped_id, direction)
  VALUES (v_swiper_id, p_swiped_id, p_direction)
  ON CONFLICT (swiper_id, swiped_id)
  DO UPDATE SET
    direction = EXCLUDED.direction,
    created_at = NOW();

  IF p_direction = 'right' THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.swipes
      WHERE swiper_id = p_swiped_id
        AND swiped_id = v_swiper_id
        AND direction = 'right'
    )
    INTO v_is_match;

    IF v_is_match THEN
      v_user1 := LEAST(v_swiper_id::TEXT, p_swiped_id::TEXT)::UUID;
      v_user2 := GREATEST(v_swiper_id::TEXT, p_swiped_id::TEXT)::UUID;

      INSERT INTO public.rider_matches (user1_id, user2_id)
      VALUES (v_user1, v_user2)
      ON CONFLICT DO NOTHING
      RETURNING id INTO v_match_id;

      IF v_match_id IS NULL THEN
        SELECT id
        INTO v_match_id
        FROM public.rider_matches
        WHERE user1_id = v_user1
          AND user2_id = v_user2
        LIMIT 1;
      END IF;

      INSERT INTO public.matches (user_id, matched_user_id)
      SELECT v_swiper_id, p_swiped_id
      WHERE NOT EXISTS (
        SELECT 1
        FROM public.matches
        WHERE user_id = v_swiper_id
          AND matched_user_id = p_swiped_id
      );

      INSERT INTO public.matches (user_id, matched_user_id)
      SELECT p_swiped_id, v_swiper_id
      WHERE NOT EXISTS (
        SELECT 1
        FROM public.matches
        WHERE user_id = p_swiped_id
          AND matched_user_id = v_swiper_id
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'is_match', v_is_match,
    'match_id', v_match_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_swipe(UUID, TEXT) TO authenticated;

INSERT INTO public.rider_matches (user1_id, user2_id)
SELECT DISTINCT
  LEAST(a.swiper_id::TEXT, a.swiped_id::TEXT)::UUID AS user1_id,
  GREATEST(a.swiper_id::TEXT, a.swiped_id::TEXT)::UUID AS user2_id
FROM public.swipes a
JOIN public.swipes b
  ON b.swiper_id = a.swiped_id
 AND b.swiped_id = a.swiper_id
WHERE a.direction = 'right'
  AND b.direction = 'right'
  AND a.swiper_id <> a.swiped_id
ON CONFLICT DO NOTHING;

INSERT INTO public.matches (user_id, matched_user_id)
SELECT rm.user1_id, rm.user2_id
FROM public.rider_matches rm
WHERE NOT EXISTS (
  SELECT 1
  FROM public.matches m
  WHERE m.user_id = rm.user1_id
    AND m.matched_user_id = rm.user2_id
);

INSERT INTO public.matches (user_id, matched_user_id)
SELECT rm.user2_id, rm.user1_id
FROM public.rider_matches rm
WHERE NOT EXISTS (
  SELECT 1
  FROM public.matches m
  WHERE m.user_id = rm.user2_id
    AND m.matched_user_id = rm.user1_id
);
