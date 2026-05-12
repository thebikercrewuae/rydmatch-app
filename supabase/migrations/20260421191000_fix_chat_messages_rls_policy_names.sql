-- Fix chat_messages RLS policies using correct column names (recipient_id, message_body)
-- Uses exact policy names: chat_messages_select and chat_messages_insert

DROP POLICY IF EXISTS "chat_messages_select" ON chat_messages;
CREATE POLICY "chat_messages_select" ON chat_messages
FOR SELECT USING (
  sender_id = auth.uid() OR recipient_id = auth.uid()
);

DROP POLICY IF EXISTS "chat_messages_insert" ON chat_messages;
CREATE POLICY "chat_messages_insert" ON chat_messages
FOR INSERT WITH CHECK (
  sender_id = auth.uid()
);
