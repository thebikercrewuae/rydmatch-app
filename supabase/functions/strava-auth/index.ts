import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const STRAVA_OAUTH_BASE_URL = 'https://www.strava.com';
const STRAVA_API_BASE_URL = 'https://www.api-v3.strava.com';

type Action = 'exchange' | 'status' | 'refresh' | 'disconnect';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const stravaClientId = Deno.env.get('STRAVA_CLIENT_ID');
    const stravaClientSecret = Deno.env.get('STRAVA_CLIENT_SECRET');

    if (
      !supabaseUrl ||
      !anonKey ||
      !serviceRoleKey ||
      !stravaClientId ||
      !stravaClientSecret
    ) {
      return jsonResponse({ error: 'Strava service is not configured' }, 500);
    }

    const authHeader = req.headers.get('Authorization') ?? '';
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

    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    const body = await readJsonBody(req);
    const action = parseAction(body.action);

    if (action === 'exchange') {
      const code = typeof body.code === 'string' ? body.code.trim() : '';
      if (!code) return jsonResponse({ error: 'Missing Strava code' }, 400);

      const tokenData = await exchangeCode({
        code,
        clientId: stravaClientId,
        clientSecret: stravaClientSecret,
      });

      await upsertConnection(adminClient, user.id, tokenData);

      return jsonResponse({
        connected: true,
        athlete: publicAthlete(tokenData.athlete),
        scope: tokenData.scope ?? null,
        expiresAt: toIsoExpiry(tokenData.expires_at),
      });
    }

    const connection = await getConnection(adminClient, user.id);

    if (action === 'status') {
      if (!connection) return jsonResponse({ connected: false });

      return jsonResponse({
        connected: true,
        athlete: publicAthlete(connection.athlete),
        scope: connection.scope ?? null,
        expiresAt: connection.expires_at,
      });
    }

    if (!connection) {
      return jsonResponse({ error: 'Strava is not connected' }, 404);
    }

    if (action === 'refresh') {
      const token = await ensureFreshAccessToken({
        adminClient,
        connection,
        clientId: stravaClientId,
        clientSecret: stravaClientSecret,
      });

      const athlete = await fetchAthlete(token);

      await adminClient
        .from('strava_connections')
        .update({
          athlete,
          athlete_id: numberOrNull(athlete?.id),
          athlete_username: stringOrNull(athlete?.username),
          athlete_firstname: stringOrNull(athlete?.firstname),
          athlete_lastname: stringOrNull(athlete?.lastname),
        })
        .eq('user_id', user.id);

      return jsonResponse({
        connected: true,
        athlete: publicAthlete(athlete),
        scope: connection.scope ?? null,
      });
    }

    await revokeToken(connection.access_token);
    await adminClient.from('strava_connections').delete().eq('user_id', user.id);

    return jsonResponse({ connected: false });
  } catch (error) {
    console.error('strava-auth error:', error);
    return jsonResponse({ error: 'Internal server error' }, 500);
  }
});

async function readJsonBody(req: Request): Promise<Record<string, unknown>> {
  try {
    const data = await req.json();
    return data && typeof data === 'object' ? data as Record<string, unknown> : {};
  } catch (_) {
    return {};
  }
}

function parseAction(value: unknown): Action {
  if (
    value === 'exchange' ||
    value === 'status' ||
    value === 'refresh' ||
    value === 'disconnect'
  ) {
    return value;
  }

  return 'status';
}

async function exchangeCode({
  code,
  clientId,
  clientSecret,
}: {
  code: string;
  clientId: string;
  clientSecret: string;
}): Promise<Record<string, any>> {
  const response = await fetch(`${STRAVA_OAUTH_BASE_URL}/oauth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      code,
      grant_type: 'authorization_code',
    }),
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error('Strava code exchange failed:', data);
    throw new Error('Could not connect Strava');
  }

  return data;
}

async function refreshToken({
  refreshToken,
  clientId,
  clientSecret,
}: {
  refreshToken: string;
  clientId: string;
  clientSecret: string;
}): Promise<Record<string, any>> {
  const response = await fetch(`${STRAVA_OAUTH_BASE_URL}/oauth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }),
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error('Strava token refresh failed:', data);
    throw new Error('Could not refresh Strava');
  }

  return data;
}

