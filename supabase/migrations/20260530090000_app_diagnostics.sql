-- Lightweight app diagnostics for beta reliability.

CREATE TABLE IF NOT EXISTS public.app_errors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  feature TEXT NOT NULL,
  action TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'error',
  message TEXT NOT NULL,
  stack_trace TEXT,
  context JSONB NOT NULL DEFAULT '{}'::JSONB,
  platform TEXT,
  is_debug BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.app_errors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_insert_own_app_errors" ON public.app_errors;
CREATE POLICY "users_insert_own_app_errors"
ON public.app_errors
FOR INSERT TO authenticated
WITH CHECK (user_id IS NULL OR user_id = auth.uid());

DROP POLICY IF EXISTS "admins_read_app_errors" ON public.app_errors;
CREATE POLICY "admins_read_app_errors"
ON public.app_errors
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.user_profiles up
    WHERE up.id = auth.uid()
      AND up.is_admin = TRUE
  )
);

DROP POLICY IF EXISTS "service_role_all_app_errors" ON public.app_errors;
CREATE POLICY "service_role_all_app_errors"
ON public.app_errors
FOR ALL TO service_role
USING (TRUE)
WITH CHECK (TRUE);

CREATE INDEX IF NOT EXISTS idx_app_errors_created_at
  ON public.app_errors(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_errors_feature_created
  ON public.app_errors(feature, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_errors_user_created
  ON public.app_errors(user_id, created_at DESC);
