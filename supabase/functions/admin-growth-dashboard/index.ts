import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const authHeader = req.headers.get('Authorization') ?? '';

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return jsonResponse({ error: 'Dashboard service is not configured' }, 500);
    }
    if (!authHeader) {
      return jsonResponse({ error: 'Missing authorization header' }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse({ error: 'Not signed in' }, 401);
    }

    const { data: isAdmin, error: adminError } = await userClient.rpc(
      'is_admin_user',
    );
    if (adminError || isAdmin !== true) {
      return jsonResponse({ error: 'Admin access required' }, 403);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const now = new Date();
    const since7 = new Date(now.getTime() - 7 * 86400000).toISOString();
    const since30 = new Date(now.getTime() - 30 * 86400000).toISOString();

    const [
      profilesResult,
      eventsResult,
      matchesResult,
      messagesResult,
      groupsResult,
      stravaCountResult,
      liveSessionsResult,
      liveParticipantsResult,
      liveLocationsResult,
      liveErrorsResult,
      notificationsResult,
      notificationErrorsResult,
    ] = await Promise.all([
      admin
        .from('user_profiles')
        .select('id, is_profile_complete, is_premium, is_admin, created_at')
        .limit(10000),
      admin
        .from('analytics_events')
        .select('user_id, event_type, event_data, created_at')
        .gte('created_at', since30)
        .order('created_at', { ascending: false })
        .limit(10000),
      admin
        .from('rider_matches')
        .select('id, user1_id, user2_id, created_at')
        .gte('created_at', since30)
        .limit(10000),
      admin
        .from('chat_messages')
        .select('id, sender_id, recipient_id, created_at')
        .gte('created_at', since30)
        .limit(10000),
      admin
        .from('ride_groups')
        .select('id, creator_id, name, route, route_polyline, created_at')
        .gte('created_at', since30)
        .limit(10000),
      admin.from('strava_connections').select('*', { count: 'exact', head: true }),
      admin
        .from('live_ride_sessions')
        .select('id, ride_group_id, started_by, status, started_at, ended_at, auto_stop_at')
        .gte('started_at', since30)
        .order('started_at', { ascending: false })
        .limit(250),
      admin
        .from('live_ride_participants')
        .select('session_id, user_id, status, is_sharing_location, joined_at, left_at')
        .gte('joined_at', since30)
        .limit(10000),
      admin
        .from('live_ride_locations')
        .select('session_id, user_id, created_at')
        .gte('created_at', since30)
        .order('created_at', { ascending: false })
        .limit(10000),
      admin
        .from('app_errors')
        .select('feature, action, severity, message, context, created_at, user_id')
        .in('feature', ['live_ride', 'live_ride_voice'])
        .gte('created_at', since7)
        .order('created_at', { ascending: false })
        .limit(250),
      admin
        .from('notifications')
        .select('id, user_id, notification_type, title, message, is_read, action_route, action_arguments, created_at')
        .gte('created_at', since30)
        .order('created_at', { ascending: false })
        .limit(10000),
      admin
        .from('app_errors')
        .select('feature, action, severity, message, context, created_at, user_id')
        .or('feature.eq.notifications,and(feature.eq.ride_groups,action.eq.create_invite_notifications),and(feature.eq.live_ride,action.eq.notify_group_members)')
        .gte('created_at', since7)
        .order('created_at', { ascending: false })
        .limit(250),
    ]);

    for (const [name, result] of [
      ['profiles', profilesResult],
      ['events', eventsResult],
      ['matches', matchesResult],
      ['messages', messagesResult],
      ['groups', groupsResult],
      ['live sessions', liveSessionsResult],
      ['live participants', liveParticipantsResult],
      ['live locations', liveLocationsResult],
      ['live diagnostics', liveErrorsResult],
      ['notifications', notificationsResult],
      ['notification diagnostics', notificationErrorsResult],
    ] as const) {
      if (result.error) {
        console.error(`admin-growth-dashboard ${name} error:`, result.error);
        return jsonResponse({ error: `Could not load ${name} metrics` }, 500);
      }
    }

    const profiles = profilesResult.data ?? [];
    const events = eventsResult.data ?? [];
    const matches = matchesResult.data ?? [];
    const messages = messagesResult.data ?? [];
    const groups = groupsResult.data ?? [];
    const liveSessions = liveSessionsResult.data ?? [];
    const liveParticipants = liveParticipantsResult.data ?? [];
    const liveLocations = liveLocationsResult.data ?? [];
    const liveErrors = liveErrorsResult.data ?? [];
    const notifications = notificationsResult.data ?? [];
    const notificationErrors = notificationErrorsResult.data ?? [];

    const nonAdminProfiles = profiles.filter((profile) => profile.is_admin !== true);

    const metrics7 = periodMetrics({
      since: since7,
      profiles: nonAdminProfiles,
      events,
      matches,
      messages,
      groups,
      liveSessions,
    });
    const metrics30 = periodMetrics({
      since: since30,
      profiles: nonAdminProfiles,
      events,
      matches,
      messages,
      groups,
      liveSessions,
    });

    const totalUsers = nonAdminProfiles.length;
    const completeProfiles = nonAdminProfiles.filter(
      (profile) => profile.is_profile_complete === true,
    ).length;
    const premiumUsers = nonAdminProfiles.filter(
      (profile) => profile.is_premium === true,
    ).length;

    return jsonResponse({
      generatedAt: now.toISOString(),
      totals: {
        users: totalUsers,
        completeProfiles,
        profileCompletionRate: percent(completeProfiles, totalUsers),
        premiumUsers,
        premiumAccountRate: percent(premiumUsers, totalUsers),
        stravaConnections: stravaCountResult.error
          ? null
          : stravaCountResult.count ?? 0,
        newUsers7d: countSince(nonAdminProfiles, since7),
        newUsers30d: countSince(nonAdminProfiles, since30),
      },
      periods: {
        '7d': metrics7,
        '30d': metrics30,
      },
      liveRide: liveRideDiagnostics({
        now,
        sessions: liveSessions,
        participants: liveParticipants,
        locations: liveLocations,
        errors: liveErrors,
        groups,
      }),
      notifications: notificationDiagnostics({
        now,
        notifications,
        errors: notificationErrors,
      }),
      notes: [
        'Active users are riders who generated a tracked analytics event.',
        'Premium conversions include beta unlocks and store activations.',
        'Actual store revenue and subscription renewals remain in RevenueCat.',
      ],
    });
  } catch (error) {
    console.error('admin-growth-dashboard error:', error);
    return jsonResponse({ error: 'Internal server error' }, 500);
  }
});

