-- Ride Groups table and participant invitations
CREATE TABLE IF NOT EXISTS public.ride_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  route TEXT NOT NULL,
  ride_date TIMESTAMPTZ NOT NULL,
  max_riders INTEGER NOT NULL DEFAULT 4,
  member_count INTEGER NOT NULL DEFAULT 1,
  leader_name TEXT NOT NULL DEFAULT 'You',
  ride_type TEXT NOT NULL DEFAULT 'Scenic',
  difficulty TEXT NOT NULL DEFAULT 'Moderate',
  duration TEXT NOT NULL DEFAULT '2h',
  route_image_url TEXT DEFAULT 'https://images.pexels.com/photos/1119796/pexels-photo-1119796.jpeg',
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ride_groups_creator_id ON public.ride_groups(creator_id);
CREATE INDEX IF NOT EXISTS idx_ride_groups_created_at ON public.ride_groups(created_at);

ALTER TABLE public.ride_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_manage_own_ride_groups" ON public.ride_groups;
CREATE POLICY "users_manage_own_ride_groups"
ON public.ride_groups
FOR ALL
TO authenticated
USING (creator_id = auth.uid())
WITH CHECK (creator_id = auth.uid());

DROP POLICY IF EXISTS "users_view_invited_ride_groups" ON public.ride_groups;
CREATE POLICY "users_view_invited_ride_groups"
ON public.ride_groups
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.ride_group_invites rgi
    WHERE rgi.group_id = id
      AND rgi.invitee_id = auth.uid()
  )
);

-- ride_group_invites already exists; add group_id FK to ride_groups if not present
ALTER TABLE public.ride_group_invites
ADD COLUMN IF NOT EXISTS group_name TEXT NOT NULL DEFAULT 'Group Ride';
