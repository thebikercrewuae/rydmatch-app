-- Keep notification schema aligned with current app writers.
ALTER TYPE public.notification_type ADD VALUE IF NOT EXISTS 'ride_started';

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS reference_id UUID;

CREATE INDEX IF NOT EXISTS idx_notifications_type_created
  ON public.notifications(notification_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_reference_id
  ON public.notifications(reference_id);