function periodMetrics({
  since,
  profiles,
  events,
  matches,
  messages,
  groups,
  liveSessions,
}: {
  since: string;
  profiles: any[];
  events: any[];
  matches: any[];
  messages: any[];
  groups: any[];
  liveSessions: any[];
}) {
  const periodEvents = events.filter((row) => row.created_at >= since);
  const periodMatches = matches.filter((row) => row.created_at >= since);
  const periodMessages = messages.filter((row) => row.created_at >= since);
  const periodGroups = groups.filter((row) => row.created_at >= since);
  const periodLiveSessions = liveSessions.filter((row) => row.started_at >= since);
  const eventCounts: Record<string, number> = {};
  const eventUsers: Record<string, Set<string>> = {};
  const activeUsers = new Set<string>();

  for (const event of periodEvents) {
    const type = String(event.event_type ?? 'unknown');
    eventCounts[type] = (eventCounts[type] ?? 0) + 1;
    if (event.user_id) {
      activeUsers.add(event.user_id);
      (eventUsers[type] ??= new Set()).add(event.user_id);
    }
  }

  const premiumViews = eventCounts.premium_screen_view ?? 0;
  const subscribeStarts = eventCounts.premium_subscribe_started ?? 0;
  const purchaseResultCounts = eventDataCounts(
    periodEvents,
    'premium_purchase_result',
    'status',
  );
  const conversions = eventCounts.premium_converted ?? 0;
  const rightSwipes = eventCounts.swipe_right ?? 0;
  const matchEvents = eventCounts.match_created ?? periodMatches.length;
  const onboarding = onboardingFunnel(periodEvents, eventCounts);
  const activation = activationMetrics({
    since,
    profiles,
    events: periodEvents,
    matches: periodMatches,
    messages: periodMessages,
    groups: periodGroups,
    liveSessions: periodLiveSessions,
    activeUsers,
    eventUsers,
  });

  return {
    activeUsers: activeUsers.size,
    profileCreated: eventCounts.profile_created ?? 0,
    profileUpdated: eventCounts.profile_updated ?? 0,
    rightSwipes,
    leftSwipes: eventCounts.swipe_left ?? 0,
    superLikes: eventCounts.super_like ?? 0,
    matchEvents,
    matchRows: periodMatches.length,
    messageEvents: eventCounts.message_sent ?? 0,
    messageRows: periodMessages.length,
    rideGroupCreatedEvents: eventCounts.ride_group_created ?? 0,
    rideGroupJoinedEvents: eventCounts.ride_group_joined ?? 0,
    rideGroupsCreated: periodGroups.length,
    liveRideStartedEvents: eventCounts.live_ride_started ?? 0,
    liveRideJoinedEvents: eventCounts.live_ride_joined ?? 0,
    premiumViews,
    premiumSubscribeStarts: subscribeStarts,
    premiumPurchaseResults: eventCounts.premium_purchase_result ?? 0,
    premiumPurchaseSuccesses: purchaseResultCounts.success ?? 0,
    premiumPurchaseErrors: purchaseResultCounts.error ?? 0,
    premiumPurchaseStoreUnavailable:
      purchaseResultCounts.store_unavailable ?? 0,
    premiumPurchaseMissingEntitlement:
      purchaseResultCounts.missing_entitlement ?? 0,
    premiumPurchaseNoActiveSubscription:
      purchaseResultCounts.no_active_subscription ?? 0,
    premiumConversions: conversions,
    premiumViewToStartRate: percent(subscribeStarts, premiumViews),
    premiumStartToConversionRate: percent(conversions, subscribeStarts),
    rightSwipeToMatchRate: percent(matchEvents, rightSwipes),
    uniquePremiumViewers: eventUsers.premium_screen_view?.size ?? 0,
    uniqueSubscribeStarters: eventUsers.premium_subscribe_started?.size ?? 0,
    uniqueConverters: eventUsers.premium_converted?.size ?? 0,
    onboarding,
    activation,
  };
}

