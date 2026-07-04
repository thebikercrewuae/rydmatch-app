import http from 'k6/http';
import exec from 'k6/execution';
import { check, fail, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const supabaseUrl = (__ENV.SUPABASE_URL || '').replace(/\/$/, '');
const anonKey = __ENV.SUPABASE_ANON_KEY || '';
const accountsFile = __ENV.LOAD_TEST_ACCOUNTS_FILE || './load-tests/accounts.json';
const accounts = JSON.parse(open(accountsFile));

const discoveryLatency = new Trend('discovery_latency', true);
const chatLatency = new Trend('chat_latency', true);
const liveLocationLatency = new Trend('live_location_latency', true);
const discoveryFailures = new Rate('discovery_failures');
const chatFailures = new Rate('chat_failures');
const liveLocationFailures = new Rate('live_location_failures');

function positiveInt(value, fallback) {
  const parsed = Number.parseInt(value || '', 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
}

const duration = __ENV.LOAD_TEST_DURATION || '30s';
export const options = {
  discardResponseBodies: true,
  scenarios: {
    discovery: { executor: 'constant-vus', exec: 'discoveryScenario', vus: positiveInt(__ENV.DISCOVERY_VUS, 2), duration, gracefulStop: '10s' },
    chat_reads: { executor: 'constant-vus', exec: 'chatScenario', vus: positiveInt(__ENV.CHAT_VUS, 1), duration, gracefulStop: '10s' },
    live_location: { executor: 'constant-vus', exec: 'liveLocationScenario', vus: positiveInt(__ENV.LIVE_LOCATION_VUS, 1), duration, gracefulStop: '10s' },
  },
  thresholds: {
    checks: ['rate>0.99'],
    http_req_failed: ['rate<0.01'],
    discovery_failures: ['rate<0.01'],
    chat_failures: ['rate<0.01'],
    live_location_failures: ['rate<0.01'],
    discovery_latency: ['p(95)<750'],
    chat_latency: ['p(95)<500'],
    live_location_latency: ['p(95)<500'],
  },
};

function validateConfiguration() {
  if (!supabaseUrl || !anonKey) fail('SUPABASE_URL and SUPABASE_ANON_KEY are required.');
  if (!Array.isArray(accounts) || accounts.length === 0) fail(`${accountsFile} must contain synthetic accounts.`);
  const isProduction = supabaseUrl.includes('tbdmucmrsftbrgvszvxa') || (__ENV.LOAD_TEST_ENVIRONMENT || '').toLowerCase() === 'production';
  if (isProduction && __ENV.ALLOW_PRODUCTION_LOAD_TEST !== 'true') {
    fail('Production load testing is locked. Use staging or explicitly set ALLOW_PRODUCTION_LOAD_TEST=true.');
  }
}

function authHeaders(accessToken) {
  return { apikey: anonKey, Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' };
}

export function setup() {
  validateConfiguration();
  return accounts.map((account, index) => {
    if (!account.email || !account.password) fail(`Synthetic account ${index + 1} is missing credentials.`);
    const response = http.post(
      `${supabaseUrl}/auth/v1/token?grant_type=password`,
      JSON.stringify({ email: account.email, password: account.password }),
      { headers: { apikey: anonKey, 'Content-Type': 'application/json' }, responseType: 'text', tags: { operation: 'authenticate' } },
    );
    const authenticated = check(response, { 'synthetic account authenticated': (r) => r.status === 200 });
    if (!authenticated) fail(`Authentication failed for synthetic account ${index + 1}.`);
    const body = response.json();
    return {
      ...account,
      accessToken: body.access_token,
      userId: body.user.id,
      latitude: Number(account.latitude ?? 25.2048),
      longitude: Number(account.longitude ?? 55.2708),
    };
  });
}

function accountForVu(data) {
  return data[(exec.vu.idInTest - 1) % data.length];
}

export function discoveryScenario(data) {
  const account = accountForVu(data);
  const response = http.post(
    `${supabaseUrl}/rest/v1/rpc/get_discovery_profiles`,
    JSON.stringify({
      p_current_user_id: account.userId,
      p_excluded_ids: [],
      p_latitude: account.latitude,
      p_longitude: account.longitude,
      p_radius_meters: Number(account.radiusMeters ?? 100000),
      p_limit: 20,
      p_offset: 0,
    }),
    { headers: authHeaders(account.accessToken), tags: { operation: 'discovery' } },
  );
  discoveryLatency.add(response.timings.duration);
  const ok = check(response, { 'discovery returned 200': (r) => r.status === 200 });
  discoveryFailures.add(!ok);
  sleep(1);
}

export function chatScenario(data) {
  const account = accountForVu(data);
  if (!account.conversationId) fail(`Account ${account.email} is missing conversationId.`);
  const select = encodeURIComponent('id,sender_id,recipient_id,message_body,delivery_status,created_at');
  const conversation = encodeURIComponent(account.conversationId);
  const response = http.get(
    `${supabaseUrl}/rest/v1/chat_messages?select=${select}&conversation_id=eq.${conversation}&order=created_at.desc&limit=50`,
    { headers: authHeaders(account.accessToken), tags: { operation: 'chat_read' } },
  );
  chatLatency.add(response.timings.duration);
  const ok = check(response, { 'chat history returned 200': (r) => r.status === 200 });
  chatFailures.add(!ok);
  sleep(1);
}

export function liveLocationScenario(data) {
  const account = accountForVu(data);
  if (!account.liveRideSessionId) fail(`Account ${account.email} is missing liveRideSessionId.`);
  const step = (__ITER % 20) * 0.00001;
  const response = http.post(
    `${supabaseUrl}/rest/v1/live_ride_current_locations?on_conflict=session_id,user_id`,
    JSON.stringify({
      session_id: account.liveRideSessionId,
      user_id: account.userId,
      latitude: account.latitude + step,
      longitude: account.longitude + step,
      heading: (__ITER * 7) % 360,
      speed: 13.5,
      accuracy: 8.0,
      updated_at: new Date().toISOString(),
    }),
    { headers: { ...authHeaders(account.accessToken), Prefer: 'resolution=merge-duplicates,return=minimal' }, tags: { operation: 'live_location_write' } },
  );
  liveLocationLatency.add(response.timings.duration);
  const ok = check(response, { 'live location upsert succeeded': (r) => [200, 201, 204].includes(r.status) });
  liveLocationFailures.add(!ok);
  sleep(5);
}

export function handleSummary(data) {
  return {
    'load-tests/results/latest-summary.json': JSON.stringify(data, null, 2),
    stdout: '\nRydMatch load test complete. Full summary: load-tests/results/latest-summary.json\n',
  };
}

