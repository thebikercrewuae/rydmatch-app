-- Let ride groups support larger tester groups while preserving the
-- existing member-count safety cap.

ALTER TABLE public.ride_groups
  ALTER COLUMN max_riders SET DEFAULT 15;

UPDATE public.ride_groups
SET max_riders = 15,
    updated_at = CURRENT_TIMESTAMP
WHERE max_riders < 15;

NOTIFY pgrst, 'reload schema';
