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
    const openAiKey = Deno.env.get('OPENAI_API_KEY');
    const scheduleSecret = Deno.env.get('DIAGNOSTICS_SCHEDULE_SECRET');
    const model = Deno.env.get('OPENAI_DIAGNOSTICS_MODEL') ?? 'gpt-4.1-mini';
    const authHeader = req.headers.get('Authorization') ?? '';
    const scheduleHeader = req.headers.get('x-scheduled-secret') ?? '';

    if (!supabaseUrl || !anonKey || !serviceRoleKey || !openAiKey) {
      return jsonResponse(
        { error: 'AI diagnostics service is not configured' },
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
    const review = await generateAiReview({
      apiKey: openAiKey,
      model,
      summary,
    });
    const maintenance = await runSafeMaintenance(admin, auth.trigger);
    const responseBody = {
      generatedAt: new Date().toISOString(),
      days,
      filters: { feature, severity },
      trigger: auth.trigger,
      ...review,
      maintenance,
      source: {
        totalEvents: rows.length,
        groupedIssues: summary.issues.length,
      },
    };

    await storeReview(admin, responseBody, auth.userId);

    return jsonResponse(responseBody);
  } catch (error) {
    console.error('admin-diagnostics-review error:', error);
    return jsonResponse({ error: 'Internal server error' }, 500);
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
) {
  try {
    const source = review.source as Record<string, unknown> | undefined;
    const { error } = await admin.from('admin_diagnostic_reviews').insert({
      generated_at: review.generatedAt,
      trigger_source: review.trigger,
      created_by: userId,
      days: review.days,
      total_events: source?.totalEvents ?? null,
      grouped_issues: source?.groupedIssues ?? null,
      review,
      maintenance: review.maintenance ?? {},
    });
    if (error) {
      console.error('admin-diagnostics-review store error:', error);
    }
  } catch (error) {
    console.error('admin-diagnostics-review store exception:', error);
  }
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

async function generateAiReview({
  apiKey,
  model,
  summary,
}: {
  apiKey: string;
  model: string;
  summary: unknown;
}) {
  const response = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: 'system',
          content:
            'You are a senior mobile reliability reviewer for RydMatch. Review diagnostics in read-only mode. Do not claim to have changed data, code, SQL, policies, or deployments. Avoid exposing personal data. Be concise and practical.',
        },
        {
          role: 'user',
          content:
            `Analyze this grouped diagnostic summary and return JSON only.\n\n${JSON.stringify(summary)}`,
        },
      ],
      text: {
        format: {
          type: 'json_schema',
          name: 'diagnostic_review',
          strict: true,
          schema: {
            type: 'object',
            additionalProperties: false,
            properties: {
              overview: { type: 'string' },
              releaseBlockers: {
                type: 'array',
                items: { type: 'string' },
                maxItems: 5,
              },
              likelyRootCauses: {
                type: 'array',
                items: { type: 'string' },
                maxItems: 6,
              },
              recommendedNextActions: {
                type: 'array',
                items: { type: 'string' },
                maxItems: 6,
              },
              privacyNotes: {
                type: 'array',
                items: { type: 'string' },
                maxItems: 4,
              },
            },
            required: [
              'overview',
              'releaseBlockers',
              'likelyRootCauses',
              'recommendedNextActions',
              'privacyNotes',
            ],
          },
        },
      },
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    console.error('OpenAI diagnostics review error:', data);
    throw new Error('Could not generate AI diagnostics review');
  }

  const text =
    typeof data.output_text === 'string' ? data.output_text : extractOutputText(data);
  if (!text) {
    throw new Error('AI diagnostics review returned no text');
  }

  return JSON.parse(text);
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

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
