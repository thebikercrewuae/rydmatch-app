-- Repo drift capture: ad-hoc objects from the live database that had no migration.
-- Brings the repo in sync with live. Safe to run on live (IF NOT EXISTS / OR REPLACE).
-- Generated from live DB introspection 2026-07-31.

-- =========== 1. Verification feature (app-used) ===========
CREATE TABLE IF NOT EXISTS public.verification_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  license_front_path TEXT NOT NULL,
  license_back_path TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  rejection_reason TEXT,
  submitted_at TIMESTAMPTZ DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);
ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can create own verification requests" ON public.verification_requests;
CREATE POLICY "Users can create own verification requests" ON public.verification_requests FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own pending verification requests" ON public.verification_requests;
CREATE POLICY "Users can update own pending verification requests" ON public.verification_requests FOR UPDATE TO authenticated USING (auth.uid() = user_id AND status = 'pending') WITH CHECK (auth.uid() = user_id AND status = 'pending');
DROP POLICY IF EXISTS "Users can view own verification requests" ON public.verification_requests;
CREATE POLICY "Users can view own verification requests" ON public.verification_requests FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS verification_requests_status_idx ON public.verification_requests (status);
CREATE INDEX IF NOT EXISTS verification_requests_user_id_idx ON public.verification_requests (user_id);

-- =========== 2. Conversations (send route to rider) ===========
CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider1_id UUID REFERENCES auth.users(id),
  rider2_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  last_message TEXT,
  last_message_at TIMESTAMPTZ
);
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can read own conversations" ON public.conversations;
CREATE POLICY "Users can read own conversations" ON public.conversations FOR SELECT TO authenticated USING (rider1_id = auth.uid() OR rider2_id = auth.uid());
DROP POLICY IF EXISTS "Users can update own conversations" ON public.conversations;
CREATE POLICY "Users can update own conversations" ON public.conversations FOR UPDATE TO authenticated USING (rider1_id = auth.uid() OR rider2_id = auth.uid());

-- =========== 3. Waitlist ===========
CREATE TABLE IF NOT EXISTS public.waitlist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  source TEXT DEFAULT 'unknown',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public insert" ON public.waitlist;
CREATE POLICY "Allow public insert" ON public.waitlist FOR INSERT WITH CHECK (true);
CREATE INDEX IF NOT EXISTS waitlist_created_at_idx ON public.waitlist (created_at DESC);
CREATE INDEX IF NOT EXISTS waitlist_email_idx ON public.waitlist (email);

-- =========== 4. Launch waitlist ===========
CREATE TABLE IF NOT EXISTS public.launch_waitlist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE CHECK (email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),
  full_name TEXT,
  city TEXT,
  country TEXT,
  platform TEXT NOT NULL DEFAULT 'both' CHECK (platform = ANY (ARRAY['ios','android','both'])),
  ride_type TEXT NOT NULL DEFAULT 'both' CHECK (ride_type = ANY (ARRAY['motorcycle','bicycle','both'])),
  referral_source TEXT,
  source_path TEXT,
  user_agent TEXT,
  consent_marketing BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.launch_waitlist ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can join launch waitlist" ON public.launch_waitlist;
