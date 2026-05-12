-- Ride Feed: posts, likes, comments
-- Timestamp: 20260307200000

-- 1. Tables
CREATE TABLE IF NOT EXISTS public.ride_feed_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    caption TEXT,
    photo_url TEXT,
    route_name TEXT,
    distance NUMERIC(10, 2) DEFAULT 0,
    distance_unit TEXT DEFAULT 'km',
    bike_name TEXT,
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.post_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.ride_feed_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_post_likes_unique ON public.post_likes(post_id, user_id);

CREATE TABLE IF NOT EXISTS public.post_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.ride_feed_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. Indexes
CREATE INDEX IF NOT EXISTS idx_ride_feed_posts_user_id ON public.ride_feed_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_ride_feed_posts_created_at ON public.ride_feed_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON public.post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON public.post_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON public.post_comments(post_id);

-- 3. Functions
CREATE OR REPLACE FUNCTION public.increment_post_likes(post_uuid UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.ride_feed_posts
    SET likes_count = likes_count + 1, updated_at = now()
    WHERE id = post_uuid;
END;
$$;

CREATE OR REPLACE FUNCTION public.decrement_post_likes(post_uuid UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.ride_feed_posts
    SET likes_count = GREATEST(0, likes_count - 1), updated_at = now()
    WHERE id = post_uuid;
END;
$$;

CREATE OR REPLACE FUNCTION public.increment_post_comments(post_uuid UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.ride_feed_posts
    SET comments_count = comments_count + 1, updated_at = now()
    WHERE id = post_uuid;
END;
$$;

-- 4. Enable RLS
ALTER TABLE public.ride_feed_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies
-- ride_feed_posts: authenticated users can read all posts (app filters by matches), own write
DROP POLICY IF EXISTS "authenticated_read_ride_feed_posts" ON public.ride_feed_posts;
CREATE POLICY "authenticated_read_ride_feed_posts"
ON public.ride_feed_posts
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "users_insert_own_ride_feed_posts" ON public.ride_feed_posts;
CREATE POLICY "users_insert_own_ride_feed_posts"
ON public.ride_feed_posts
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "users_update_own_ride_feed_posts" ON public.ride_feed_posts;
CREATE POLICY "users_update_own_ride_feed_posts"
ON public.ride_feed_posts
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "users_delete_own_ride_feed_posts" ON public.ride_feed_posts;
CREATE POLICY "users_delete_own_ride_feed_posts"
ON public.ride_feed_posts
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- post_likes
DROP POLICY IF EXISTS "authenticated_read_post_likes" ON public.post_likes;
CREATE POLICY "authenticated_read_post_likes"
ON public.post_likes
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "users_manage_own_post_likes" ON public.post_likes;
CREATE POLICY "users_manage_own_post_likes"
ON public.post_likes
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- post_comments
DROP POLICY IF EXISTS "authenticated_read_post_comments" ON public.post_comments;
CREATE POLICY "authenticated_read_post_comments"
ON public.post_comments
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "users_manage_own_post_comments" ON public.post_comments;
CREATE POLICY "users_manage_own_post_comments"
ON public.post_comments
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
