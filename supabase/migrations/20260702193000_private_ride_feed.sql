-- Keep Ride Feed posts private to their owner. Related engagement data is
-- visible and writable only when it belongs to a post owned by that user.
DROP POLICY IF EXISTS "authenticated_read_ride_feed_posts"
ON public.ride_feed_posts;
DROP POLICY IF EXISTS "users_read_own_ride_feed_posts"
ON public.ride_feed_posts;
CREATE POLICY "users_read_own_ride_feed_posts"
ON public.ride_feed_posts
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

DROP POLICY IF EXISTS "authenticated_read_post_likes" ON public.post_likes;
DROP POLICY IF EXISTS "users_manage_own_post_likes" ON public.post_likes;
DROP POLICY IF EXISTS "users_read_likes_on_own_posts" ON public.post_likes;
DROP POLICY IF EXISTS "users_manage_likes_on_own_posts" ON public.post_likes;

CREATE POLICY "users_read_likes_on_own_posts"
ON public.post_likes
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.ride_feed_posts AS post
    WHERE post.id = post_likes.post_id
      AND post.user_id = auth.uid()
  )
);

CREATE POLICY "users_manage_likes_on_own_posts"
ON public.post_likes
FOR ALL
TO authenticated
USING (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.ride_feed_posts AS post
    WHERE post.id = post_likes.post_id
      AND post.user_id = auth.uid()
  )
)
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.ride_feed_posts AS post
    WHERE post.id = post_likes.post_id
      AND post.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "authenticated_read_post_comments"
ON public.post_comments;
DROP POLICY IF EXISTS "users_manage_own_post_comments"
ON public.post_comments;
DROP POLICY IF EXISTS "users_read_comments_on_own_posts"
ON public.post_comments;
DROP POLICY IF EXISTS "users_manage_comments_on_own_posts"
ON public.post_comments;

CREATE POLICY "users_read_comments_on_own_posts"
ON public.post_comments
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.ride_feed_posts AS post
    WHERE post.id = post_comments.post_id
      AND post.user_id = auth.uid()
  )
);

CREATE POLICY "users_manage_comments_on_own_posts"
ON public.post_comments
FOR ALL
TO authenticated
USING (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.ride_feed_posts AS post
    WHERE post.id = post_comments.post_id
      AND post.user_id = auth.uid()
  )
)
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.ride_feed_posts AS post
    WHERE post.id = post_comments.post_id
      AND post.user_id = auth.uid()
  )
);

CREATE OR REPLACE FUNCTION public.increment_post_likes(post_uuid UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.ride_feed_posts
  SET likes_count = likes_count + 1, updated_at = now()
  WHERE id = post_uuid AND user_id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION public.decrement_post_likes(post_uuid UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.ride_feed_posts
  SET likes_count = GREATEST(0, likes_count - 1), updated_at = now()
  WHERE id = post_uuid AND user_id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION public.increment_post_comments(post_uuid UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.ride_feed_posts
  SET comments_count = comments_count + 1, updated_at = now()
  WHERE id = post_uuid AND user_id = auth.uid();
END;
$$;