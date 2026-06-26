-- Persist motorcycle modification text entered in the garage add/edit flow.
ALTER TABLE public.garage_bikes
ADD COLUMN IF NOT EXISTS mods JSONB NOT NULL DEFAULT '[]'::jsonb;

UPDATE public.garage_bikes
SET mods = '[]'::jsonb
WHERE mods IS NULL;

COMMENT ON COLUMN public.garage_bikes.mods IS
  'User-entered motorcycle modifications displayed in garage cards and bike details.';