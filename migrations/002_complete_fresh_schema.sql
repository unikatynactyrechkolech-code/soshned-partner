-- ═══════════════════════════════════════════════════════════════════════
--  SOS HNED — Kompletní databázové schéma
--  Spustit v Supabase SQL Editor (Settings → SQL Editor)
--  POZOR: Toto smaže a znovu vytvoří tabulky partners a sos_requests!
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Drop starých tabulek (cascade smaže i RLS policies, indexy, triggery)
DROP TABLE IF EXISTS sos_requests CASCADE;
DROP TABLE IF EXISTS partners CASCADE;

-- ═══════════════════════════════════════════════════════════════════════
--  TABULKA: partners
--  Každý partner má 1 účet = 1 pin na mapě = sídlo jeho firmy
--  Pin NENÍ aktuální GPS poloha, je to adresa businessu (sídlo).
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE partners (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  jmeno        TEXT NOT NULL DEFAULT '',
  firma        TEXT,
  telefon      TEXT NOT NULL DEFAULT '',
  email        TEXT NOT NULL DEFAULT '',
  kategorie    TEXT NOT NULL DEFAULT 'servis'
               CHECK (kategorie IN ('zamecnik', 'odtahovka', 'servis', 'instalater', 'elektrikar', 'sklenar', 'nahradni_dily', 'cisteni', 'klimatizace', 'pest_control', 'pneuservis', 'vykup_aut')),
  adresa       TEXT,           -- textová adresa sídla
  lat          DOUBLE PRECISION,  -- GPS sídla firmy
  lng          DOUBLE PRECISION,  -- GPS sídla firmy
  zona         TEXT NOT NULL DEFAULT 'praha',
  hodnoceni    NUMERIC(2,1) NOT NULL DEFAULT 5.0,
  pocet_recenzi INT NOT NULL DEFAULT 0,
  is_online    BOOLEAN NOT NULL DEFAULT false,
  foto_url     TEXT,
  last_seen_at TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index na geolokaci sídla
CREATE INDEX idx_partners_location ON partners (lat, lng) WHERE lat IS NOT NULL AND lng IS NOT NULL;
-- Index na online stav
CREATE INDEX idx_partners_online ON partners (is_online) WHERE is_online = true;
-- Index na kategorii
CREATE INDEX idx_partners_kategorie ON partners (kategorie);
-- Index na user_id
CREATE INDEX idx_partners_user_id ON partners (user_id);

-- ═══════════════════════════════════════════════════════════════════════
--  TABULKA: sos_requests
--  Zákazník vyšle SOS → partner přijme → řeší → dokončí
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE sos_requests (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id   UUID,          -- může být NULL (anonym. zákazník)
  kategorie     TEXT NOT NULL,
  popis         TEXT,
  lat           DOUBLE PRECISION NOT NULL,
  lng           DOUBLE PRECISION NOT NULL,
  adresa        TEXT,
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'accepted', 'in_progress', 'completed', 'cancelled')),
  accepted_by   UUID REFERENCES partners(id),
  accepted_at   TIMESTAMPTZ,
  completed_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sos_status ON sos_requests (status);
