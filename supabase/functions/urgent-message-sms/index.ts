import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const TWILIO_ACCOUNT_SID = Deno.env.get('TWILIO_ACCOUNT_SID');
const TWILIO_AUTH_TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN');
const TWILIO_PHONE_NUMBER = Deno.env.get('TWILIO_PHONE_NUMBER');

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*',
};

async function sendSms(to: string, body: string): Promise<boolean> {
  const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;
  const credentials = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);

  const formData = new URLSearchParams({
    To: to,
    From: TWILIO_PHONE_NUMBER!,
    Body: body,
  });

  const response = await fetch(twilioUrl, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: formData,
  });

  if (!response.ok) {
    const error = await response.json();
    console.error('Twilio error:', error);
    return false;
  }

  const data = await response.json();
  console.log('SMS sent, SID:', data.sid);
  return true;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const payload = await req.json();
    // Supports both direct call and Supabase database webhook payload
    // For INSERT events on urgent messages, or UPDATE events where is_urgent becomes true
    const record = payload.record ?? payload;

    const messageId: string = record.id;
    const recipientId: string = record.recipient_id;
    const isUrgent: boolean = record.is_urgent ?? false;
    const deliveryStatus: string = record.delivery_status ?? 'sending';
    const smsAlertSent: boolean = record.sms_alert_sent ?? false;

    if (!messageId || !recipientId) {
      return new Response(
        JSON.stringify({ error: 'Missing message id or recipient_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Only send SMS for urgent messages or messages that remain unread (sent/delivered but not read)
    const shouldAlert = isUrgent || deliveryStatus === 'delivered';

    if (!shouldAlert) {
      return new Response(
        JSON.stringify({ skipped: true, reason: 'Message is not urgent and not unread' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (smsAlertSent) {
      return new Response(
        JSON.stringify({ skipped: true, reason: 'SMS alert already sent for this message' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Get recipient phone number
    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('phone_number, full_name')
      .eq('id', recipientId)
      .single();

    if (profileError || !profile) {
      console.error('Profile fetch error:', profileError);
      return new Response(
        JSON.stringify({ error: 'User profile not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!profile.phone_number) {
      console.log('No phone number for user:', recipientId);
      return new Response(
        JSON.stringify({ skipped: true, reason: 'No phone number on file' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const message = 'You have an unread urgent message from a rider on RydMatch.';
    const sent = await sendSms(profile.phone_number, message);

    if (sent) {
      // Mark SMS alert as sent to avoid duplicates
      await supabase
        .from('chat_messages')
        .update({ sms_alert_sent: true })
        .eq('id', messageId);
    }

    return new Response(
      JSON.stringify({ success: sent }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    console.error('urgent-message-sms error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
