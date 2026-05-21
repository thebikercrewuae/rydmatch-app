const TWILIO_ACCOUNT_SID = Deno.env.get('TWILIO_ACCOUNT_SID');
const TWILIO_AUTH_TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN');
const TWILIO_PHONE_NUMBER = Deno.env.get('TWILIO_PHONE_NUMBER');

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_PHONE_NUMBER) {
      console.error('Missing Twilio environment variables');
      return jsonResponse(
        {
          error:
            'Twilio credentials not configured. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_PHONE_NUMBER in Supabase secrets.',
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
    const normalizedFromPhone = normalizePhoneNumber(TWILIO_PHONE_NUMBER);

    if (!isE164(normalizedContactPhone)) {
      return jsonResponse(
        {
          error:
            'Emergency contact phone number must be in international E.164 format, for example +971501234567.',
        },
        400,
      );
    }

    if (!isE164(normalizedFromPhone)) {
      return jsonResponse(
        {
          error:
            'TWILIO_PHONE_NUMBER must be in international E.164 format, for example +15551234567.',
        },
        500,
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

    const twilioUrl =
      `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;
    const credentials = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);

    const formData = new URLSearchParams({
      To: normalizedContactPhone,
      From: normalizedFromPhone,
      Body: message,
    });

    console.log(
      `Sending SOS SMS to ${normalizedContactPhone} from ${normalizedFromPhone}`,
    );

    const response = await fetch(twilioUrl, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${credentials}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: formData,
    });

    const data = await response.json();

    if (!response.ok) {
      console.error('Twilio API error:', JSON.stringify(data));
      const twilioMessage =
        data?.message || data?.error_message || 'Unknown Twilio error';
      const twilioCode = data?.code || data?.error_code || response.status;

      return jsonResponse(
        {
          error: 'Failed to send SOS SMS',
          twilioError: twilioMessage,
          twilioCode,
          details: data,
        },
        response.status,
      );
    }

    console.log(
      'Emergency SOS SMS sent successfully:',
      data.sid,
      'Status:',
      data.status,
    );
    return jsonResponse({
      success: true,
      messageSid: data.sid,
      status: data.status,
    });
  } catch (error) {
    console.error('Error sending SOS SMS:', error);
    return jsonResponse(
      { error: 'Internal server error', details: String(error) },
      500,
    );
  }
});
