-- ═══════════════════════════════════════════════════════════════════════
--  SOS HNED — KOMPLETNÍ DATABÁZOVÉ SCHÉMA
--  Spusť v Supabase SQL Editor: https://ysyvbjzpoxpttoofjwfc.supabase.co
--  Datum: 2026-03-28
-- ═══════════════════════════════════════════════════════════════════════

-- =====================================================================
--  1) TABULKA: partners
--     Partneři (živnostníci) — špendlíky na mapě
--     Každý partner = 1 špendlík (lat, lng)
-- =====================================================================

CREATE TABLE IF NOT EXISTS partners (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  jmeno         TEXT NOT NULL,
  firma         TEXT,
  telefon       TEXT NOT NULL,
  email         TEXT NOT NULL,
  kategorie     TEXT NOT NULL CHECK (kategorie IN ('zamecnik','odtahovka','servis','instalater')),
  adresa        TEXT,
  lat           DOUBLE PRECISION,
  lng           DOUBLE PRECISION,
  zona          TEXT DEFAULT 'praha',
  hodnoceni     NUMERIC(2,1) DEFAULT 5.0,
  pocet_recenzi INT DEFAULT 0,
  is_online     BOOLEAN DEFAULT false,
  foto_url      TEXT,
  last_seen_at  TIMESTAMPTZ DEFAULT now(),
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- Pokud tabulka už existuje ale chybí last_seen_at:
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'partners' AND column_name = 'last_seen_at'
  ) THEN
    ALTER TABLE partners ADD COLUMN last_seen_at TIMESTAMPTZ DEFAULT now();
  END IF;
END $$;

COMMENT ON TABLE partners IS 'Partneři/živnostníci — každý má max 1 špendlík na mapě';
COMMENT ON COLUMN partners.lat IS 'Zeměpisná šířka špendlíku partnera';
COMMENT ON COLUMN partners.lng IS 'Zeměpisná délka špendlíku partnera';
COMMENT ON COLUMN partners.is_online IS 'Zda je partner online a přijímá požadavky';
COMMENT ON COLUMN partners.last_seen_at IS 'Poslední update polohy nebo online stavu';
COMMENT ON COLUMN partners.user_id IS 'FK na auth.users — UNIQUE = 1 user = 1 partner = 1 špendlík';

-- =====================================================================
--  2) TABULKA: sos_requests
--     SOS požadavky od zákazníků
-- =====================================================================

CREATE TABLE IF NOT EXISTS sos_requests (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id   UUID,
  kategorie     TEXT NOT NULL CHECK (kategorie IN ('zamecnik','odtahovka','servis','instalater')),
  popis         TEXT,
  lat           DOUBLE PRECISION NOT NULL,
  lng           DOUBLE PRECISION NOT NULL,
  adresa        TEXT,
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','accepted','in_progress','completed','cancelled')),
  accepted_by   UUID REFERENCES partners(id),
  accepted_at   TIMESTAMPTZ,
  completed_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE sos_requests IS 'SOS požadavky zákazníků — partneři je přijímají z dashboardu';

-- =====================================================================
--  3) INDEXY — rychlé dotazy
-- =====================================================================

-- Partners: online s polohou (hlavní dotaz pro mapu)
CREATE INDEX IF NOT EXISTS idx_partners_online_location
  ON partners (is_online, lat, lng)
  WHERE is_online = true AND lat IS NOT NULL AND lng IS NOT NULL;

-- Partners: podle user_id (login lookup)
CREATE INDEX IF NOT EXISTS idx_partners_user_id
  ON partners (user_id);

-- Partners: last_seen (pro aktivitu)
CREATE INDEX IF NOT EXISTS idx_partners_last_seen
  ON partners (last_seen_at DESC);

-- Partners: podle kategorie
CREATE INDEX IF NOT EXISTS idx_partners_kategorie
  ON partners (kategorie);

-- SOS: pending podle kategorie (dashboard dotaz)
CREATE INDEX IF NOT EXISTS idx_sos_pending_kategorie
  ON sos_requests (kategorie, status)
  WHERE status = 'pending';

