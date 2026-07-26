create table if not exists public.pioneer_members (
  pioneer_number smallint primary key
    check (pioneer_number between 1 and 500),
  user_id uuid unique references auth.users(id) on delete set null,
  awarded_at timestamptz not null default now(),
  early_access_enabled boolean not null default true
);

alter table public.pioneer_members enable row level security;

drop policy if exists "authenticated_users_can_view_pioneer_members"
  on public.pioneer_members;
create policy "authenticated_users_can_view_pioneer_members"
  on public.pioneer_members
  for select
  to authenticated
  using (true);

create or replace function public._claim_pioneer_membership(p_user_id uuid)
returns table (
  user_id uuid,
  pioneer_number smallint,
  awarded_at timestamptz,
  early_access_enabled boolean
)
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
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

  if v_next_number > 500 then
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
  on conflict (user_id) do nothing;

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

create or replace function public.claim_pioneer_membership()
returns table (
  user_id uuid,
  pioneer_number smallint,
  awarded_at timestamptz,
  early_access_enabled boolean
)
language sql
security definer
set search_path = public, auth, pg_temp
as $$
  select *
  from public._claim_pioneer_membership(auth.uid());
$$;

create or replace function public.get_pioneer_status(p_user_ids uuid[])
returns table (
  user_id uuid,
  pioneer_number smallint,
  awarded_at timestamptz,
  early_access_enabled boolean
)
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select
    pm.user_id,
    pm.pioneer_number,
    pm.awarded_at,
    pm.early_access_enabled
  from public.pioneer_members pm
  where pm.user_id = any(coalesce(p_user_ids, array[]::uuid[]));
$$;

create or replace function public.claim_pioneer_after_profile_completion()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if new.is_profile_complete is true
    and (
      tg_op = 'INSERT'
      or old.is_profile_complete is distinct from new.is_profile_complete
    )
  then
    perform public._claim_pioneer_membership(new.id);
  end if;

  return new;
end;
$$;

drop trigger if exists claim_pioneer_after_profile_completion
  on public.user_profiles;
create trigger claim_pioneer_after_profile_completion
after insert or update of is_profile_complete
on public.user_profiles
for each row
execute function public.claim_pioneer_after_profile_completion();

do $$
declare
  v_user record;
begin
  for v_user in
    select up.id
    from public.user_profiles up
    join auth.users au on au.id = up.id
    where up.is_profile_complete is true
      and lower(au.email) <> 'reviewer@rydmatch.com'
      and lower(au.email) not like '%@rydmatch.test'
      and lower(au.email) not like 'loadtest-%'
    order by au.created_at, up.id
  loop
    perform public._claim_pioneer_membership(v_user.id);
  end loop;
end;
$$;

revoke all on function public.claim_pioneer_membership() from public;
revoke all on function public.get_pioneer_status(uuid[]) from public;
revoke all on function public._claim_pioneer_membership(uuid) from public;

grant execute on function public.claim_pioneer_membership() to authenticated;
grant execute on function public.get_pioneer_status(uuid[]) to authenticated;

