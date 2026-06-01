-- Allow admin diagnostics to audit matching health without exposing data to normal users.

ALTER TABLE public.swipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rider_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admins_read_swipes" ON public.swipes;
CREATE POLICY "admins_read_swipes"
ON public.swipes
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.user_profiles up
    WHERE up.id = auth.uid()
      AND up.is_admin = TRUE
  )
);

DROP POLICY IF EXISTS "admins_read_rider_matches" ON public.rider_matches;
CREATE POLICY "admins_read_rider_matches"
ON public.rider_matches
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.user_profiles up
    WHERE up.id = auth.uid()
      AND up.is_admin = TRUE
  )
);

DROP POLICY IF EXISTS "admins_read_matches" ON public.matches;
CREATE POLICY "admins_read_matches"
ON public.matches
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.user_profiles up
    WHERE up.id = auth.uid()
      AND up.is_admin = TRUE
  )
);