CREATE POLICY "Anyone can join launch waitlist" ON public.launch_waitlist FOR INSERT WITH CHECK (consent_marketing = true AND email IS NOT NULL AND email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$');
CREATE INDEX IF NOT EXISTS launch_waitlist_created_at_idx ON public.launch_waitlist (created_at DESC);
CREATE INDEX IF NOT EXISTS launch_waitlist_platform_idx ON public.launch_waitlist (platform);

-- =========== 5. Premium subscriptions ===========
CREATE TABLE IF NOT EXISTS public.premium_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  stripe_customer_id TEXT,
  stripe_session_id TEXT,
  stripe_subscription_id TEXT,
  plan_id TEXT NOT NULL,
  plan_name TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  currency TEXT DEFAULT 'usd',
  status TEXT DEFAULT 'pending',
  activated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.premium_subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users_view_own_subscriptions" ON public.premium_subscriptions;
CREATE POLICY "users_view_own_subscriptions" ON public.premium_subscriptions FOR SELECT TO authenticated USING (user_id = auth.uid());
DROP POLICY IF EXISTS "users_insert_own_subscriptions" ON public.premium_subscriptions;
CREATE POLICY "users_insert_own_subscriptions" ON public.premium_subscriptions FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE INDEX IF NOT EXISTS idx_premium_subscriptions_user_id ON public.premium_subscriptions (user_id);
CREATE INDEX IF NOT EXISTS idx_premium_subscriptions_stripe_session ON public.premium_subscriptions (stripe_session_id);
CREATE INDEX IF NOT EXISTS idx_premium_subscriptions_stripe_sub ON public.premium_subscriptions (stripe_subscription_id);

-- =========== 6. Motion rider samples ===========
CREATE TABLE IF NOT EXISTS public.motion_rider_samples (
  id BIGINT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id UUID NOT NULL REFERENCES public.motion_sessions(id) ON DELETE CASCADE,
  sample_index INTEGER NOT NULL,
  elapsed_ms INTEGER NOT NULL,
  acceleration_x DOUBLE PRECISION NOT NULL,
  acceleration_y DOUBLE PRECISION NOT NULL,
  acceleration_z DOUBLE PRECISION NOT NULL,
  rotation_x DOUBLE PRECISION NOT NULL,
  rotation_y DOUBLE PRECISION NOT NULL,
  rotation_z DOUBLE PRECISION NOT NULL,
  lean_angle_degrees DOUBLE PRECISION NOT NULL,
  lateral_g DOUBLE PRECISION NOT NULL,
  longitudinal_g DOUBLE PRECISION NOT NULL,
  vibration_g DOUBLE PRECISION NOT NULL,
  source TEXT NOT NULL DEFAULT 'phone_suit_hump',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (session_id, sample_index)
);
ALTER TABLE public.motion_rider_samples ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "motion_rider_samples_select_own" ON public.motion_rider_samples;
CREATE POLICY "motion_rider_samples_select_own" ON public.motion_rider_samples FOR SELECT TO authenticated USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "motion_rider_samples_insert_own" ON public.motion_rider_samples;
CREATE POLICY "motion_rider_samples_insert_own" ON public.motion_rider_samples FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "motion_rider_samples_delete_own" ON public.motion_rider_samples;
CREATE POLICY "motion_rider_samples_delete_own" ON public.motion_rider_samples FOR DELETE TO authenticated USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS motion_rider_samples_session_elapsed_idx ON public.motion_rider_samples (session_id, elapsed_ms);

-- =========== 7. Motion track markers ===========
CREATE TABLE IF NOT EXISTS public.motion_track_markers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_key TEXT NOT NULL UNIQUE,
  venue_name TEXT NOT NULL,
  start_finish_latitude DOUBLE PRECISION NOT NULL,
  start_finish_longitude DOUBLE PRECISION NOT NULL,
  match_radius_meters INTEGER NOT NULL DEFAULT 2500,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  layouts TEXT[] NOT NULL DEFAULT '{}'::text[]
);
ALTER TABLE public.motion_track_markers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "authenticated_read_motion_track_markers" ON public.motion_track_markers;
CREATE POLICY "authenticated_read_motion_track_markers" ON public.motion_track_markers FOR SELECT TO authenticated USING (true);
-- =========== Functions (from live DB pg_get_functiondef) ===========

