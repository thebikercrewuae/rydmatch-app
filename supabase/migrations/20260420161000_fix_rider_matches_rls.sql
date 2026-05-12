-- Ensure RLS is enabled on rider_matches
ALTER TABLE public.rider_matches ENABLE ROW LEVEL SECURITY;

-- Drop and re-create the SELECT policy to ensure it allows both user1_id and user2_id
DROP POLICY IF EXISTS "rider_matches_select_own" ON public.rider_matches;
CREATE POLICY "rider_matches_select_own"
  ON public.rider_matches
  FOR SELECT
  TO authenticated
  USING (user1_id = auth.uid() OR user2_id = auth.uid());

-- Drop and re-create the INSERT policy
DROP POLICY IF EXISTS "rider_matches_insert_authenticated" ON public.rider_matches;
CREATE POLICY "rider_matches_insert_authenticated"
  ON public.rider_matches
  FOR INSERT
  TO authenticated
  WITH CHECK (user1_id = auth.uid() OR user2_id = auth.uid());
