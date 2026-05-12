-- Migration: Clear broken blob: URLs from user_profiles.avatar_url
-- Sets avatar_url to NULL for any row where the value starts with 'blob:'
-- so those users see a placeholder image instead of a broken image.

UPDATE public.user_profiles
SET avatar_url = NULL
WHERE avatar_url LIKE 'blob:%';

-- Log how many rows were affected
DO $$
DECLARE
  affected_count INTEGER;
BEGIN
  GET DIAGNOSTICS affected_count = ROW_COUNT;
  RAISE NOTICE 'Cleared blob: avatar_url for % user(s)', affected_count;
END $$;
