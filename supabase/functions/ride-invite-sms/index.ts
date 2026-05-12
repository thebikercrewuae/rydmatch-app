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
    const record = payload.record ?? payload;

    const inviteId: string = record.id;
    const inviteeId: string = record.invitee_id;

    if (!inviteId || !inviteeId) {
      return new Response(
        JSON.stringify({ error: 'Missing invite id or invitee_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Get invitee phone number
    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('phone_number, full_name')
      .eq('id', inviteeId)
      .single();

    if (profileError || !profile) {
      console.error('Profile fetch error:', profileError);
      return new Response(
        JSON.stringify({ error: 'User profile not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!profile.phone_number) {
      console.log('No phone number for user:', inviteeId);
      return new Response(
        JSON.stringify({ skipped: true, reason: 'No phone number on file' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const message = "You've been invited to a group ride on RydMatch. Tap to view details.";
    const sent = await sendSms(profile.phone_number, message);

    if (sent) {
      // Mark SMS as sent
      await supabase
        .from('ride_group_invites')
        .update({ sms_sent: true })
        .eq('id', inviteId);
    }

    return new Response(
      JSON.stringify({ success: sent }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    console.error('ride-invite-sms error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
