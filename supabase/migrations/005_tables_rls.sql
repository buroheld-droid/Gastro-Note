-- =====================================================
-- Gastro Note POS - Tables RLS Policies
-- =====================================================
-- Erstellt: 2026-01-13
-- Beschreibung: RLS für Tische (permissive für Entwicklung)
-- =====================================================

ALTER TABLE tables ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable all for anon - tables" ON tables FOR ALL USING (true) WITH CHECK (true);

COMMENT ON POLICY "Enable all for anon - tables" ON tables IS 'TEMPORARY: Remove after implementing auth';
