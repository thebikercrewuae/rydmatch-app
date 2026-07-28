import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-scheduled-secret',
};

type DiagnosticRow = {
  feature: string | null;
  action: string | null;
  severity: string | null;
  message: string | null;
  context: Record<string, unknown> | null;
  platform: string | null;
  created_at: string | null;
};

type ReviewTrigger = 'manual' | 'scheduled';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const groqKey = Deno.env.get('GROQ_API_KEY');
    const scheduleSecret = Deno.env.get('DIAGNOSTICS_SCHEDULE_SECRET');
    const model = Deno.env.get('GROQ_DIAGNOSTICS_MODEL') ?? 'llama-3.3-70b-versatile';
    const authHeader = req.headers.get('Authorization') ?? '';
    const scheduleHeader = req.headers.get('x-scheduled-secret') ?? '';

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return jsonResponse(
        { error: 'AI diagnostics service is missing Supabase configuration' },
        500,
      );
    }
    const body = await safeJson(req);
    const days = clampNumber(body.days, 1, 30, 30);
    const feature = cleanFilter(body.feature);
    const severity = cleanFilter(body.severity);
    const since = new Date(Date.now() - days * 86400000).toISOString();

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const auth = await verifyAccess({
      supabaseUrl,
      anonKey,
      authHeader,
      scheduleSecret,
      scheduleHeader,
    });
    if (!auth.allowed) {
      return jsonResponse({ error: auth.error }, auth.status);
    }

    let query = admin
      .from('app_errors')
      .select('feature, action, severity, message, context, platform, created_at')
      .eq('is_debug', false)
      .gte('created_at', since)
      .order('created_at', { ascending: false })
      .limit(500);

    if (feature) query = query.eq('feature', feature);
    if (severity) query = query.eq('severity', severity);

    const { data, error } = await query;
    if (error) {
      console.error('admin-diagnostics-review query error:', error);
      return jsonResponse({ error: 'Could not load diagnostics' }, 500);
    }

    const rows = (data ?? []) as DiagnosticRow[];
    const summary = buildDiagnosticSummary(rows, { days, feature, severity });
    const reviewResult = await buildReview({
      apiKey: groqKey,
      model,
      summary,
    });
    const maintenance = await runSafeMaintenance(admin, auth.trigger);
    const responseBody = {
      generatedAt: new Date().toISOString(),
      days,
      filters: { feature, severity },
      trigger: auth.trigger,
      ...reviewResult.review,
      aiProvider: reviewResult.provider,
      aiWarning: reviewResult.warning,
      maintenance,
      source: {
        totalEvents: rows.length,
        groupedIssues: summary.issues.length,
      },
    };

    const reviewId = await storeReview(admin, responseBody, auth.userId);
    if (auth.trigger === 'scheduled') {
      await notifyAdminsOfReview(admin, responseBody, reviewId);
    }

    return jsonResponse(responseBody);
  } catch (error) {
    console.error('admin-diagnostics-review error:', error);
    return jsonResponse({ error: publicErrorMessage(error) }, 500);
  }
});

async function verifyAccess({
  supabaseUrl,
  anonKey,
  authHeader,
  scheduleSecret,
  scheduleHeader,
}: {
  supabaseUrl: string;
  anonKey: string;
  authHeader: string;
  scheduleSecret?: string;
  scheduleHeader: string;
}): Promise<
  | { allowed: true; trigger: ReviewTrigger; userId: string | null }
  | { allowed: false; status: number; error: string }
> {
  if (scheduleSecret && scheduleHeader && scheduleHeader === scheduleSecret) {
    return { allowed: true, trigger: 'scheduled', userId: null };
  }

  if (!authHeader) {
    return { allowed: false, status: 401, error: 'Missing authorization header' };
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return { allowed: false, status: 401, error: 'Not signed in' };
  }

  const { data: isAdmin, error: adminError } = await userClient.rpc(
    'is_admin_user',
  );
  if (adminError || isAdmin !== true) {
    return { allowed: false, status: 403, error: 'Admin access required' };
  }

  return { allowed: true, trigger: 'manual', userId: user.id };
}

