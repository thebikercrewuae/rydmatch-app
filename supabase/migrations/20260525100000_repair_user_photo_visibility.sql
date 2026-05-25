-- Ensure profile and bike photos remain visible to matched/discovery users.
-- Earlier installs may already have the bucket, so ON CONFLICT DO NOTHING
-- would not have changed a private bucket back to public.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'user-photos',
    'user-photos',
    true,
    10485760,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE
SET
    public = true,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "public_read_user_photos" ON storage.objects;
CREATE POLICY "public_read_user_photos" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'user-photos');

DROP POLICY IF EXISTS "authenticated_upload_user_photos" ON storage.objects;
CREATE POLICY "authenticated_upload_user_photos" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'user-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "authenticated_update_user_photos" ON storage.objects;
CREATE POLICY "authenticated_update_user_photos" ON storage.objects
FOR UPDATE TO authenticated
USING (
    bucket_id = 'user-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'user-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "authenticated_delete_user_photos" ON storage.objects;
CREATE POLICY "authenticated_delete_user_photos" ON storage.objects
FOR DELETE TO authenticated
USING (
    bucket_id = 'user-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

UPDATE public.user_profiles
SET avatar_url = NULL
WHERE avatar_url LIKE 'blob:%'
   OR avatar_url LIKE 'file:%';
