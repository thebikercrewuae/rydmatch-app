-- Rider Verifications Table
CREATE TABLE IF NOT EXISTS public.rider_verifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  document_type TEXT NOT NULL CHECK (document_type IN ('riding_licence', 'national_id', 'passport')),
  document_url TEXT,
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewer_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Unique constraint: one active verification per user
CREATE UNIQUE INDEX IF NOT EXISTS rider_verifications_user_id_idx
  ON public.rider_verifications(user_id)
  WHERE status IN ('pending', 'approved');

-- RLS
ALTER TABLE public.rider_verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own verification" ON public.rider_verifications;
CREATE POLICY "Users can view own verification"
  ON public.rider_verifications FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own verification" ON public.rider_verifications;
CREATE POLICY "Users can insert own verification"
  ON public.rider_verifications FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own pending verification" ON public.rider_verifications;
CREATE POLICY "Users can update own pending verification"
  ON public.rider_verifications FOR UPDATE
  USING (auth.uid() = user_id AND status = 'pending');

-- Allow reading verified status of other users (for badge display)
DROP POLICY IF EXISTS "Anyone can check verified status" ON public.rider_verifications;
CREATE POLICY "Anyone can check verified status"
  ON public.rider_verifications FOR SELECT
  USING (status = 'approved');

-- Storage bucket for verification documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'verification-docs',
  'verification-docs',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS
DROP POLICY IF EXISTS "Users can upload own verification docs" ON storage.objects;
CREATE POLICY "Users can upload own verification docs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'verification-docs' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "Users can view own verification docs" ON storage.objects;
CREATE POLICY "Users can view own verification docs"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'verification-docs' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
