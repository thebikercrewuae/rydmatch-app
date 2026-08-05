-- Hot-path performance indexes (corrected from 20260714120000).
-- The original migration had a typo (app_diagnostics instead of app_errors)
-- and was never applied. This version uses a conditional helper that only
-- creates an index if the table and all its columns exist, so it's safe
-- regardless of the live DB state.

CREATE OR REPLACE FUNCTION public._rydmatch_create_index_if_columns_exist(
  p_index_name text,
  p_table_name text,
  p_columns text[],
  p_index_sql text
)
RETURNS void
LANGUAGE plpgsql
AS $$
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

SELECT public._rydmatch_create_index_if_columns_exist(
  'live_ride_locations_session_updated_idx',
  'live_ride_locations',
  array['session_id', 'updated_at'],
  'create index if not exists live_ride_locations_session_updated_idx on public.live_ride_locations (session_id, updated_at desc)'
);

SELECT public._rydmatch_create_index_if_columns_exist(
  'live_ride_locations_group_updated_idx',
  'live_ride_locations',
  array['ride_group_id', 'updated_at'],
  'create index if not exists live_ride_locations_group_updated_idx on public.live_ride_locations (ride_group_id, updated_at desc)'
);

SELECT public._rydmatch_create_index_if_columns_exist(
  'live_ride_locations_user_updated_idx',
  'live_ride_locations',
  array['user_id', 'updated_at'],
  'create index if not exists live_ride_locations_user_updated_idx on public.live_ride_locations (user_id, updated_at desc)'
);

SELECT public._rydmatch_create_index_if_columns_exist(
  'chat_messages_conversation_created_idx',
  'chat_messages',
  array['conversation_id', 'created_at'],
  'create index if not exists chat_messages_conversation_created_idx on public.chat_messages (conversation_id, created_at desc)'
);

SELECT public._rydmatch_create_index_if_columns_exist(
  'chat_messages_recipient_delivery_created_idx',
  'chat_messages',
  array['recipient_id', 'delivery_status', 'created_at'],
  'create index if not exists chat_messages_recipient_delivery_created_idx on public.chat_messages (recipient_id, delivery_status, created_at desc)'
);

SELECT public._rydmatch_create_index_if_columns_exist(
  'notifications_user_created_idx',
  'notifications',
  array['user_id', 'created_at'],
  'create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc)'
);

SELECT public._rydmatch_create_index_if_columns_exist(
  'notifications_user_read_created_idx',
  'notifications',
  array['user_id', 'is_read', 'created_at'],
  'create index if not exists notifications_user_read_created_idx on public.notifications (user_id, is_read, created_at desc)'
);

SELECT public._rydmatch_create_index_if_columns_exist(
  'swipes_swiper_swiped_idx',
  'swipes',
  array['swiper_id', 'swiped_id'],
  'create index if not exists swipes_swiper_swiped_idx on public.swipes (swiper_id, swiped_id)'
);

SELECT public._rydmatch_create_index_if_columns_exist(
  'swipes_swiper_direction_created_idx',
  'swipes',
  array['swiper_id', 'direction', 'created_at'],
  'create index if not exists swipes_swiper_direction_created_idx on public.swipes (swiper_id, direction, created_at desc)'
);

SELECT public._rydmatch_create_index_if_columns_exist(
  'ride_groups_status_created_idx',
  'ride_groups',
  array['status', 'created_at'],
  'create index if not exists ride_groups_status_created_idx on public.ride_groups (status, created_at desc)'
);

SELECT public._rydmatch_create_index_if_columns_exist(
  'app_errors_severity_created_idx',
  'app_errors',
  array['severity', 'created_at'],
  'create index if not exists app_errors_severity_created_idx on public.app_errors (severity, created_at desc)'
);

DROP FUNCTION IF EXISTS public._rydmatch_create_index_if_columns_exist(text, text, text[], text);

NOTIFY pgrst, 'reload schema';