function activationMetrics({
  since,
  profiles,
  events,
  matches,
  messages,
  groups,
  liveSessions,
  activeUsers,
  eventUsers,
}: {
  since: string;
  profiles: any[];
  events: any[];
  matches: any[];
  messages: any[];
  groups: any[];
  liveSessions: any[];
  activeUsers: Set<string>;
  eventUsers: Record<string, Set<string>>;
}) {
  const periodProfiles = profiles.filter((profile) => profile.created_at >= since);
  const completedProfiles = new Set(
    profiles
      .filter((profile) => profile.is_profile_complete === true)
      .map((profile) => profile.id)
      .filter(Boolean),
  );
  const swipeUsers = unionSets([
    eventUsers.swipe_right,
    eventUsers.swipe_left,
    eventUsers.super_like,
  ]);
  const matchUsers = uniqueMatchUsers(matches);
  const messageUsers = uniqueByKey(messages, 'sender_id');
  const groupCreators = unionSets([
    uniqueByKey(groups, 'creator_id'),
    eventUsers.ride_group_created,
  ]);
  const groupJoiners = eventUsers.ride_group_joined ?? new Set<string>();
  const liveRideStarters = unionSets([
    uniqueByKey(liveSessions, 'started_by'),
    eventUsers.live_ride_started,
  ]);
  const liveRideJoiners = eventUsers.live_ride_joined ?? new Set<string>();
  const premiumViewers = eventUsers.premium_screen_view ?? new Set<string>();
  const valueUsers = unionSets([
    swipeUsers,
    matchUsers,
    messageUsers,
    groupCreators,
    groupJoiners,
    liveRideStarters,
    liveRideJoiners,
    premiumViewers,
  ]);
  const activatedUsers = intersectionSize(completedProfiles, valueUsers);
  const returningUsers = multiDayActiveUsers(events);
  const newUserIds = new Set(
    periodProfiles.map((profile) => profile.id).filter(Boolean),
  );
  const newActiveUsers = intersectionSize(newUserIds, activeUsers);
  const newActivatedUsers = intersectionSize(newUserIds, valueUsers);
  const moments = [
    { label: 'First swipe', users: swipeUsers.size },
    { label: 'First match', users: matchUsers.size },
    { label: 'First message', users: messageUsers.size },
    { label: 'Ride group created', users: groupCreators.size },
    { label: 'Live ride started', users: liveRideStarters.size },
    { label: 'Premium viewed', users: premiumViewers.size },
  ];
  const weakestMoment = [...moments].sort((a, b) => a.users - b.users)[0] ?? null;
  const strongestMoment = [...moments].sort((a, b) => b.users - a.users)[0] ?? null;

  return {
    activeUsers: activeUsers.size,
    returningUsers: returningUsers.size,
    multiDayActiveRate: percent(returningUsers.size, activeUsers.size),
    newUsers: periodProfiles.length,
    newActiveUsers,
    newUserActivationRate: percent(newActiveUsers, periodProfiles.length),
    newValueUsers: newActivatedUsers,
    newUserValueRate: percent(newActivatedUsers, periodProfiles.length),
    activatedUsers,
    activationRate: percent(activatedUsers, completedProfiles.size),
    firstSwipeUsers: swipeUsers.size,
    firstMatchUsers: matchUsers.size,
    firstMessageUsers: messageUsers.size,
    rideGroupCreators: groupCreators.size,
    rideGroupJoiners: groupJoiners.size,
    liveRideStarters: liveRideStarters.size,
    liveRideJoiners: liveRideJoiners.size,
    premiumViewers: premiumViewers.size,
    weakestMoment,
    strongestMoment,
  };
}

