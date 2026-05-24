-- Allow a ride creator to create in-app notifications for riders they invited.
-- The policy only permits ride_group_invite notifications that match an
-- existing invite created by the authenticated user.

DROP POLICY IF EXISTS "creators_insert_ride_group_invite_notifications"
ON public.notifications;

CREATE POLICY "creators_insert_ride_group_invite_notifications"
ON public.notifications
FOR INSERT
TO authenticated
WITH CHECK (
  notification_type = 'ride_group_invite'
  AND action_arguments ? 'group_id'
  AND EXISTS (
    SELECT 1
    FROM public.ride_group_invites rgi
    WHERE rgi.group_id = (action_arguments ->> 'group_id')::uuid
      AND rgi.invitee_id = notifications.user_id
      AND rgi.inviter_id = auth.uid()
  )
);
