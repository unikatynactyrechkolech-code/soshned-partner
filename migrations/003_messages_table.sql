-- ═══════════════════════════════════════════════════════════════════════
--  SOS HNED — Tabulka zpráv (chat mezi zákazníkem a partnerem)
--  Spustit v Supabase SQL Editor PO 002_complete_fresh_schema.sql
-- ═══════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS messages CASCADE;

CREATE TABLE messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sos_request_id  UUID NOT NULL REFERENCES sos_requests(id) ON DELETE CASCADE,
  sender_type     TEXT NOT NULL CHECK (sender_type IN ('customer', 'partner')),
  sender_id       UUID,          -- partner ID nebo NULL pro anonymního zákazníka
  text            TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_messages_request ON messages (sos_request_id, created_at);
CREATE INDEX idx_messages_created ON messages (created_at DESC);

-- RLS
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Kdokoliv může číst zprávy (zákazník i partner)
CREATE POLICY "messages_select_all"
  ON messages FOR SELECT
  USING (true);

-- Kdokoliv může vkládat zprávy (zákazník je anonym, partner je přihlášen)
CREATE POLICY "messages_insert_anyone"
  ON messages FOR INSERT
  WITH CHECK (true);

-- Realtime
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime DROP TABLE messages;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  ALTER PUBLICATION supabase_realtime ADD TABLE messages;
END $$;

-- ═══════════════════════════════════════════════════════════════════════
--  HOTOVO! Tabulka messages pro chat je připravena.
--  ✅ Vazba na sos_requests přes sos_request_id
--  ✅ sender_type: 'customer' nebo 'partner'
--  ✅ RLS: public read + public insert
--  ✅ Realtime pro live chat
-- ═══════════════════════════════════════════════════════════════════════
