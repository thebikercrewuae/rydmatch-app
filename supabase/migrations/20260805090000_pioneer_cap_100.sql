-- Cap Pioneer membership at 100 (down from 500) for greater exclusivity.
-- Current membership is well below 100, so no rows are affected.

-- 1. Replace the pioneer_number check constraint (1-500 -> 1-100).
--    The original inline check has an auto-generated name, so drop whatever
--    check constraint exists on the column, then add an explicitly named one.
DO $$
DECLARE
  v_conname text;
BEGIN
  SELECT c.conname INTO v_conname
  FROM pg_constraint c
  JOIN pg_class rel ON rel.oid = c.conrelid
  JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
  WHERE nsp.nspname = 'public'
    AND rel.relname = 'pioneer_members'
    AND c.contype = 'c'
    AND pg_get_constraintdef(c.oid) ILIKE '%pioneer_number%';

  IF v_conname IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.pioneer_members DROP CONSTRAINT %I', v_conname);
  END IF;
END;
$$;

ALTER TABLE public.pioneer_members
  ADD CONSTRAINT pioneer_members_pioneer_number_check
  CHECK (pioneer_number between 1 and 100);

-- 2. Recreate the claim helper with the new cap (stop awarding past #100).
CREATE OR REPLACE FUNCTION public._claim_pioneer_membership(p_user_id uuid)
RETURNS TABLE (
  user_id uuid,
  pioneer_number smallint,
  awarded_at timestamptz,
  early_access_enabled boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
declare
  v_email text;
  v_next_number integer;
begin
  if p_user_id is null then
    return;
  end if;

  perform pg_advisory_xact_lock(hashtext('rydmatch_pioneer_members'));

  return query
  select
    pm.user_id,
    pm.pioneer_number,
    pm.awarded_at,
    pm.early_access_enabled
  from public.pioneer_members pm
  where pm.user_id = p_user_id;

  if found then
    return;
  end if;

  select lower(au.email)
  into v_email
  from auth.users au
  where au.id = p_user_id;

  if v_email is null
    or v_email = 'reviewer@rydmatch.com'
    or v_email like '%@rydmatch.test'
    or v_email like 'loadtest-%'
  then
    return;
  end if;

  if not exists (
    select 1
    from public.user_profiles up
    where up.id = p_user_id
      and up.is_profile_complete is true
  ) then
    return;
  end if;

  select coalesce(max(pm.pioneer_number), 0) + 1
  into v_next_number
  from public.pioneer_members pm;

  if v_next_number > 100 then
    return;
  end if;

  insert into public.pioneer_members (
    pioneer_number,
    user_id
  )
  values (
    v_next_number::smallint,
    p_user_id
  )
  on conflict on constraint pioneer_members_user_id_key do nothing;

  return query
  select
    pm.user_id,
    pm.pioneer_number,
    pm.awarded_at,
    pm.early_access_enabled
  from public.pioneer_members pm
  where pm.user_id = p_user_id;
end;
$$;

REVOKE ALL ON FUNCTION public._claim_pioneer_membership(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public._claim_pioneer_membership(uuid) TO authenticated;

-- 3. Verify
SELECT count(*) AS pioneer_count, max(pioneer_number) AS highest_number
FROM public.pioneer_members;