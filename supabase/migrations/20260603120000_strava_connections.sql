create table if not exists public.strava_connections (
  user_id uuid primary key references auth.users(id) on delete cascade,
  athlete_id bigint,
  athlete_username text,
  athlete_firstname text,
  athlete_lastname text,
  scope text,
  access_token text not null,
  refresh_token text not null,
  expires_at timestamptz not null,
  athlete jsonb not null default '{}'::jsonb,
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.strava_connections enable row level security;

drop policy if exists "Users can view their own Strava connection" on public.strava_connections;
drop policy if exists "Users can delete their own Strava connection" on public.strava_connections;

-- Token rows are managed only by Supabase Edge Functions with the service role.
-- The mobile app reads status and disconnects through the strava-auth function.

create index if not exists strava_connections_athlete_id_idx
  on public.strava_connections(athlete_id);

create or replace function public.set_strava_connections_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_strava_connections_updated_at on public.strava_connections;
create trigger set_strava_connections_updated_at
  before update on public.strava_connections
  for each row
  execute function public.set_strava_connections_updated_at();
