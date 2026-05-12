-- Block and Report System Migration
-- Creates user_blocks and user_reports tables with proper RLS

-- ── user_blocks table ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT user_blocks_unique UNIQUE (blocker_id, blocked_id),
  CONSTRAINT user_blocks_no_self_block CHECK (blocker_id != blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker_id ON public.user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked_id ON public.user_blocks(blocked_id);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_manage_own_blocks" ON public.user_blocks;
CREATE POLICY "users_manage_own_blocks"
  ON public.user_blocks
  FOR ALL
  TO authenticated
  USING (blocker_id = auth.uid())
  WITH CHECK (blocker_id = auth.uid());

DROP POLICY IF EXISTS "users_view_blocks_against_them" ON public.user_blocks;
CREATE POLICY "users_view_blocks_against_them"
  ON public.user_blocks
  FOR SELECT
  TO authenticated
  USING (blocked_id = auth.uid());

-- ── user_reports table ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  reported_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  details TEXT,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT user_reports_no_self_report CHECK (reporter_id != reported_id)
);

CREATE INDEX IF NOT EXISTS idx_user_reports_reporter_id ON public.user_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_reported_id ON public.user_reports(reported_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_status ON public.user_reports(status);

ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_create_own_reports" ON public.user_reports;
CREATE POLICY "users_create_own_reports"
  ON public.user_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (reporter_id = auth.uid());

DROP POLICY IF EXISTS "users_view_own_reports" ON public.user_reports;
CREATE POLICY "users_view_own_reports"
  ON public.user_reports
  FOR SELECT
  TO authenticated
  USING (reporter_id = auth.uid());
