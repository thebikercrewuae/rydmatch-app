const TWILIO_ACCOUNT_SID = Deno.env.get('TWILIO_ACCOUNT_SID');
const TWILIO_AUTH_TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN');
const TWILIO_PHONE_NUMBER = Deno.env.get('TWILIO_PHONE_NUMBER');

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*'
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Validate Twilio credentials are configured
    if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_PHONE_NUMBER) {
      console.error('Missing Twilio environment variables');
      return new Response(
        JSON.stringify({ error: 'Twilio credentials not configured. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_PHONE_NUMBER in Supabase secrets.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const body = await req.json();
    const { riderName, contactPhone, latitude, longitude } = body;

    if (!riderName || !contactPhone) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: riderName, contactPhone' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (latitude == null || longitude == null) {
      return new Response(
        JSON.stringify({ error: 'Missing GPS coordinates: latitude and longitude are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const lat = parseFloat(String(latitude));
    const lng = parseFloat(String(longitude));

    if (isNaN(lat) || isNaN(lng)) {
      return new Response(
        JSON.stringify({ error: 'Invalid GPS coordinates: latitude and longitude must be valid numbers' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const mapsLink = `https://maps.google.com/?q=${lat},${lng}`;
    const message = `🚨 EMERGENCY SOS from ${riderName}\n\nThis rider needs immediate assistance!\n\nLive Location: ${mapsLink}\n\nCoordinates: ${lat.toFixed(6)}, ${lng.toFixed(6)}\n\nSent via RydMatch Emergency SOS`;

    const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;
    const credentials = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);

    const formData = new URLSearchParams({
      To: contactPhone,
      From: TWILIO_PHONE_NUMBER,
      Body: message
    });

    console.log(`Sending SOS SMS to ${contactPhone} from ${TWILIO_PHONE_NUMBER}`);

    const response = await fetch(twilioUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${credentials}`,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: formData
    });

    const data = await response.json();

    if (!response.ok) {
      console.error('Twilio API error:', JSON.stringify(data));
      const twilioMessage = data?.message || data?.error_message || 'Unknown Twilio error';
      const twilioCode = data?.code || data?.error_code || response.status;
      return new Response(
        JSON.stringify({ 
          error: 'Failed to send SOS SMS', 
          twilioError: twilioMessage,
          twilioCode: twilioCode,
          details: data 
        }),
        { status: response.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('Emergency SOS SMS sent successfully:', data.sid, 'Status:', data.status);
    return new Response(
      JSON.stringify({ success: true, messageSid: data.sid, status: data.status }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error sending SOS SMS:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: String(error) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
