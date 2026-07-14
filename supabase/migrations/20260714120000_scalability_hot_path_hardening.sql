create or replace function public._rydmatch_create_index_if_columns_exist(
  p_index_name text,
  p_table_name text,
  p_columns text[],
  p_index_sql text
)
returns void
language plpgsql
as $$
begin
  if to_regclass('public.' || p_table_name) is null then
    return;
  end if;

  if exists (
    select 1
    from unnest(p_columns) as c(column_name)
    where not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = p_table_name
        and column_name = c.column_name
    )
  ) then
    return;
  end if;

  execute p_index_sql;
end;
$$;

select public._rydmatch_create_index_if_columns_exist(
  'live_ride_locations_session_updated_idx',
  'live_ride_locations',
  array['session_id', 'updated_at'],
  'create index if not exists live_ride_locations_session_updated_idx on public.live_ride_locations (session_id, updated_at desc)'
);

select public._rydmatch_create_index_if_columns_exist(
  'live_ride_locations_group_updated_idx',
  'live_ride_locations',
  array['ride_group_id', 'updated_at'],
  'create index if not exists live_ride_locations_group_updated_idx on public.live_ride_locations (ride_group_id, updated_at desc)'
);

select public._rydmatch_create_index_if_columns_exist(
  'live_ride_locations_user_updated_idx',
  'live_ride_locations',
  array['user_id', 'updated_at'],
  'create index if not exists live_ride_locations_user_updated_idx on public.live_ride_locations (user_id, updated_at desc)'
);

select public._rydmatch_create_index_if_columns_exist(
  'chat_messages_conversation_created_idx',
  'chat_messages',
  array['conversation_id', 'created_at'],
  'create index if not exists chat_messages_conversation_created_idx on public.chat_messages (conversation_id, created_at desc)'
);

select public._rydmatch_create_index_if_columns_exist(
  'chat_messages_recipient_delivery_created_idx',
  'chat_messages',
  array['recipient_id', 'delivery_status', 'created_at'],
  'create index if not exists chat_messages_recipient_delivery_created_idx on public.chat_messages (recipient_id, delivery_status, created_at desc)'
);

select public._rydmatch_create_index_if_columns_exist(
  'notifications_user_created_idx',
  'notifications',
  array['user_id', 'created_at'],
  'create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc)'
);

select public._rydmatch_create_index_if_columns_exist(
  'notifications_user_read_created_idx',
  'notifications',
  array['user_id', 'is_read', 'created_at'],
  'create index if not exists notifications_user_read_created_idx on public.notifications (user_id, is_read, created_at desc)'
);

select public._rydmatch_create_index_if_columns_exist(
  'swipes_swiper_swiped_idx',
  'swipes',
  array['swiper_id', 'swiped_id'],
  'create index if not exists swipes_swiper_swiped_idx on public.swipes (swiper_id, swiped_id)'
);

select public._rydmatch_create_index_if_columns_exist(
  'swipes_swiper_direction_created_idx',
  'swipes',
  array['swiper_id', 'direction', 'created_at'],
  'create index if not exists swipes_swiper_direction_created_idx on public.swipes (swiper_id, direction, created_at desc)'
);

select public._rydmatch_create_index_if_columns_exist(
  'ride_groups_status_created_idx',
  'ride_groups',
  array['status', 'created_at'],
  'create index if not exists ride_groups_status_created_idx on public.ride_groups (status, created_at desc)'
);

select public._rydmatch_create_index_if_columns_exist(
  'ride_group_members_group_user_idx',
  'ride_group_members',
  array['group_id', 'user_id'],
  'create index if not exists ride_group_members_group_user_idx on public.ride_group_members (group_id, user_id)'
);

select public._rydmatch_create_index_if_columns_exist(
  'app_diagnostics_severity_created_idx',
  'app_diagnostics',
  array['severity', 'created_at'],
  'create index if not exists app_diagnostics_severity_created_idx on public.app_diagnostics (severity, created_at desc)'
);

drop function public._rydmatch_create_index_if_columns_exist(text, text, text[], text);

create or replace function public.cleanup_stale_live_ride_locations(retention_minutes integer default 360)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer := 0;
  cutoff timestamptz;
begin
  if retention_minutes is null or retention_minutes < 15 then
    retention_minutes := 15;
  end if;

  cutoff := now() - make_interval(mins => retention_minutes);

  if to_regclass('public.live_ride_locations') is not null
     and exists (
       select 1 from information_schema.columns
       where table_schema = 'public'
         and table_name = 'live_ride_locations'
         and column_name = 'updated_at'
     ) then
    execute 'delete from public.live_ride_locations where updated_at < $1' using cutoff;
    get diagnostics deleted_count = row_count;
  end if;

  return deleted_count;
end;
$$;

create or replace function public.cleanup_old_app_diagnostics(retention_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer := 0;
  total_count integer := 0;
  cutoff timestamptz;
begin
  if retention_days is null or retention_days < 7 then
    retention_days := 7;
  end if;

  cutoff := now() - make_interval(days => retention_days);

  if to_regclass('public.app_diagnostics') is not null
     and exists (
       select 1 from information_schema.columns
       where table_schema = 'public'
         and table_name = 'app_diagnostics'
         and column_name = 'created_at'
     ) then
    execute 'delete from public.app_diagnostics where created_at < $1' using cutoff;
    get diagnostics deleted_count = row_count;
    total_count := total_count + deleted_count;
  end if;

  if to_regclass('public.app_errors') is not null
     and exists (
       select 1 from information_schema.columns
       where table_schema = 'public'
         and table_name = 'app_errors'
         and column_name = 'created_at'
     ) then
    execute 'delete from public.app_errors where created_at < $1' using cutoff;
    get diagnostics deleted_count = row_count;
    total_count := total_count + deleted_count;
  end if;

  return total_count;
end;
$$;

grant execute on function public.cleanup_stale_live_ride_locations(integer) to service_role;
grant execute on function public.cleanup_old_app_diagnostics(integer) to service_role;
