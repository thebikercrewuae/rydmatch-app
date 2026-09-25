import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { AccessToken } from 'npm:livekit-server-sdk';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

    if (!livekitUrl || !livekitApiKey || !livekitApiSecret || !supabaseUrl || !anonKey || !serviceRoleKey) {
      return jsonResponse({ error: 'Voice service is not configured' }, 500);
    }

    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader) {
      return jsonResponse({ error: 'Missing authorization header' }, 401);
    }

    let requestBody: { channelId?: unknown };
    try {
      requestBody = await req.json();
    } catch (_) {
      return jsonResponse({ error: 'Invalid request body' }, 400);
    }

    const channelId = typeof requestBody.channelId === 'string' ? requestBody.channelId.trim() : '';
    if (!channelId) {
      return jsonResponse({ error: 'Missing channelId' }, 400);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return jsonResponse({ error: 'Not signed in' }, 401);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    // Get the channel and its event
    const { data: channel, error: channelError } = await adminClient
      .from('event_channels')
      .select('id, event_id, is_restricted')
      .eq('id', channelId)
      .maybeSingle();

    if (channelError || !channel) {
      return jsonResponse({ error: 'Channel not found' }, 404);
    }

    // Check if user is a member of this channel
    const { data: membership } = await adminClient
      .from('event_channel_members')
      .select('user_id')
      .eq('channel_id', channelId)
      .eq('user_id', user.id)
      .maybeSingle();

    // If not a direct member, check if they're an event admin/owner
    let hasAccess = !!membership;
    if (!hasAccess) {
      const { data: isAdmin } = await adminClient.rpc('is_event_admin_or_owner', {
        event_uuid: channel.event_id,
        user_uuid: user.id,
      });
      hasAccess = !!isAdmin;
    }

    if (!hasAccess) {
      return jsonResponse({ error: 'You do not have access to this channel' }, 403);
    }

    // Get user profile for display name
    const { data: profile } = await adminClient
      .from('user_profiles')
      .select('full_name, email')
      .eq('id', user.id)
      .maybeSingle();

    const displayName = profile?.full_name || profile?.email?.split('@')[0] || 'Staff';
    const roomName = 'event-voice-' + channelId;

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
    console.error('event-voice-token error:', error);
    return jsonResponse({ error: 'Internal server error' }, 500);
  }
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
