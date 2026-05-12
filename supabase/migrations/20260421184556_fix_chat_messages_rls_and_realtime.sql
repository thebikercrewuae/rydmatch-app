-- Fix chat_messages RLS policies and enable Realtime
-- Ensures both sender AND recipient can SELECT messages
-- Enables Supabase Realtime publication for instant message delivery

-- 1. Drop and recreate the SELECT policy to be explicit about both directions
DROP POLICY IF EXISTS "users_can_read_own_messages" ON public.chat_messages;
CREATE POLICY "users_can_read_own_messages"
ON public.chat_messages
FOR SELECT
TO authenticated
USING (
  sender_id = auth.uid()
  OR recipient_id = auth.uid()
);

-- 2. Ensure INSERT policy allows sender to insert
DROP POLICY IF EXISTS "users_can_insert_own_messages" ON public.chat_messages;
CREATE POLICY "users_can_insert_own_messages"
ON public.chat_messages
FOR INSERT
TO authenticated
WITH CHECK (sender_id = auth.uid());

-- 3. Ensure UPDATE policy allows participants to update
DROP POLICY IF EXISTS "users_can_update_own_messages" ON public.chat_messages;
CREATE POLICY "users_can_update_own_messages"
ON public.chat_messages
FOR UPDATE
TO authenticated
USING (sender_id = auth.uid() OR recipient_id = auth.uid())
WITH CHECK (sender_id = auth.uid() OR recipient_id = auth.uid());

-- 4. Enable Realtime on chat_messages so INSERT events are broadcast to subscribers
-- This is required for the Flutter Realtime subscription to receive new messages
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;

-- 5. Add index on recipient_id for fast lookups (if not already present)
CREATE INDEX IF NOT EXISTS idx_chat_messages_recipient_id ON public.chat_messages(recipient_id);

-- 6. Add composite index for conversation queries
CREATE INDEX IF NOT EXISTS idx_chat_messages_conv_created ON public.chat_messages(conversation_id, created_at);
