CREATE TABLE IF NOT EXISTS public.app_update_config (
  id text PRIMARY KEY DEFAULT 'android',
  platform text NOT NULL DEFAULT 'android',
  latest_version_name text NOT NULL DEFAULT '1.0.19',
  latest_build_number integer NOT NULL DEFAULT 19,
  minimum_build_number integer NOT NULL DEFAULT 19,
  title text NOT NULL DEFAULT 'RydMatch update available',
  message text NOT NULL DEFAULT 'A newer version of RydMatch is available. Update now to get the latest fixes and features.',
  store_url text NOT NULL DEFAULT 'https://play.google.com/store/apps/details?id=com.rydmatch.app',
  release_notes text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_update_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated_read_app_update_config" ON public.app_update_config;
CREATE POLICY "authenticated_read_app_update_config"
ON public.app_update_config
FOR SELECT
TO authenticated
USING (is_active = true);

INSERT INTO public.app_update_config (
  id,
  platform,
  latest_version_name,
  latest_build_number,
  minimum_build_number,
  title,
  message,
  store_url,
  release_notes,
  is_active
)
VALUES (
  'android',
  'android',
  '1.0.19',
  19,
  19,
  'RydMatch update available',
  'A newer version of RydMatch is available. Update now to get the latest fixes and features.',
  'https://play.google.com/store/apps/details?id=com.rydmatch.app',
  NULL,
  true
)
ON CONFLICT (id) DO UPDATE
SET
  platform = EXCLUDED.platform,
  latest_version_name = EXCLUDED.latest_version_name,
  latest_build_number = EXCLUDED.latest_build_number,
  minimum_build_number = EXCLUDED.minimum_build_number,
  title = EXCLUDED.title,
  message = EXCLUDED.message,
  store_url = EXCLUDED.store_url,
  release_notes = EXCLUDED.release_notes,
  is_active = EXCLUDED.is_active,
  updated_at = now();

NOTIFY pgrst, 'reload schema';