async function runSafeMaintenance(admin: any, trigger: ReviewTrigger) {
  const maintenance: Record<string, unknown> = {
    trigger,
    actions: [],
    warnings: [],
  };
  const actions = maintenance.actions as Array<Record<string, unknown>>;
  const warnings = maintenance.warnings as string[];

  try {
    const { data, error } = await admin.rpc('expire_ambassador_access');
    if (error) {
      warnings.push(`Could not expire ambassador access: ${error.message}`);
    } else {
      actions.push({
        name: 'expire_ambassador_access',
        affectedRows: typeof data === 'number' ? data : null,
      });
    }
  } catch (error) {
    warnings.push(`Ambassador maintenance skipped: ${String(error)}`);
  }

  return maintenance;
}

async function storeReview(
  admin: any,
  review: Record<string, unknown>,
  userId: string | null,
): Promise<string | null> {
  try {
    const source = review.source as Record<string, unknown> | undefined;
    const { data, error } = await admin.from('admin_diagnostic_reviews').insert({
      generated_at: review.generatedAt,
      trigger_source: review.trigger,
      created_by: userId,
      days: review.days,
      total_events: source?.totalEvents ?? null,
      grouped_issues: source?.groupedIssues ?? null,
      review,
      maintenance: review.maintenance ?? {},
    }).select('id').single();
    if (error) {
      console.error('admin-diagnostics-review store error:', error);
      return null;
    }
    return typeof data?.id === 'string' ? data.id : null;
  } catch (error) {
    console.error('admin-diagnostics-review store exception:', error);
    return null;
  }
}

async function notifyAdminsOfReview(
  admin: any,
  review: Record<string, unknown>,
  reviewId: string | null,
) {
  try {
    const { data: admins, error: adminError } = await admin
      .from('user_profiles')
      .select('id')
      .eq('is_admin', true);

    if (adminError) {
      console.error('admin-diagnostics-review admin lookup error:', adminError);
      return;
    }

    const rows = (admins ?? [])
      .map((row: { id?: string }) => row.id)
      .filter((id: unknown): id is string => typeof id === 'string')
      .map((userId: string) => ({
        user_id: userId,
        notification_type: 'admin_diagnostics_review',
        title: 'Daily AI diagnostics review',
        message: buildNotificationMessage(review),
        action_route: '/admin-diagnostics-screen',
        action_arguments: {
          review_id: reviewId,
          generated_at: review.generatedAt,
          total_events: (review.source as Record<string, unknown> | undefined)
            ?.totalEvents ?? 0,
          grouped_issues: (review.source as Record<string, unknown> | undefined)
            ?.groupedIssues ?? 0,
          days: review.days,
        },
        reference_id: reviewId,
      }));

    if (rows.length === 0) return;

    const { error } = await admin.from('notifications').insert(rows);
    if (error) {
      console.error('admin-diagnostics-review notification error:', error);
    }
  } catch (error) {
    console.error('admin-diagnostics-review notification exception:', error);
  }
}

function buildNotificationMessage(review: Record<string, unknown>): string {
  const source = review.source as Record<string, unknown> | undefined;
  const total = Number(source?.totalEvents ?? 0);
  const blockers = Array.isArray(review.releaseBlockers)
    ? review.releaseBlockers.length
    : 0;
  const actions = Array.isArray(review.recommendedNextActions)
    ? review.recommendedNextActions
    : [];
  const topAction = typeof actions[0] === 'string' ? actions[0] : '';
  const overview = typeof review.overview === 'string' ? review.overview : '';
  const summary = overview || `${total} diagnostic events reviewed.`;
  const actionText = topAction ? ` Top fix: ${topAction}` : '';
  return `${summary} ${blockers} blocker(s).${actionText}`.slice(0, 450);
}

