import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { AccessToken } from 'npm:livekit-server-sdk';

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
    const livekitUrl = Deno.env.get('LIVEKIT_URL');
    const livekitApiKey = Deno.env.get('LIVEKIT_API_KEY');
    const livekitApiSecret = Deno.env.get('LIVEKIT_API_SECRET');
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (
      !livekitUrl ||
      !livekitApiKey ||
      !livekitApiSecret ||
      !supabaseUrl ||
      !anonKey ||
      !serviceRoleKey
    ) {
      return jsonResponse(
        { error: 'LiveKit voice service is not configured' },
        500,
      );
    }

    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader) {
      return jsonResponse({ error: 'Missing authorization header' }, 401);
    }

    let requestBody: { sessionId?: unknown };
    try {
      requestBody = await req.json();
    } catch (_) {
      return jsonResponse({ error: 'Invalid request body' }, 400);
    }

    const sessionId = typeof requestBody.sessionId === 'string'
      ? requestBody.sessionId.trim()
      : '';
    if (!sessionId) {
      return jsonResponse({ error: 'Missing sessionId' }, 400);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse({ error: 'Not signed in' }, 401);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: profile, error: profileError } = await adminClient
      .from('user_profiles')
      .select('full_name, email, is_premium, is_admin')
      .eq('id', user.id)
      .maybeSingle();

    if (profileError) {
      console.error('livekit-token profile lookup error:', profileError);
      return jsonResponse({ error: 'Could not verify premium status' }, 500);
    }

    const isPremium = profile?.is_premium === true || profile?.is_admin === true;
    if (!isPremium) {
      return jsonResponse({ error: 'Premium subscription required' }, 403);
    }

    const { data: session } = await adminClient
      .from('live_ride_sessions')
      .select('id, status')
      .eq('id', sessionId)
      .eq('status', 'active')
      .maybeSingle();

    if (!session) {
      return jsonResponse({ error: 'Live ride session not found' }, 404);
    }

    const { data: participant } = await adminClient
      .from('live_ride_participants')
      .select('id')
      .eq('session_id', sessionId)
      .eq('user_id', user.id)
      .neq('status', 'left')
      .maybeSingle();

    if (!participant) {
      return jsonResponse(
        { error: 'You are not part of this live ride' },
        403,
      );
    }

    const displayName = profile?.full_name ||
      profile?.email?.split('@')[0] ||
      'Rider';
    const roomName = `live-ride-${sessionId}`;

    const token = new AccessToken(livekitApiKey, livekitApiSecret, {
      identity: user.id,
      name: displayName,
      ttl: '8h',
    });

    token.addGrant({
      room: roomName,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    return jsonResponse({
      url: livekitUrl,
      token: await token.toJwt(),
      roomName,
    });
  } catch (error) {
    console.error('livekit-token error:', error);
    return jsonResponse({ error: 'Internal server error' }, 500);
  }
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}
