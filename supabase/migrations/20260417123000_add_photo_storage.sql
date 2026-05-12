-- Add photo_url column to garage_bikes table
ALTER TABLE public.garage_bikes
ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Create public bucket for user photos (profile + bike photos)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'user-photos',
    'user-photos',
    true,
    10485760,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- RLS: Anyone can view public photos
DROP POLICY IF EXISTS "public_read_user_photos" ON storage.objects;
CREATE POLICY "public_read_user_photos" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'user-photos');

-- RLS: Authenticated users can upload their own photos
DROP POLICY IF EXISTS "authenticated_upload_user_photos" ON storage.objects;
CREATE POLICY "authenticated_upload_user_photos" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'user-photos' AND (storage.foldername(name))[1] = auth.uid()::text);

-- RLS: Users can update their own photos
DROP POLICY IF EXISTS "authenticated_update_user_photos" ON storage.objects;
CREATE POLICY "authenticated_update_user_photos" ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'user-photos' AND owner = auth.uid());

-- RLS: Users can delete their own photos
DROP POLICY IF EXISTS "authenticated_delete_user_photos" ON storage.objects;
CREATE POLICY "authenticated_delete_user_photos" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'user-photos' AND owner = auth.uid());