-- Verification: submit
CREATE OR REPLACE FUNCTION public.submit_verification_request(license_front_path text, license_back_path text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare
  request_id uuid;
begin
  insert into public.verification_requests (user_id, license_front_path, license_back_path, status)
  values (auth.uid(), license_front_path, license_back_path, 'pending')
  returning id into request_id;
  update public.user_profiles set verification_status = 'pending', updated_at = now() where id = auth.uid();
  return request_id;
end;
$function$;

-- Verification: review (admin)
CREATE OR REPLACE FUNCTION public.review_verification_request(request_id_param uuid, approved_param boolean, rejection_reason_param text DEFAULT NULL::text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare
  target_user_id uuid;
  next_status text;
begin
  if not public.is_admin_user() then raise exception 'Not authorized'; end if;
  select user_id into target_user_id from public.verification_requests where id = request_id_param;
  if target_user_id is null then raise exception 'Verification request not found'; end if;
  next_status := case when approved_param then 'approved' else 'rejected' end;
  update public.verification_requests set status = next_status, rejection_reason = case when approved_param then null else rejection_reason_param end, reviewed_at = now(), reviewed_by = auth.uid() where id = request_id_param;
  update public.user_profiles set is_verified = approved_param, verification_status = next_status, updated_at = now() where id = target_user_id;
  return true;
end;
$function$;

-- Verification: list (admin)
CREATE OR REPLACE FUNCTION public.list_verification_requests()
RETURNS TABLE(request_id uuid, user_id uuid, full_name text, email text, status text, rejection_reason text, license_front_path text, license_back_path text, submitted_at timestamp with time zone)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin_user() then raise exception 'Not authorized'; end if;
  return query
  select vr.id as request_id, vr.user_id, up.full_name, up.email, vr.status, vr.rejection_reason, vr.license_front_path, vr.license_back_path, vr.submitted_at
  from public.verification_requests vr
  left join public.user_profiles up on up.id = vr.user_id
  where vr.status in ('pending', 'needs_more_info')
  order by vr.submitted_at asc;
end;
$function$;

-- Ride group invite notification trigger function
CREATE OR REPLACE FUNCTION public.create_ride_group_invite_notification()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
begin
  insert into public.notifications (user_id, notification_type, title, message, is_read, action_route, action_arguments, reference_id, created_at)
  values (new.invitee_id, 'ride_group_invite'::notification_type, 'New group ride invite', 'You have been invited to ' || coalesce(new.group_name, 'a group ride'), false, '/ride-groups-screen', jsonb_build_object('group_id', new.group_id, 'group_name', new.group_name, 'source', 'ride_group_invite'), new.group_id::text, coalesce(new.created_at, now()));
  return new;
end;
$function$;

-- New message notification trigger function
CREATE OR REPLACE FUNCTION public.notify_new_message()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO notifications (user_id, notification_type, title, message, is_read, reference_id, created_at)
  VALUES (NEW.recipient_id, 'new_message', 'New Message', LEFT(NEW.message_body, 100), false, NEW.sender_id::text, now());
  RETURN NEW;
END;
$function$;

-- Delete old ride group (creator only)
CREATE OR REPLACE FUNCTION public.delete_old_ride_group(group_id_param uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare
  current_user_id uuid := auth.uid();
  owns_ride boolean;
  session_ids uuid[];
begin
  if current_user_id is null then raise exception 'Not authenticated'; end if;
  select exists (select 1 from public.ride_groups where id = group_id_param and creator_id = current_user_id) into owns_ride;
  if not owns_ride then raise exception 'Only the creator can delete this ride'; end if;
  select coalesce(array_agg(id), array[]::uuid[]) into session_ids from public.live_ride_sessions where ride_group_id = group_id_param;
  if array_length(session_ids, 1) is not null then
    delete from public.live_ride_locations where session_id = any(session_ids);
    delete from public.live_ride_messages where session_id = any(session_ids);
    delete from public.live_ride_participants where session_id = any(session_ids);
    delete from public.notifications where reference_id in (select id::text from unnest(session_ids) as id);
  end if;
  if to_regclass('public.ride_group_members') is not null then
    execute 'delete from public.ride_group_members where group_id = $1' using group_id_param;
  end if;
  delete from public.live_ride_sessions where ride_group_id = group_id_param;
  delete from public.ride_group_invites where group_id = group_id_param;
  delete from public.notifications where reference_id = group_id_param::text;
  delete from public.ride_groups where id = group_id_param and creator_id = current_user_id;
end;
$function$;

-- Normalize launch waitlist email trigger function
CREATE OR REPLACE FUNCTION public.normalize_launch_waitlist_email()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
begin
  new.email := lower(trim(new.email));
  return new;
end;
$function$;

-- Premium subscriptions updated_at trigger function
CREATE OR REPLACE FUNCTION public.update_premium_subscriptions_updated_at()
RETURNS trigger LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- Save motion track marker
CREATE OR REPLACE FUNCTION public.save_motion_track_marker(marker_venue_key text, marker_venue_name text, marker_latitude double precision, marker_longitude double precision, marker_match_radius_meters integer DEFAULT 2500)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public'
AS $function$
  INSERT INTO public.motion_track_markers (venue_key, venue_name, start_finish_latitude, start_finish_longitude, match_radius_meters, updated_at)
  VALUES (marker_venue_key, marker_venue_name, marker_latitude, marker_longitude, marker_match_radius_meters, now())
  ON CONFLICT (venue_key) DO UPDATE SET venue_name = EXCLUDED.venue_name, start_finish_latitude = EXCLUDED.start_finish_latitude, start_finish_longitude = EXCLUDED.start_finish_longitude, match_radius_meters = EXCLUDED.match_radius_meters, updated_at = now();
$function$;

-- RLS auto-enable event trigger function
CREATE OR REPLACE FUNCTION public.rls_auto_enable()
RETURNS event_trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT * FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

-- =========== Triggers ===========
DROP TRIGGER IF EXISTS on_new_message ON public.chat_messages;
CREATE TRIGGER on_new_message AFTER INSERT ON public.chat_messages FOR EACH ROW EXECUTE FUNCTION public.notify_new_message();

DROP TRIGGER IF EXISTS ride_group_invite_notification_trigger ON public.ride_group_invites;
CREATE TRIGGER ride_group_invite_notification_trigger AFTER INSERT ON public.ride_group_invites FOR EACH ROW EXECUTE FUNCTION public.create_ride_group_invite_notification();

DROP TRIGGER IF EXISTS premium_subscriptions_updated_at ON public.premium_subscriptions;
CREATE TRIGGER premium_subscriptions_updated_at BEFORE UPDATE ON public.premium_subscriptions FOR EACH ROW EXECUTE FUNCTION public.update_premium_subscriptions_updated_at();

DROP TRIGGER IF EXISTS normalize_launch_waitlist_email_before_insert ON public.launch_waitlist;
CREATE TRIGGER normalize_launch_waitlist_email_before_insert BEFORE INSERT ON public.launch_waitlist FOR EACH ROW EXECUTE FUNCTION public.normalize_launch_waitlist_email();

-- =========== Event trigger (auto-enable RLS on new tables) ===========
DROP EVENT TRIGGER IF EXISTS rls_auto_enable;
CREATE EVENT TRIGGER rls_auto_enable ON ddl_command_end
  WHEN tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  EXECUTE FUNCTION public.rls_auto_enable();

-- =========== Grants for app-called RPCs ===========
GRANT EXECUTE ON FUNCTION public.list_verification_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_verification_request(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_verification_request(uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_old_ride_group(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_motion_track_marker(text, text, double precision, double precision, integer) TO authenticated;