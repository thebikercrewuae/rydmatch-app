import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Twilio sends status callbacks as URL-encoded form data
    const formData = await req.formData();
    const messageSid = formData.get('MessageSid') as string;
    const messageStatus = formData.get('MessageStatus') as string;

    if (!messageSid || !messageStatus) {
      return new Response(
        JSON.stringify({ error: 'Missing MessageSid or MessageStatus' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Map Twilio status to our internal status
    const statusMap: Record<string, string> = {
      queued: 'sent',
      accepted: 'sent',
      sending: 'sent',
      sent: 'sent',
      delivered: 'delivered',
      read: 'read',
      failed: 'failed',
      undelivered: 'failed',
    };

    const internalStatus = statusMap[messageStatus.toLowerCase()] ?? 'sent';

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { error } = await supabase
      .from('chat_messages')
      .update({
        delivery_status: internalStatus,
        status_updated_at: new Date().toISOString(),
      })
      .eq('twilio_message_sid', messageSid);

    if (error) {
      console.error('Supabase update error:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to update status', details: error.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`Updated message ${messageSid} to status: ${internalStatus}`);

    // Twilio expects a 200 response with empty body or TwiML
    return new Response('<?xml version="1.0" encoding="UTF-8"?><Response></Response>', {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'text/xml' },
    });
  } catch (error) {
    console.error('Webhook error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
