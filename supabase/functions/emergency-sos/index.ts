import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

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
      return jsonResponse({ error: 'Emergency network is not configured' }, 500);
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

    const admin = createClient(supabaseUrl, serviceRoleKey);

    const body = await req.json();
    const { latitude, longitude, accuracy, isTest, liveRideSessionId } = body;

    if (latitude == null || longitude == null) {
      return jsonResponse(
        { error: 'Missing GPS coordinates: latitude and longitude are required' },
        400,
      );
    }

    const lat = parseFloat(String(latitude));
    const lng = parseFloat(String(longitude));

    if (Number.isNaN(lat) || Number.isNaN(lng)) {
      return jsonResponse(
        {
          error:
            'Invalid GPS coordinates: latitude and longitude must be valid numbers',
        },
        400,
      );
    }

    const { data: profile } = await admin
      .from('user_profiles')
      .select('full_name, phone_number')
      .eq('id', user.id)
      .maybeSingle();
    const riderName =
      profile?.full_name?.trim() || body.riderName?.trim() || 'RydMatch Rider';

    const recipients = new Map<string, 'live_ride' | 'match' | 'self_test'>();
    if (isTest === true) {
      recipients.set(user.id, 'self_test');
    } else {
      if (typeof liveRideSessionId === 'string' && liveRideSessionId.length > 0) {
        const { data: participants } = await admin
          .from('live_ride_participants')
          .select('user_id')
          .eq('session_id', liveRideSessionId)
          .eq('status', 'active');
        for (const participant of participants ?? []) {
          if (participant.user_id !== user.id) {
            recipients.set(participant.user_id, 'live_ride');
          }
        }
      }

      const { data: matches } = await admin
        .from('rider_matches')
        .select('user1_id, user2_id')
        .or(`user1_id.eq.${user.id},user2_id.eq.${user.id}`)
        .limit(50);
      for (const match of matches ?? []) {
        const recipientId =
          match.user1_id === user.id ? match.user2_id : match.user1_id;
        if (recipientId && recipientId !== user.id && !recipients.has(recipientId)) {
          recipients.set(recipientId, 'match');
        }
      }
    }

    const { data: alert, error: alertError } = await admin
      .from('emergency_alerts')
      .insert({
        rider_id: user.id,
        rider_name: riderName,
        latitude: lat,
        longitude: lng,
        accuracy: Number.isFinite(Number(accuracy)) ? Number(accuracy) : null,
        phone_number: profile?.phone_number ?? null,
        live_ride_session_id:
          typeof liveRideSessionId === 'string' && liveRideSessionId.length > 0
            ? liveRideSessionId
            : null,
        is_test: isTest === true,
      })
      .select('id')
      .single();
    if (alertError || !alert) {
      return jsonResponse(
        { error: 'Could not create emergency alert', details: alertError?.message },
        500,
      );
    }

    const recipientRows = [...recipients.entries()].map(
      ([recipientId, source]) => ({
        alert_id: alert.id,
        recipient_id: recipientId,
        source,
      }),
    );
    if (recipientRows.length > 0) {
      const { error: recipientError } = await admin
        .from('emergency_alert_recipients')
        .insert(recipientRows);
      if (recipientError) {
        return jsonResponse(
          { error: 'Could not notify emergency contacts', details: recipientError.message },
          500,
        );
      }

      const notifications = recipientRows.map((recipient) => ({
        user_id: recipient.recipient_id,
        notification_type: 'emergency_sos',
        title: isTest === true ? 'Test emergency alert' : 'Emergency SOS',
        message:
          isTest === true
            ? `${riderName} sent a test RydMatch emergency alert.`
            : `${riderName} needs immediate assistance. Tap to respond.`,
        action_route: '/emergency-alert-screen',
        action_arguments: { alert_id: alert.id },
        reference_id: user.id,
      }));
      const { error: notificationError } = await admin
        .from('notifications')
        .insert(notifications);
      if (notificationError) {
        return jsonResponse(
          { error: 'Could not deliver emergency notifications', details: notificationError.message },
          500,
        );
      }
    }

    return jsonResponse({
      success: true,
      alertId: alert.id,
      recipientCount: recipientRows.length,
      provider: 'rydmatch_network',
    });
  } catch (error) {
    return jsonResponse(
      { error: 'Internal server error', details: String(error) },
      500,
    );
  }
});
