-- ═══════════════════════════════════════════════════════════════════════
-- FIX: RLS policy pro UPDATE na partners (aby šlo upravit profil)
-- Spustit v Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════

-- Zkontroluj existující policies
-- SELECT * FROM pg_policies WHERE tablename = 'partners';

-- Přidej UPDATE policy — partner může upravit pouze svůj vlastní profil
DO $$
BEGIN
  -- Smaž pokud existuje
  BEGIN
    DROP POLICY IF EXISTS "partners_update_own" ON partners;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  
  -- Vytvoř novou
  CREATE POLICY "partners_update_own"
    ON partners FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
END $$;

-- Ověř že SELECT policy existuje
DO $$
BEGIN
  BEGIN
    DROP POLICY IF EXISTS "partners_select_all" ON partners;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  
  CREATE POLICY "partners_select_all"
    ON partners FOR SELECT
    USING (true);
END $$;

-- Ověř že INSERT policy existuje
DO $$
BEGIN
  BEGIN
    DROP POLICY IF EXISTS "partners_insert_auth" ON partners;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  
  CREATE POLICY "partners_insert_auth"
    ON partners FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);
END $$;

-- Zapni RLS pokud ještě není
ALTER TABLE partners ENABLE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════════
-- Ověř messages tabulku a realtime
-- ═══════════════════════════════════════════════════════════════════════

-- Ověř že messages tabulka existuje
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name = 'messages'
);

-- Ověř realtime na messages
-- SELECT * FROM pg_publication_tables WHERE tablename = 'messages';

-- ═══════════════════════════════════════════════════════════════════════
--  HOTOVO! Spustit tenhle SQL v Supabase Dashboard → SQL Editor
-- ═══════════════════════════════════════════════════════════════════════