function onboardingFunnel(
  events: any[],
  eventCounts: Record<string, number>,
) {
  const stepViews = new Map<number, { name: string; users: Set<string>; events: number }>();
  const stepCompletions = new Map<number, { name: string; users: Set<string>; events: number }>();

  for (const event of events) {
    if (
      event.event_type !== 'profile_setup_step_viewed' &&
      event.event_type !== 'profile_setup_step_completed'
    ) {
      continue;
    }

    const data = event.event_data ?? {};
    const stepIndex =
      typeof data.step_index === 'number'
        ? data.step_index
        : Number.parseInt(String(data.step_index ?? ''), 10);
    if (Number.isNaN(stepIndex)) continue;

    const target =
      event.event_type === 'profile_setup_step_viewed'
        ? stepViews
        : stepCompletions;
    const entry = target.get(stepIndex) ?? {
      name: String(data.step_name ?? `Step ${stepIndex + 1}`),
      users: new Set<string>(),
      events: 0,
    };
    entry.events += 1;
    if (event.user_id) entry.users.add(event.user_id);
    target.set(stepIndex, entry);
  }

  const allStepIndexes = Array.from(
    new Set([...stepViews.keys(), ...stepCompletions.keys()]),
  ).sort((a, b) => a - b);
  const steps = allStepIndexes.map((index) => {
    const viewed = stepViews.get(index);
    const completed = stepCompletions.get(index);
    const viewedUsers = viewed?.users.size ?? 0;
    const completedUsers = completed?.users.size ?? 0;
    return {
      stepIndex: index,
      stepNumber: index + 1,
      stepName: viewed?.name ?? completed?.name ?? `Step ${index + 1}`,
      viewedUsers,
      completedUsers,
      completionRate: percent(completedUsers, viewedUsers),
      dropOffUsers: Math.max(viewedUsers - completedUsers, 0),
    };
  });
  const weakestStep = [...steps].sort(
    (a, b) => b.dropOffUsers - a.dropOffUsers,
  )[0] ?? null;

  const registrationCompleted = eventCounts.registration_completed ?? 0;
  const setupStarted = eventCounts.profile_setup_started ?? 0;
  const profileCreated = eventCounts.profile_created ?? 0;
  const skipped = eventCounts.profile_setup_skipped ?? 0;

  return {
    registrationCompleted,
    setupStarted,
    profileCreated,
    skipped,
    registrationToProfileRate: percent(profileCreated, registrationCompleted),
    setupStartToProfileRate: percent(profileCreated, setupStarted),
    skipRate: percent(skipped, setupStarted),
    weakestStep,
    steps,
  };
}

