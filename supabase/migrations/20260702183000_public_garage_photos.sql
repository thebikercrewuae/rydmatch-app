-- Expose only garage photo URLs needed by authenticated profile viewers.
-- Garage details remain protected by the existing owner-only RLS policy.
CREATE OR REPLACE FUNCTION public.get_public_garage_photos(
  p_user_ids UUID[]
)
RETURNS TABLE (
  user_id UUID,
  photo_url TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT gb.user_id, gb.photo_url
  FROM public.garage_bikes AS gb
  WHERE auth.uid() IS NOT NULL
    AND gb.user_id = ANY(COALESCE(p_user_ids, ARRAY[]::UUID[]))
    AND NULLIF(BTRIM(gb.photo_url), '') IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.user_blocks AS ub
      WHERE (ub.blocker_id = auth.uid() AND ub.blocked_id = gb.user_id)
         OR (ub.blocker_id = gb.user_id AND ub.blocked_id = auth.uid())
    )
  ORDER BY gb.is_primary DESC, gb.created_at DESC;
$$;

REVOKE ALL ON FUNCTION public.get_public_garage_photos(UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_garage_photos(UUID[]) TO authenticated;