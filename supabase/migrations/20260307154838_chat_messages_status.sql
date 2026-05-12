-- Chat messages table with Twilio delivery status tracking

-- 1. Types
DROP TYPE IF EXISTS public.message_status CASCADE;
CREATE TYPE public.message_status AS ENUM ('sending', 'sent', 'delivered', 'read', 'failed');

-- 2. Core tables
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id TEXT NOT NULL,
    sender_id UUID NOT NULL,
    recipient_id UUID NOT NULL,
    message_body TEXT NOT NULL,
    is_image BOOLEAN DEFAULT false,
    twilio_message_sid TEXT,
    delivery_status public.message_status DEFAULT 'sending'::public.message_status,
    status_updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_id ON public.chat_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON public.chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_twilio_sid ON public.chat_messages(twilio_message_sid);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages(created_at);

-- 4. Enable RLS
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies — participants in a conversation can read/write
DROP POLICY IF EXISTS "users_can_read_own_messages" ON public.chat_messages;
CREATE POLICY "users_can_read_own_messages"
ON public.chat_messages
FOR SELECT
TO authenticated
USING (sender_id = auth.uid() OR recipient_id = auth.uid());

DROP POLICY IF EXISTS "users_can_insert_own_messages" ON public.chat_messages;
CREATE POLICY "users_can_insert_own_messages"
ON public.chat_messages
FOR INSERT
TO authenticated
WITH CHECK (sender_id = auth.uid());

DROP POLICY IF EXISTS "users_can_update_own_messages" ON public.chat_messages;
CREATE POLICY "users_can_update_own_messages"
ON public.chat_messages
FOR UPDATE
TO authenticated
USING (sender_id = auth.uid() OR recipient_id = auth.uid())
WITH CHECK (sender_id = auth.uid() OR recipient_id = auth.uid());

-- Allow service_role (edge function) to update status from Twilio webhooks
DROP POLICY IF EXISTS "service_role_update_status" ON public.chat_messages;
CREATE POLICY "service_role_update_status"
ON public.chat_messages
FOR UPDATE
TO service_role
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_insert_messages" ON public.chat_messages;
CREATE POLICY "service_role_insert_messages"
ON public.chat_messages
FOR INSERT
TO service_role
WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_select_messages" ON public.chat_messages;
CREATE POLICY "service_role_select_messages"
ON public.chat_messages
FOR SELECT
TO service_role
USING (true);