function notificationDiagnostics({
  now,
  notifications,
  errors,
}: {
  now: Date;
  notifications: any[];
  errors: any[];
}) {
  const unread = notifications.filter((row) => row.is_read === false);
  const olderThan7 = new Date(now.getTime() - 7 * 86400000).toISOString();
  const staleUnread = unread.filter((row) => row.created_at < olderThan7);
  const byType = countBy(notifications, 'notification_type');
  const unreadByType = countBy(unread, 'notification_type');
  const actionCounts = countBy(errors, 'action');
  const missingRoute = notifications.filter((row) => {
    const type = String(row.notification_type ?? '');
    if (type === 'urgent_alert') return false;
    return !row.action_route;
  });
  const invalidLiveRideTargets = notifications.filter((row) => {
    if (row.notification_type !== 'ride_started') return false;
    const args = row.action_arguments ?? {};
    return !args.session_id || !args.ride_group_id;
  });
  const highUnreadUsers = topCounts(unread, 'user_id', 5).filter(
    (row) => row.count >= 10,
  );

  return {
    notifications30d: notifications.length,
    unread: unread.length,
    staleUnread: staleUnread.length,
    missingRoute: missingRoute.length,
    invalidLiveRideTargets: invalidLiveRideTargets.length,
    highUnreadUsers,
    byType,
    unreadByType,
    errorEvents7d: errors.length,
    actionCounts,
    recentErrors: errors.slice(0, 6),
    recentNotifications: notifications.slice(0, 8).map((row) => ({
      id: row.id,
      userId: row.user_id,
      type: row.notification_type,
      title: row.title,
      isRead: row.is_read,
      actionRoute: row.action_route,
      createdAt: row.created_at,
      hasActionArguments:
        row.action_arguments && Object.keys(row.action_arguments).length > 0,
    })),
  };
}

function liveRideDiagnostics({
  now,
  sessions,
  participants,
  locations,
  errors,
  groups,
}: {
  now: Date;
  sessions: any[];
  participants: any[];
  locations: any[];
  errors: any[];
  groups: any[];
}) {
  const participantsBySession = new Map<string, any[]>();
  for (const participant of participants) {
    if (!participant.session_id) continue;
    const list = participantsBySession.get(participant.session_id) ?? [];
    list.push(participant);
    participantsBySession.set(participant.session_id, list);
  }

  const latestLocationBySession = new Map<string, string>();
  const locationUsersBySession = new Map<string, Set<string>>();
  for (const location of locations) {
    if (!location.session_id) continue;
    if (!latestLocationBySession.has(location.session_id)) {
      latestLocationBySession.set(location.session_id, location.created_at);
    }
    if (location.user_id) {
      const users = locationUsersBySession.get(location.session_id) ?? new Set();
      users.add(location.user_id);
      locationUsersBySession.set(location.session_id, users);
    }
  }

  const groupsById = new Map<string, any>();
  for (const group of groups) {
    if (group.id) groupsById.set(group.id, group);
  }

  const activeSessions = sessions.filter((session) => session.status === 'active');
  const completedSessions = sessions.filter(
    (session) => session.status === 'completed',
  );
  const staleActiveSessions = activeSessions.filter((session) => {
    if (!session.auto_stop_at) return false;
    return new Date(session.auto_stop_at).getTime() < now.getTime();
  });

  const actionCounts = countBy(errors, 'action');
  const routeIssueActions = new Set([
    'planned_route_unavailable',
    'load_planned_route',
    'map_session_resume_failed',
  ]);
  const locationIssueActions = new Set([
    'send_location',
    'load_latest_locations',
    'location_service_disabled',
    'location_permission_denied',
    'location_permission_denied_forever',
  ]);

  const routeIssues = errors.filter(
    (error) => error.feature === 'live_ride' && routeIssueActions.has(error.action),
  );
  const locationIssues = errors.filter(
    (error) =>
      error.feature === 'live_ride' && locationIssueActions.has(error.action),
  );
  const failedJoinEvents = errors.filter(
    (error) =>
      error.feature === 'live_ride' &&
      ['join_ride', 'map_session_resume_failed'].includes(error.action),
  );
  const voiceIssues = errors.filter((error) => error.feature === 'live_ride_voice');

  const activeParticipants = participants.filter(
    (participant) => participant.status === 'active',
  );
  const sharingParticipants = activeParticipants.filter(
    (participant) => participant.is_sharing_location === true,
  );

  const recentSessions = sessions.slice(0, 8).map((session) => {
    const group = session.ride_group_id ? groupsById.get(session.ride_group_id) : null;
    const sessionParticipants = participantsBySession.get(session.id) ?? [];
    const activeSessionParticipants = sessionParticipants.filter(
      (participant) => participant.status === 'active',
    );
    const locationUsers = locationUsersBySession.get(session.id);
    const routePolyline = Array.isArray(group?.route_polyline)
      ? group.route_polyline
      : [];

    return {
      id: session.id,
      status: session.status,
      startedAt: session.started_at,
      endedAt: session.ended_at,
      autoStopAt: session.auto_stop_at,
      groupId: session.ride_group_id,
      groupName: group?.name ?? null,
      routeName: group?.route ?? null,
      hasPlannedRoute: routePolyline.length >= 2,
      activeParticipants: activeSessionParticipants.length,
      totalParticipants: sessionParticipants.length,
      locationSharers: activeSessionParticipants.filter(
        (participant) => participant.is_sharing_location === true,
      ).length,
      ridersWithLocation: locationUsers?.size ?? 0,
      lastLocationAt: latestLocationBySession.get(session.id) ?? null,
      isPastAutoStop:
        session.status === 'active' &&
        session.auto_stop_at &&
        new Date(session.auto_stop_at).getTime() < now.getTime(),
    };
  });

  return {
    sessions30d: sessions.length,
    activeSessions: activeSessions.length,
    completedSessions: completedSessions.length,
    staleActiveSessions: staleActiveSessions.length,
    activeParticipants: activeParticipants.length,
    locationSharingParticipants: sharingParticipants.length,
    sessionsWithLocations: latestLocationBySession.size,
    failedJoinEvents: failedJoinEvents.length,
    routeIssues: routeIssues.length,
    locationIssues: locationIssues.length,
    voiceIssues: voiceIssues.length,
    errorEvents7d: errors.length,
    actionCounts,
    recentErrors: errors.slice(0, 6),
    recentSessions,
  };
}