CREATE INDEX idx_sos_kategorie ON sos_requests (kategorie);
CREATE INDEX idx_sos_accepted_by ON sos_requests (accepted_by);
CREATE INDEX idx_sos_created ON sos_requests (created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════
--  RLS (Row Level Security)
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE sos_requests ENABLE ROW LEVEL SECURITY;

-- Partners: kdokoliv může číst (klientská appka potřebuje vidět piny)
CREATE POLICY "partners_select_all"
  ON partners FOR SELECT
  USING (true);

-- Partners: přihlášený uživatel může vytvořit svůj vlastní profil
CREATE POLICY "partners_insert_own"
  ON partners FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Partners: přihlášený uživatel může editovat svůj profil
CREATE POLICY "partners_update_own"
  ON partners FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Partners: přihlášený uživatel může smazat svůj profil
CREATE POLICY "partners_delete_own"
  ON partners FOR DELETE
  USING (auth.uid() = user_id);

-- SOS Requests: kdokoliv (i anonym) může vytvořit request
CREATE POLICY "sos_insert_anyone"
  ON sos_requests FOR INSERT
  WITH CHECK (true);

-- SOS Requests: kdokoliv může číst (partner vidí pending, klient vidí svůj)
CREATE POLICY "sos_select_all"
  ON sos_requests FOR SELECT
  USING (true);

-- SOS Requests: přihlášený partner může aktualizovat (přijmout, dokončit)
CREATE POLICY "sos_update_partner"
  ON sos_requests FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- ═══════════════════════════════════════════════════════════════════════
--  REALTIME (Supabase Realtime musí mít tabulky v publication)
-- ═══════════════════════════════════════════════════════════════════════

-- Bezpečné přidání do realtime publication
DO $$
BEGIN
  -- Odstraň staré, pokud existují
  BEGIN
    ALTER PUBLICATION supabase_realtime DROP TABLE partners;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime DROP TABLE sos_requests;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  -- Přidej nové
  ALTER PUBLICATION supabase_realtime ADD TABLE partners;
  ALTER PUBLICATION supabase_realtime ADD TABLE sos_requests;
END $$;

-- ═══════════════════════════════════════════════════════════════════════
--  TRIGGER: automatický update last_seen_at při změně polohy
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_last_seen()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.lat IS DISTINCT FROM OLD.lat OR NEW.lng IS DISTINCT FROM OLD.lng THEN
    NEW.last_seen_at = now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_partners_last_seen
  BEFORE UPDATE ON partners
  FOR EACH ROW
  EXECUTE FUNCTION update_last_seen();

-- ═══════════════════════════════════════════════════════════════════════
--  TESTOVACÍ DATA: 15 fiktivních partnerů (sídla v Praze)
--  Odpovídají SERVICES v klientské webové aplikaci (page.tsx)
--  user_id = NULL (nemají reálné auth účty, jsou jen pro zobrazení)
-- ═══════════════════════════════════════════════════════════════════════

INSERT INTO partners (jmeno, firma, telefon, email, kategorie, adresa, lat, lng, zona, hodnoceni, pocet_recenzi, is_online) VALUES
  -- Zámečníci
  ('Karel Novák',     'Zámky Praha 24/7',     '+420 777 111 001', 'karel@zamkypraha.cz',    'zamecnik',     'Vinohradská 12, Praha 2',           50.0755, 14.4378, 'praha', 4.9, 127, true),
  ('Martin Dvořák',   'SecureKey s.r.o.',      '+420 777 111 002', 'martin@securekey.cz',    'zamecnik',     'Mánesova 45, Praha 2',              50.0812, 14.4289, 'praha', 4.8, 89,  true),

  -- Odtahovky
  ('Josef Procházka', 'AutoHelp Odtah',        '+420 777 222 001', 'josef@autohelp.cz',      'odtahovka',    'Průmyslová 5, Praha 10',            50.0652, 14.4981, 'praha', 4.7, 203, true),
  ('Tomáš Černý',    'Express Tow s.r.o.',     '+420 777 222 002', 'tomas@expresstow.cz',    'odtahovka',    'Kolbenova 8, Praha 9',              50.1058, 14.4955, 'praha', 4.5, 156, true),
  ('Petr Veselý',    'Night Tow Praha',        '+420 777 222 003', 'petr@nighttow.cz',       'odtahovka',    'Na Pankráci 30, Praha 4',           50.0578, 14.4312, 'praha', 4.3, 67,  true),

  -- Servis / Autoservis
  ('Radek Kučera',   'MotoDoc Praha',          '+420 777 333 001', 'radek@motodoc.cz',       'servis',       'Bělohorská 90, Praha 6',            50.0845, 14.3712, 'praha', 4.8, 312, true),
  ('Lukáš Svoboda',  'AutoFix Žižkov',         '+420 777 333 002', 'lukas@autofix.cz',       'servis',       'Koněvova 55, Praha 3',              50.0892, 14.4534, 'praha', 4.6, 178, true),

  -- Instalatéři
  ('David Horák',    'AquaPro Instalatér',     '+420 777 444 001', 'david@aquapro.cz',       'instalater',   'Nuselská 18, Praha 4',              50.0612, 14.4367, 'praha', 4.9, 95,  true),
  ('Jan Marek',      'Water Expert',           '+420 777 444 002', 'jan@waterexpert.cz',     'instalater',   'Slezská 72, Praha 2',               50.0768, 14.4432, 'praha', 4.7, 143, true),

  -- Elektrikáři
  ('Pavel Fiala',    'ElektroBlitz',           '+420 777 555 001', 'pavel@elektroblitz.cz',  'elektrikar',   'Budějovická 3, Praha 4',            50.0442, 14.4498, 'praha', 4.8, 201, true),

  -- Sklenáři
  ('Ondřej Beneš',   'GlassFix Praha',         '+420 777 666 001', 'ondrej@glassfix.cz',     'sklenar',      'Stodůlecká 22, Praha 5',            50.0534, 14.3565, 'praha', 4.6, 88,  true),

  -- Náhradní díly
  ('Michal Pospíšil','AutoParts Express',      '+420 777 777 001', 'michal@autoparts.cz',    'nahradni_dily','Hostivařská 60, Praha 10',          50.0689, 14.5145, 'praha', 4.4, 234, true),

  -- Čištění
  ('Filip Novotný',  'CleanPro CZ',            '+420 777 888 001', 'filip@cleanpro.cz',      'cisteni',      'Letohradská 14, Praha 7',           50.1012, 14.4234, 'praha', 4.7, 112, true),

  -- Klimatizace
  ('Štěpán Růžička', 'AirCool Servis',         '+420 777 999 001', 'stepan@aircool.cz',      'klimatizace',  'Zelený pruh 95, Praha 4',           50.0398, 14.4312, 'praha', 4.5, 76,  true),

  -- Pneuservis
  ('Marek Krejčí',   'PneuSpeed Praha',        '+420 777 000 001', 'marek@pneuspeed.cz',     'pneuservis',   'Řevnická 8, Praha 5',              50.0456, 14.3678, 'praha', 4.9, 289, true);

-- ═══════════════════════════════════════════════════════════════════════
--  HOTOVO! Nyní máte:
--  ✅ Tabulku partners se sídlem firmy (pin na mapě)
--  ✅ Tabulku sos_requests pro SOS výjezdy
--  ✅ RLS policies (public read, auth write)
--  ✅ Realtime pro obě tabulky
--  ✅ Trigger pro last_seen_at
--  ✅ 15 testovacích partnerů s fiktivními firmami v Praze
-- ═══════════════════════════════════════════════════════════════════════