-- SOS: accepted_by (moje výjezdy)
CREATE INDEX IF NOT EXISTS idx_sos_accepted_by
  ON sos_requests (accepted_by, status);

-- SOS: created_at (řazení)
CREATE INDEX IF NOT EXISTS idx_sos_created_at
  ON sos_requests (created_at DESC);

-- =====================================================================
--  4) ROW LEVEL SECURITY (RLS)
--     Musí být zapnuto aby Supabase anon key fungovaly bezpečně
-- =====================================================================

-- Zapni RLS na obou tabulkách
ALTER TABLE partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE sos_requests ENABLE ROW LEVEL SECURITY;

-- ── PARTNERS policies ───────────────────────────────────────────────

-- Kdokoliv může ČÍST partnery (zákazníci vidí špendlíky na mapě)
DROP POLICY IF EXISTS "Partners: public read" ON partners;
CREATE POLICY "Partners: public read"
  ON partners FOR SELECT
  USING (true);

-- Přihlášený user může INSERT svůj profil (registrace)
DROP POLICY IF EXISTS "Partners: authenticated insert own" ON partners;
CREATE POLICY "Partners: authenticated insert own"
  ON partners FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Přihlášený user může UPDATE svůj profil (poloha, online stav, atd.)
DROP POLICY IF EXISTS "Partners: authenticated update own" ON partners;
CREATE POLICY "Partners: authenticated update own"
  ON partners FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── SOS_REQUESTS policies ───────────────────────────────────────────

-- Kdokoliv může ČÍST SOS requesty (partneri vidí pending na dashboardu)
DROP POLICY IF EXISTS "SOS: public read" ON sos_requests;
CREATE POLICY "SOS: public read"
  ON sos_requests FOR SELECT
  USING (true);

-- Kdokoliv může INSERT SOS request (zákazníci nejsou přihlášení)
DROP POLICY IF EXISTS "SOS: anyone can insert" ON sos_requests;
CREATE POLICY "SOS: anyone can insert"
  ON sos_requests FOR INSERT
  WITH CHECK (true);

-- Přihlášený partner může UPDATE SOS request (přijmout, dokončit)
DROP POLICY IF EXISTS "SOS: authenticated update" ON sos_requests;
CREATE POLICY "SOS: authenticated update"
  ON sos_requests FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- =====================================================================
--  5) REALTIME — zapni pro obě tabulky
--     Potřebné pro live notifikace nových SOS a změn partnerů
-- =====================================================================

-- Supabase: přidej tabulky do realtime publication
-- (Toto funguje jen pokud ještě nejsou přidané)
DO $$
BEGIN
  -- Partners realtime
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'partners'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE partners;
  END IF;

  -- SOS requests realtime
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'sos_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE sos_requests;
  END IF;
END $$;

-- =====================================================================
--  6) HELPER FUNKCE
-- =====================================================================

-- Funkce pro auto-update last_seen_at při změně lat/lng nebo is_online
CREATE OR REPLACE FUNCTION update_partner_last_seen()
RETURNS TRIGGER AS $$
BEGIN
  IF (OLD.lat IS DISTINCT FROM NEW.lat)
     OR (OLD.lng IS DISTINCT FROM NEW.lng)
     OR (OLD.is_online IS DISTINCT FROM NEW.is_online) THEN
    NEW.last_seen_at := now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
DROP TRIGGER IF EXISTS trg_partner_last_seen ON partners;
CREATE TRIGGER trg_partner_last_seen
  BEFORE UPDATE ON partners
  FOR EACH ROW
  EXECUTE FUNCTION update_partner_last_seen();

-- =====================================================================
--  7) VERIFIKACE — zkontroluj po spuštění
-- =====================================================================

-- Spusť toto pro ověření:
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'partners' ORDER BY ordinal_position;
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sos_requests' ORDER BY ordinal_position;
-- SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
-- SELECT policyname, cmd FROM pg_policies WHERE tablename IN ('partners', 'sos_requests');