function buildDiagnosticSummary(
  rows: DiagnosticRow[],
  filters: { days: number; feature: string | null; severity: string | null },
) {
  const grouped = new Map<
    string,
    {
      feature: string;
      action: string;
      severity: string;
      message: string;
      count: number;
      firstSeen: string | null;
      lastSeen: string | null;
      platforms: Set<string>;
      contextKeys: Set<string>;
    }
  >();

  const severityCounts: Record<string, number> = {};
  const featureCounts: Record<string, number> = {};

  for (const row of rows) {
    const feature = cleanText(row.feature, 'unknown');
    const action = cleanText(row.action, 'unknown');
    const severity = cleanText(row.severity, 'unknown');
    const message = sanitizeMessage(cleanText(row.message, 'No message'));
    const key = `${feature}|${action}|${severity}|${message}`;
    const existing = grouped.get(key) ?? {
      feature,
      action,
      severity,
      message,
      count: 0,
      firstSeen: row.created_at,
      lastSeen: row.created_at,
      platforms: new Set<string>(),
      contextKeys: new Set<string>(),
    };

    existing.count += 1;
    existing.firstSeen = earlier(existing.firstSeen, row.created_at);
    existing.lastSeen = later(existing.lastSeen, row.created_at);
    if (row.platform) existing.platforms.add(row.platform);
    for (const contextKey of Object.keys(row.context ?? {})) {
      existing.contextKeys.add(contextKey);
    }
    grouped.set(key, existing);

    severityCounts[severity] = (severityCounts[severity] ?? 0) + 1;
    featureCounts[feature] = (featureCounts[feature] ?? 0) + 1;
  }

  const issues = [...grouped.values()]
    .sort((a, b) => {
      const severityRank =
        severityWeight(b.severity) - severityWeight(a.severity);
      if (severityRank !== 0) return severityRank;
      return b.count - a.count;
    })
    .slice(0, 25)
    .map((issue) => ({
      feature: issue.feature,
      action: issue.action,
      severity: issue.severity,
      message: issue.message,
      count: issue.count,
      firstSeen: issue.firstSeen,
      lastSeen: issue.lastSeen,
      platforms: [...issue.platforms].slice(0, 4),
      contextKeys: [...issue.contextKeys].slice(0, 12),
    }));

  return {
    product: 'RydMatch',
    reviewMode: 'read_only',
    filters,
    totalEvents: rows.length,
    severityCounts,
    featureCounts,
    issues,
  };
}

async function buildReview({
  apiKey,
  model,
  summary,
}: {
  apiKey?: string;
  model: string;
  summary: ReturnType<typeof buildDiagnosticSummary>;
}): Promise<{
  review: Record<string, unknown>;
  provider: 'groq' | 'fallback';
  warning: string | null;
}> {
  if (!apiKey) {
    return {
      review: buildFallbackReview(summary),
      provider: 'fallback',
      warning: 'GROQ_API_KEY is not configured; using local diagnostic summary.',
    };
  }

  try {
    return {
      review: await generateAiReview({ apiKey, model, summary }),
      provider: 'groq',
      warning: null,
    };
  } catch (error) {
    console.error('admin-diagnostics-review Groq fallback:', error);
    return {
      review: buildFallbackReview(summary),
      provider: 'fallback',
      warning: `Groq review unavailable: ${publicErrorMessage(error)}`,
    };
  }
}