function countBy(rows: any[], key: string): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const row of rows) {
    const value = String(row[key] ?? 'unknown');
    counts[value] = (counts[value] ?? 0) + 1;
  }
  return counts;
}

function eventDataCounts(
  events: any[],
  eventType: string,
  dataKey: string,
): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const event of events) {
    if (event.event_type !== eventType) continue;
    const data = event.event_data ?? {};
    const value = String(data[dataKey] ?? 'unknown');
    counts[value] = (counts[value] ?? 0) + 1;
  }
  return counts;
}

function topCounts(rows: any[], key: string, limit: number) {
  return Object.entries(countBy(rows, key))
    .filter(([value]) => value !== 'unknown')
    .map(([value, count]) => ({ value, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, limit);
}

function uniqueByKey(rows: any[], key: string): Set<string> {
  return new Set(
    rows.map((row) => row[key]).filter((value) => typeof value === 'string'),
  );
}

function uniqueMatchUsers(matches: any[]): Set<string> {
  const users = new Set<string>();
  for (const match of matches) {
    if (match.user1_id) users.add(match.user1_id);
    if (match.user2_id) users.add(match.user2_id);
  }
  return users;
}

function unionSets(sets: Array<Set<string> | undefined>): Set<string> {
  const merged = new Set<string>();
  for (const set of sets) {
    if (!set) continue;
    for (const value of set) merged.add(value);
  }
  return merged;
}

function intersectionSize(left: Set<string>, right: Set<string>): number {
  let count = 0;
  for (const value of left) {
    if (right.has(value)) count += 1;
  }
  return count;
}

function multiDayActiveUsers(events: any[]): Set<string> {
  const daysByUser = new Map<string, Set<string>>();
  for (const event of events) {
    if (!event.user_id || !event.created_at) continue;
    const day = String(event.created_at).slice(0, 10);
    const days = daysByUser.get(event.user_id) ?? new Set<string>();
    days.add(day);
    daysByUser.set(event.user_id, days);
  }

  const users = new Set<string>();
  for (const [userId, days] of daysByUser.entries()) {
    if (days.size >= 2) users.add(userId);
  }
  return users;
}

function countSince(rows: any[], since: string): number {
  return rows.filter((row) => row.created_at >= since).length;
}

function percent(value: number, total: number): number | null {
  if (total <= 0) return null;
  return Math.round((value / total) * 1000) / 10;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
