-- Stores read-only AI diagnostic reviews generated manually or by schedule.

CREATE TABLE IF NOT EXISTS public.admin_diagnostic_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  trigger_source TEXT NOT NULL DEFAULT 'manual'
    CHECK (trigger_source IN ('manual', 'scheduled')),
  created_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  days INTEGER NOT NULL DEFAULT 30,
  total_events INTEGER NOT NULL DEFAULT 0,
  grouped_issues INTEGER NOT NULL DEFAULT 0,
  review JSONB NOT NULL DEFAULT '{}'::JSONB,
  maintenance JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.admin_diagnostic_reviews ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_profiles
    WHERE id = auth.uid()
      AND is_admin = TRUE
  );
$$;

DROP POLICY IF EXISTS "admins_read_admin_diagnostic_reviews"
ON public.admin_diagnostic_reviews;
CREATE POLICY "admins_read_admin_diagnostic_reviews"
ON public.admin_diagnostic_reviews
FOR SELECT TO authenticated
USING (public.is_admin_user());

DROP POLICY IF EXISTS "service_role_all_admin_diagnostic_reviews"
ON public.admin_diagnostic_reviews;
CREATE POLICY "service_role_all_admin_diagnostic_reviews"
ON public.admin_diagnostic_reviews
FOR ALL TO service_role
USING (TRUE)
WITH CHECK (TRUE);

CREATE INDEX IF NOT EXISTS idx_admin_diagnostic_reviews_generated_at
  ON public.admin_diagnostic_reviews(generated_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_diagnostic_reviews_trigger_generated
  ON public.admin_diagnostic_reviews(trigger_source, generated_at DESC);