function buildFallbackReview(
  summary: ReturnType<typeof buildDiagnosticSummary>,
): Record<string, unknown> {
  const issues = summary.issues ?? [];
  const errorIssues = issues.filter((issue) => issue.severity === 'error');
  const warningIssues = issues.filter((issue) => issue.severity === 'warning');
  const topIssues = issues.slice(0, 6);
  const topFeature = Object.entries(summary.featureCounts ?? {}).sort(
    (a, b) => Number(b[1]) - Number(a[1]),
  )[0]?.[0] ?? 'none';

  return {
    overview:
      `${summary.totalEvents} diagnostic event(s) reviewed across ${issues.length} grouped issue(s). ` +
      `${errorIssues.length} error group(s), ${warningIssues.length} warning group(s). Top area: ${topFeature}.`,
    releaseBlockers: errorIssues.slice(0, 5).map((issue) =>
      `${issue.feature}/${issue.action}: ${issue.message}`,
    ),
    likelyRootCauses: topIssues.map((issue) =>
      `${issue.feature}/${issue.action} repeated ${issue.count} time(s): ${issue.message}`,
    ),
    recommendedNextActions: topIssues.map((issue) =>
      `Investigate ${issue.feature}/${issue.action}; verify schema, secrets, or network dependency related to this message.`,
    ),
    privacyNotes: [
      'Fallback review is generated from grouped diagnostics only and does not modify app data, SQL, or code.',
      'User identifiers and email addresses are not included in the OpenAI/fallback summary payload.',
    ],
  };
}
async function generateAiReview({
  apiKey,
  model,
  summary,
}: {
  apiKey: string;
  model: string;
  summary: unknown;
}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 18000);

  const systemPrompt =
    'You are a senior mobile reliability reviewer for RydMatch. Review diagnostics in read-only mode. ' +
    'Do not claim to have changed data, code, SQL, policies, or deployments. Avoid exposing personal data. ' +
    'Be concise and practical. For each issue, give a likely root cause and a concrete, specific recommended fix ' +
    '(for example: the exact Supabase secret to set, the migration to run, the column to add, or the config to change).\n\n' +
    'Return ONLY a JSON object with exactly these fields:\n' +
    '- overview: string\n' +
    '- releaseBlockers: array of strings (max 5)\n' +
    '- likelyRootCauses: array of strings (max 6)\n' +
    '- recommendedNextActions: array of strings (max 6)\n' +
    '- privacyNotes: array of strings (max 4)\n' +
    'Do not include any text outside the JSON object.';

  const userPrompt =
    'Analyze this grouped diagnostic summary and return JSON only.\n\n' +
    JSON.stringify(summary);

  let response: Response;
  try {
    response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        response_format: { type: 'json_object' },
        temperature: 0.2,
      }),
    });
  } finally {
    clearTimeout(timeout);
  }

  const data = await safeResponseJson(response);
  if (!response.ok) {
    const errorMessage =
      typeof data?.error?.message === 'string'
        ? data.error.message
        : `Groq request failed with HTTP ${response.status}`;

    console.error('Groq diagnostics review error:', {
      status: response.status,
      error: data?.error ?? data,
    });

    throw new Error(errorMessage);
  }

  const text = extractGroqText(data);
  if (!text) {
    throw new Error('AI diagnostics review returned no text');
  }

  return JSON.parse(text);
}

function extractGroqText(data: any): string | null {
  const choices = Array.isArray(data?.choices) ? data.choices : [];
  for (const choice of choices) {
    const content = choice?.message?.content;
    if (typeof content === 'string' && content.trim()) {
      return content;
    }
  }
  return null;
}

async function safeResponseJson(response: Response): Promise<any> {
  try {
    return await response.json();
  } catch (_) {
    return null;
  }
}
function extractOutputText(data: any): string | null {
  const output = Array.isArray(data?.output) ? data.output : [];
  for (const item of output) {
    const content = Array.isArray(item?.content) ? item.content : [];
    for (const part of content) {
      if (typeof part?.text === 'string') return part.text;
    }
  }
  return null;
}

async function safeJson(req: Request): Promise<Record<string, unknown>> {
  try {
    return await req.json();
  } catch (_) {
    return {};
  }
}

function clampNumber(
  value: unknown,
  min: number,
  max: number,
  fallback: number,
): number {
  const parsed =
    typeof value === 'number' ? value : Number.parseInt(String(value ?? ''), 10);
  if (Number.isNaN(parsed)) return fallback;
  return Math.max(min, Math.min(max, parsed));
}

function cleanFilter(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed === 'all') return null;
  return trimmed.slice(0, 80);
}

function cleanText(value: unknown, fallback: string): string {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  return trimmed || fallback;
}

function sanitizeMessage(message: string): string {
  return message
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[email]')
    .replace(
      /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi,
      '[uuid]',
    )
    .slice(0, 700);
}

function severityWeight(severity: string): number {
  if (severity === 'error') return 3;
  if (severity === 'warning') return 2;
  if (severity === 'info') return 1;
  return 0;
}

function earlier(left: string | null, right: string | null): string | null {
  if (!left) return right;
  if (!right) return left;
  return left < right ? left : right;
}

function later(left: string | null, right: string | null): string | null {
  if (!left) return right;
  if (!right) return left;
  return left > right ? left : right;
}

function publicErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim()) {
    return error.message.slice(0, 300);
  }
  const text = String(error ?? '').trim();
  return text ? text.slice(0, 300) : 'Internal server error';
}
function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
