const INFOBIP_BASE_URL = Deno.env.get('INFOBIP_BASE_URL');
const INFOBIP_API_KEY = Deno.env.get('INFOBIP_API_KEY');
const INFOBIP_SENDER = Deno.env.get('INFOBIP_SENDER') ?? 'RydMatch';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*',
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function normalizePhoneNumber(value: unknown): string {
  const raw = String(value ?? '').trim();
  if (raw.startsWith('+')) {
    return `+${raw.slice(1).replace(/\D/g, '')}`;
  }

  const digits = raw.replace(/\D/g, '');
  if (digits.startsWith('00') && digits.length > 2) {
    return `+${digits.slice(2)}`;
  }

  return digits;
}

function isE164(value: string): boolean {
  return /^\+[1-9]\d{7,14}$/.test(value);
}

function normalizedBaseUrl(value: string): string {
  const trimmed = value.trim().replace(/\/+$/, '');
  return trimmed.startsWith('http') ? trimmed : `https://${trimmed}`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    if (!INFOBIP_BASE_URL || !INFOBIP_API_KEY) {
      return jsonResponse(
        {
          error:
            'Infobip credentials not configured. Set INFOBIP_BASE_URL and INFOBIP_API_KEY in Supabase secrets.',
        },
        500,
      );
    }

    const body = await req.json();
    const { riderName, contactPhone, latitude, longitude, isTest } = body;

    if (!riderName || !contactPhone) {
      return jsonResponse(
        { error: 'Missing required fields: riderName, contactPhone' },
        400,
      );
    }

    const normalizedContactPhone = normalizePhoneNumber(contactPhone);
    if (!isE164(normalizedContactPhone)) {
      return jsonResponse(
        {
          error:
            'Emergency contact phone number must be in international E.164 format, for example +971501234567.',
        },
        400,
      );
    }

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

    const mapsLink = `https://maps.google.com/?q=${lat},${lng}`;
    const title = isTest ? 'RydMatch TEST SOS' : 'RydMatch EMERGENCY SOS';
    const message =
      `${title} from ${riderName}\n\n` +
      'This rider needs immediate assistance.\n\n' +
      `Live Location: ${mapsLink}\n\n` +
      `Coordinates: ${lat.toFixed(6)}, ${lng.toFixed(6)}\n\n` +
      'Sent via RydMatch Emergency SOS';

    const endpoint = `${normalizedBaseUrl(INFOBIP_BASE_URL)}/sms/2/text/advanced`;

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `App ${INFOBIP_API_KEY}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        messages: [
          {
            from: INFOBIP_SENDER,
            destinations: [{ to: normalizedContactPhone }],
            text: message,
          },
        ],
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      const requestError =
        data?.requestError?.serviceException?.text ||
        data?.requestError?.serviceException?.messageId ||
        data?.message ||
        'Unknown Infobip error';

      return jsonResponse(
        {
          error: 'Failed to send SOS SMS',
          infobipError: requestError,
          details: data,
        },
        response.status,
      );
    }

    const firstMessage = data?.messages?.[0];
    const status = firstMessage?.status;

    if (status?.groupName === 'REJECTED') {
      return jsonResponse(
        {
          error: 'Failed to send SOS SMS',
          infobipError: status?.description ?? 'Infobip rejected the message',
          details: data,
        },
        400,
      );
    }

    return jsonResponse({
      success: true,
      messageSid: firstMessage?.messageId,
      status: status?.description ?? status?.name ?? 'Accepted by Infobip',
      provider: 'infobip',
    });
  } catch (error) {
    return jsonResponse(
      { error: 'Internal server error', details: String(error) },
      500,
    );
  }
});
