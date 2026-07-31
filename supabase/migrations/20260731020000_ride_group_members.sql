-- "I'm home" status for ride group members. The app upserts into this table
-- when a rider marks themselves home during a group ride, but no migration
-- ever created it (a later migration only tried to index it).
CREATE TABLE IF NOT EXISTS public.ride_group_members (
  group_id UUID NOT NULL REFERENCES public.ride_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  im_home BOOLEAN NOT NULL DEFAULT false,
  im_home_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

ALTER TABLE public.ride_group_members ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS ride_group_members_group_user_idx
  ON public.ride_group_members (group_id, user_id);

DROP POLICY IF EXISTS "ride_group_members_member_read" ON public.ride_group_members;
CREATE POLICY "ride_group_members_member_read"
  ON public.ride_group_members FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.ride_groups g
      WHERE g.id = ride_group_members.group_id AND g.creator_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.ride_group_invites i
      WHERE i.group_id = ride_group_members.group_id
        AND i.invitee_id = auth.uid()
        AND i.status = 'accepted'
    )
  );

DROP POLICY IF EXISTS "ride_group_members_self_upsert" ON public.ride_group_members;
CREATE POLICY "ride_group_members_self_upsert"
  ON public.ride_group_members FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "ride_group_members_self_update" ON public.ride_group_members;
CREATE POLICY "ride_group_members_self_update"
  ON public.ride_group_members FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON public.ride_group_members TO authenticated;