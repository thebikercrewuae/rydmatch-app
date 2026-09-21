import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { create, getNumericDate } from 'https://deno.land/x/djwt@v3.0.2/mod.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*',
};

interface NotificationRow {
  user_id: string;
  notification_type: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

async function getAccessToken(): Promise<string> {
  const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL');
  const privateKey = Deno.env.get('FCM_PRIVATE_KEY');
  const projectId = Deno.env.get('FCM_PROJECT_ID');

  if (!clientEmail || !privateKey || !projectId) {
    throw new Error('FCM credentials not set');
  }

  // Format the private key (replace literal \n with actual newlines)
  const formattedKey = privateKey.replace(/\\n/g, '\n');

  const now = getNumericDate(new Date());
  const payload = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const jwt = await create({ alg: 'RS256', typ: 'JWT' }, payload, formattedKey);

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + jwt,
  });

  const tokenData = await tokenResponse.json();
  if (!tokenData.access_token) {
    throw new Error('Failed to get access token: ' + JSON.stringify(tokenData));
  }

  return tokenData.access_token;
}

async function sendFcmMessage(token: string, title: string, body: string, data?: Record<string, string>): Promise<boolean> {
  const projectId = Deno.env.get('FCM_PROJECT_ID');
  if (!projectId) {
    console.error('FCM_PROJECT_ID not set');
    return false;
  }

  const accessToken = await getAccessToken();
  const fcmUrl = 'https://fcm.googleapis.com/v1/projects/' + projectId + '/messages:send';

  const message = {
    message: {
      token: token,
      notification: { title, body },
      data: data || {},
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    },
  };

  const response = await fetch(fcmUrl, {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + accessToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(message),
  });

  if (!response.ok) {
    console.error('FCM send failed:', response.status, await response.text());
    return false;
  }

  return true;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const payload: NotificationRow = await req.json();
    const { user_id, title, body, data } = payload;

    if (!user_id || !title || !body) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: profile, error } = await supabase
      .from('user_profiles')
      .select('fcm_token')
      .eq('id', user_id)
      .maybeSingle();

    if (error || !profile?.fcm_token) {
      return new Response(JSON.stringify({ sent: false, reason: 'No FCM token' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const sent = await sendFcmMessage(profile.fcm_token, title, body, data);

    return new Response(JSON.stringify({ sent }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