async function revokeToken(accessToken: string): Promise<void> {
  const response = await fetch(`${STRAVA_OAUTH_BASE_URL}/oauth/revoke`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    const data = await response.text().catch(() => '');
    console.warn('Strava token revoke failed:', response.status, data);
  }
}

async function fetchAthlete(accessToken: string): Promise<Record<string, any>> {
  const response = await fetch(`${STRAVA_API_BASE_URL}/athlete`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error('Strava athlete fetch failed:', data);
    throw new Error('Could not load Strava athlete');
  }

  return data;
}

async function getConnection(adminClient: any, userId: string) {
  const { data, error } = await adminClient
    .from('strava_connections')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle();

  if (error) {
    console.error('Strava connection lookup failed:', error);
    throw new Error('Could not load Strava connection');
  }

  return data;
}

async function ensureFreshAccessToken({
  adminClient,
  connection,
  clientId,
  clientSecret,
}: {
  adminClient: any;
  connection: any;
  clientId: string;
  clientSecret: string;
}): Promise<string> {
  const expiresAt = new Date(connection.expires_at).getTime();
  const refreshAt = Date.now() + 5 * 60 * 1000;

  if (expiresAt > refreshAt) return connection.access_token;

  const tokenData = await refreshToken({
    refreshToken: connection.refresh_token,
    clientId,
    clientSecret,
  });

  await adminClient
    .from('strava_connections')
    .update({
      access_token: tokenData.access_token,
      refresh_token: tokenData.refresh_token,
      expires_at: toIsoExpiry(tokenData.expires_at),
      scope: tokenData.scope ?? connection.scope,
    })
    .eq('user_id', connection.user_id);

  return tokenData.access_token;
}

async function upsertConnection(
  adminClient: any,
  userId: string,
  tokenData: Record<string, any>,
): Promise<void> {
  const athlete = tokenData.athlete ?? {};

  const { error } = await adminClient.from('strava_connections').upsert({
    user_id: userId,
    athlete_id: numberOrNull(athlete.id),
    athlete_username: stringOrNull(athlete.username),
    athlete_firstname: stringOrNull(athlete.firstname),
    athlete_lastname: stringOrNull(athlete.lastname),
    scope: stringOrNull(tokenData.scope),
    access_token: tokenData.access_token,
    refresh_token: tokenData.refresh_token,
    expires_at: toIsoExpiry(tokenData.expires_at),
    athlete,
    connected_at: new Date().toISOString(),
  });

  if (error) {
    console.error('Strava connection upsert failed:', error);
    throw new Error('Could not save Strava connection');
  }
}

function publicAthlete(athlete: Record<string, any> | null | undefined) {
  if (!athlete || typeof athlete !== 'object') return null;

  return {
    id: athlete.id ?? null,
    username: athlete.username ?? null,
    firstname: athlete.firstname ?? null,
    lastname: athlete.lastname ?? null,
    profile: athlete.profile ?? null,
    profileMedium: athlete.profile_medium ?? null,
  };
}

function toIsoExpiry(expiresAt: unknown): string {
  const seconds = typeof expiresAt === 'number'
    ? expiresAt
    : Number.parseInt(String(expiresAt), 10);
  return new Date(seconds * 1000).toISOString();
}

function stringOrNull(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : null;
}

function numberOrNull(value: unknown): number | null {
  const numberValue = typeof value === 'number'
    ? value
    : Number.parseInt(String(value), 10);
  return Number.isFinite(numberValue) ? numberValue : null;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}
