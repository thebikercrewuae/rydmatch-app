-- garage_bikes table migration
CREATE TABLE IF NOT EXISTS public.garage_bikes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    make TEXT NOT NULL,
    model TEXT NOT NULL,
    year INTEGER,
    color TEXT,
    engine_size TEXT,
    mileage TEXT,
    bike_type TEXT,
    notes TEXT,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_garage_bikes_user_id ON public.garage_bikes(user_id);
CREATE INDEX IF NOT EXISTS idx_garage_bikes_is_primary ON public.garage_bikes(user_id, is_primary);

ALTER TABLE public.garage_bikes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_manage_own_garage_bikes" ON public.garage_bikes;
CREATE POLICY "users_manage_own_garage_bikes"
ON public.garage_bikes
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
