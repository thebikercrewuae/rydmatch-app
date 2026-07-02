-- Make in-app matched-rider messaging observable and notify recipients.
-- This is intentionally self-contained because some production databases
-- predate the original delivery-status migration.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public' AND t.typname = 'message_status'
  ) THEN
    CREATE TYPE public.message_status AS ENUM (
      'sending', 'sent', 'delivered', 'read', 'failed'
    );
  END IF;
END
$$;

ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS delivery_status public.message_status NOT NULL DEFAULT 'sent',
  ADD COLUMN IF NOT EXISTS status_updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_messages_participants_select" ON public.chat_messages;
CREATE POLICY "chat_messages_participants_select"
ON public.chat_messages
FOR SELECT
TO authenticated
USING (sender_id = auth.uid() OR recipient_id = auth.uid());

DROP POLICY IF EXISTS "chat_messages_sender_insert" ON public.chat_messages;
CREATE POLICY "chat_messages_sender_insert"
ON public.chat_messages
FOR INSERT
TO authenticated
WITH CHECK (
  sender_id = auth.uid()
  AND recipient_id <> auth.uid()
);

DROP POLICY IF EXISTS "chat_messages_participants_update" ON public.chat_messages;
CREATE POLICY "chat_messages_participants_update"
ON public.chat_messages
FOR UPDATE
TO authenticated
USING (sender_id = auth.uid() OR recipient_id = auth.uid())
WITH CHECK (sender_id = auth.uid() OR recipient_id = auth.uid());

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
  END IF;
END
$$;
CREATE OR REPLACE FUNCTION public.update_chat_message_status_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.delivery_status IS DISTINCT FROM OLD.delivery_status THEN
    NEW.status_updated_at := CURRENT_TIMESTAMP;
    IF NEW.delivery_status = 'delivered' AND NEW.delivered_at IS NULL THEN
      NEW.delivered_at := CURRENT_TIMESTAMP;
    ELSIF NEW.delivery_status = 'read' THEN
      NEW.delivered_at := COALESCE(NEW.delivered_at, CURRENT_TIMESTAMP);
      NEW.read_at := COALESCE(NEW.read_at, CURRENT_TIMESTAMP);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS chat_messages_status_timestamp ON public.chat_messages;
CREATE TRIGGER chat_messages_status_timestamp
BEFORE UPDATE OF delivery_status ON public.chat_messages
FOR EACH ROW
EXECUTE FUNCTION public.update_chat_message_status_timestamp();

CREATE OR REPLACE FUNCTION public.notify_chat_message_recipient()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  sender_name TEXT;
  message_preview TEXT;
BEGIN
  SELECT COALESCE(NULLIF(TRIM(up.full_name), ''), 'A matched rider')
  INTO sender_name
  FROM public.user_profiles up
  WHERE up.id = NEW.sender_id;

  message_preview := LEFT(COALESCE(NEW.message_body, 'New message'), 160);

  INSERT INTO public.notifications (
    user_id, notification_type, title, message, reference_id,
    action_route, action_arguments
  ) VALUES (
    NEW.recipient_id, 'new_message',
    COALESCE(sender_name, 'A matched rider'), message_preview,
    NEW.sender_id, '/chat-screen',
    jsonb_build_object(
      'otherUserId', NEW.sender_id,
      'otherUserName', COALESCE(sender_name, 'Rider')
    )
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS chat_messages_notify_recipient ON public.chat_messages;
CREATE TRIGGER chat_messages_notify_recipient
AFTER INSERT ON public.chat_messages
FOR EACH ROW
EXECUTE FUNCTION public.notify_chat_message_recipient();

CREATE INDEX IF NOT EXISTS idx_chat_messages_recipient_unread
  ON public.chat_messages(recipient_id, read_at, created_at DESC);

NOTIFY pgrst, 'reload schema';