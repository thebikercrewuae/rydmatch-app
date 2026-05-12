-- ride_ratings table migration
CREATE TABLE IF NOT EXISTS public.ride_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reviewer_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    reviewed_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    stars INTEGER NOT NULL CHECK (stars >= 1 AND stars <= 5),
    category_ratings JSONB DEFAULT '{}'::jsonb,
    safety_tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT no_self_rating CHECK (reviewer_id != reviewed_id)
);

CREATE INDEX IF NOT EXISTS idx_ride_ratings_reviewer_id ON public.ride_ratings(reviewer_id);
CREATE INDEX IF NOT EXISTS idx_ride_ratings_reviewed_id ON public.ride_ratings(reviewed_id);
CREATE INDEX IF NOT EXISTS idx_ride_ratings_created_at ON public.ride_ratings(created_at DESC);

ALTER TABLE public.ride_ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_can_create_ratings" ON public.ride_ratings;
CREATE POLICY "users_can_create_ratings"
ON public.ride_ratings
FOR INSERT
TO authenticated
WITH CHECK (reviewer_id = auth.uid());

DROP POLICY IF EXISTS "users_can_view_ratings" ON public.ride_ratings;
CREATE POLICY "users_can_view_ratings"
ON public.ride_ratings
FOR SELECT
TO authenticated
USING (reviewer_id = auth.uid() OR reviewed_id = auth.uid());

DROP POLICY IF EXISTS "users_cannot_update_ratings" ON public.ride_ratings;
CREATE POLICY "users_cannot_update_ratings"
ON public.ride_ratings
FOR UPDATE
TO authenticated
USING (reviewer_id = auth.uid())
WITH CHECK (reviewer_id = auth.uid());

DROP POLICY IF EXISTS "users_can_delete_own_ratings" ON public.ride_ratings;
CREATE POLICY "users_can_delete_own_ratings"
ON public.ride_ratings
FOR DELETE
TO authenticated
USING (reviewer_id = auth.uid());
