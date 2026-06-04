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
        .select('id, creator_id, created_at')
        .gte('created_at', since30)
        .limit(10000),
      admin.from('strava_connections').select('*', { count: 'exact', head: true }),
    ]);

    for (const [name, result] of [
      ['profiles', profilesResult],
      ['events', eventsResult],
      ['matches', matchesResult],
      ['messages', messagesResult],
      ['groups', groupsResult],
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

    const metrics7 = periodMetrics({
      since: since7,
      events,
      matches,
      messages,
      groups,
    });
    const metrics30 = periodMetrics({
      since: since30,
      events,
      matches,
      messages,
      groups,
    });

    const nonAdminProfiles = profiles.filter((profile) => profile.is_admin !== true);
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
  events,
  matches,
  messages,
  groups,
}: {
  since: string;
  events: any[];
  matches: any[];
  messages: any[];
  groups: any[];
}) {
  const periodEvents = events.filter((row) => row.created_at >= since);
  const periodMatches = matches.filter((row) => row.created_at >= since);
  const periodMessages = messages.filter((row) => row.created_at >= since);
  const periodGroups = groups.filter((row) => row.created_at >= since);
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
  const conversions = eventCounts.premium_converted ?? 0;
  const rightSwipes = eventCounts.swipe_right ?? 0;
  const matchEvents = eventCounts.match_created ?? periodMatches.length;

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
    rideGroupsCreated: periodGroups.length,
    premiumViews,
    premiumSubscribeStarts: subscribeStarts,
    premiumConversions: conversions,
    premiumViewToStartRate: percent(subscribeStarts, premiumViews),
    premiumStartToConversionRate: percent(conversions, subscribeStarts),
    rightSwipeToMatchRate: percent(matchEvents, rightSwipes),
    uniquePremiumViewers: eventUsers.premium_screen_view?.size ?? 0,
    uniqueSubscribeStarters: eventUsers.premium_subscribe_started?.size ?? 0,
    uniqueConverters: eventUsers.premium_converted?.size ?? 0,
  };
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
