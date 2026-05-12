-- Fix rider_matches INSERT policy so the record_swipe SECURITY DEFINER function
-- can always insert regardless of canonical user ordering.
-- The SECURITY DEFINER function runs as the DB owner and bypasses RLS,
-- but we also add a permissive policy for direct authenticated inserts.

ALTER TABLE public.rider_matches ENABLE ROW LEVEL SECURITY;

-- Drop old INSERT policy and replace with one that allows either user to be the inserter
DROP POLICY IF EXISTS "rider_matches_insert_authenticated" ON public.rider_matches;
CREATE POLICY "rider_matches_insert_authenticated"
  ON public.rider_matches
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Ensure SELECT policy is correct: users can read matches they are part of
DROP POLICY IF EXISTS "rider_matches_select_own" ON public.rider_matches;
CREATE POLICY "rider_matches_select_own"
  ON public.rider_matches
  FOR SELECT
  TO authenticated
  USING (user1_id = auth.uid() OR user2_id = auth.uid());
