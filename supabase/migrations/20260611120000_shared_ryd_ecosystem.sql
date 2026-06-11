-- RydMotion tables for the shared RydMatch Supabase project.
-- All tables are namespaced with motion_ to avoid collisions with RydMatch.

CREATE TABLE IF NOT EXISTS public.motion_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL DEFAULT '',
  activity_type text NOT NULL DEFAULT 'circuit',
  experience_level text NOT NULL DEFAULT 'intermediate',
  speed_unit text NOT NULL DEFAULT 'kmh',
  distance_unit text NOT NULL DEFAULT 'km',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.motion_vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  manufacturer text NOT NULL DEFAULT '',
  model text NOT NULL DEFAULT '',
  year integer,
  vehicle_type text NOT NULL DEFAULT 'car',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.motion_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  manufacturer text NOT NULL DEFAULT '',
  model text NOT NULL DEFAULT '',
  device_type text NOT NULL DEFAULT 'other',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.motion_tracks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  country text NOT NULL DEFAULT '',
  layout_name text NOT NULL DEFAULT '',
  distance_meters integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.motion_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vehicle_id uuid REFERENCES public.motion_vehicles(id) ON DELETE SET NULL,
  track_id uuid REFERENCES public.motion_tracks(id) ON DELETE SET NULL,
  activity_type text NOT NULL DEFAULT 'circuit',
  session_date timestamptz NOT NULL DEFAULT now(),
  fastest_lap_ms integer,
  theoretical_best_lap_ms integer,
  lap_count integer NOT NULL DEFAULT 0,
  processing_status text NOT NULL DEFAULT 'pending',
  data_confidence numeric(4,3) NOT NULL DEFAULT 0 CHECK (data_confidence BETWEEN 0 AND 1),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.motion_laps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.motion_sessions(id) ON DELETE CASCADE,
  lap_number integer NOT NULL,
  lap_time_ms integer NOT NULL,
  is_fastest boolean NOT NULL DEFAULT false,
  is_valid boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.motion_corners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  track_id uuid NOT NULL REFERENCES public.motion_tracks(id) ON DELETE CASCADE,
  corner_number integer NOT NULL,
  name text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.motion_lap_corner_metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lap_id uuid NOT NULL REFERENCES public.motion_laps(id) ON DELETE CASCADE,
  corner_id uuid NOT NULL REFERENCES public.motion_corners(id) ON DELETE CASCADE,
  braking_point_meters numeric(8,2),
  minimum_speed numeric(6,2),
  exit_speed numeric(6,2),
  time_delta_ms integer,
  confidence numeric(4,3) NOT NULL DEFAULT 0 CHECK (confidence BETWEEN 0 AND 1),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.motion_coaching_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.motion_sessions(id) ON DELETE CASCADE,
  corner_id uuid REFERENCES public.motion_corners(id) ON DELETE SET NULL,
  priority integer NOT NULL DEFAULT 1,
  observation text NOT NULL DEFAULT '',
  evidence text NOT NULL DEFAULT '',
  suggested_action text NOT NULL DEFAULT '',
  estimated_time_opportunity_ms integer,
  confidence numeric(4,3) NOT NULL DEFAULT 0 CHECK (confidence BETWEEN 0 AND 1),
  video_timestamp_ms integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.motion_stories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id uuid REFERENCES public.motion_sessions(id) ON DELETE SET NULL,
  title text NOT NULL DEFAULT '',
  caption text NOT NULL DEFAULT '',
  aspect_ratio text NOT NULL DEFAULT '16_9',
  status text NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS motion_vehicles_user_id_idx ON public.motion_vehicles(user_id);
CREATE INDEX IF NOT EXISTS motion_devices_user_id_idx ON public.motion_devices(user_id);
CREATE INDEX IF NOT EXISTS motion_sessions_user_id_idx ON public.motion_sessions(user_id);
CREATE INDEX IF NOT EXISTS motion_laps_session_id_idx ON public.motion_laps(session_id);
CREATE INDEX IF NOT EXISTS motion_metrics_lap_id_idx ON public.motion_lap_corner_metrics(lap_id);
CREATE INDEX IF NOT EXISTS motion_insights_session_id_idx ON public.motion_coaching_insights(session_id);
CREATE INDEX IF NOT EXISTS motion_stories_user_id_idx ON public.motion_stories(user_id);

ALTER TABLE public.motion_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.motion_vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.motion_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.motion_tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.motion_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.motion_laps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.motion_corners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.motion_lap_corner_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.motion_coaching_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.motion_stories ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'motion_profiles', 'motion_vehicles', 'motion_devices', 'motion_sessions',
    'motion_laps', 'motion_lap_corner_metrics', 'motion_coaching_insights',
    'motion_stories'
  ]
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS users_manage_own_rows ON public.%I', table_name);
    EXECUTE format(
      'CREATE POLICY users_manage_own_rows ON public.%I FOR ALL TO authenticated USING (%I = auth.uid()) WITH CHECK (%I = auth.uid())',
      table_name,
      CASE WHEN table_name = 'motion_profiles' THEN 'user_id' ELSE 'user_id' END,
      CASE WHEN table_name = 'motion_profiles' THEN 'user_id' ELSE 'user_id' END
    );
  END LOOP;
END $$;

DROP POLICY IF EXISTS authenticated_read_motion_tracks ON public.motion_tracks;
CREATE POLICY authenticated_read_motion_tracks
ON public.motion_tracks FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS authenticated_read_motion_corners ON public.motion_corners;
CREATE POLICY authenticated_read_motion_corners
ON public.motion_corners FOR SELECT TO authenticated USING (true);

GRANT ALL ON TABLE
  public.motion_profiles,
  public.motion_vehicles,
  public.motion_devices,
  public.motion_sessions,
  public.motion_laps,
  public.motion_lap_corner_metrics,
  public.motion_coaching_insights,
  public.motion_stories
TO authenticated;

GRANT SELECT ON TABLE
  public.motion_tracks,
  public.motion_corners
TO authenticated;
