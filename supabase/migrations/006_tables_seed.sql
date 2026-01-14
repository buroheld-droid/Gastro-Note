-- =====================================================
-- Gastro Note POS - Tables Seed Data
-- =====================================================
-- Erstellt: 2026-01-13
-- Beschreibung: Beispiel-Tische für verschiedene Bereiche
-- =====================================================

-- Tische Innenbereich
INSERT INTO tables (id, table_number, area, capacity, status, sort_order, is_active) VALUES
  ('11111111-aaaa-0000-0000-000000000001', 'T1', 'indoor', 2, 'available', 1, true),
  ('11111111-aaaa-0000-0000-000000000002', 'T2', 'indoor', 4, 'available', 2, true),
  ('11111111-aaaa-0000-0000-000000000003', 'T3', 'indoor', 4, 'available', 3, true),
  ('11111111-aaaa-0000-0000-000000000004', 'T4', 'indoor', 6, 'available', 4, true),
  ('11111111-aaaa-0000-0000-000000000005', 'T5', 'indoor', 2, 'available', 5, true),

  -- Tische Außenbereich
  ('22222222-aaaa-0000-0000-000000000001', 'T10', 'outdoor', 4, 'available', 10, true),
  ('22222222-aaaa-0000-0000-000000000002', 'T11', 'outdoor', 4, 'available', 11, true),
  ('22222222-aaaa-0000-0000-000000000003', 'T12', 'outdoor', 6, 'available', 12, true),
  ('22222222-aaaa-0000-0000-000000000004', 'T13', 'outdoor', 2, 'available', 13, true),

  -- Bar-Plätze
  ('33333333-aaaa-0000-0000-000000000001', 'B1', 'bar', 1, 'available', 20, true),
  ('33333333-aaaa-0000-0000-000000000002', 'B2', 'bar', 1, 'available', 21, true),
  ('33333333-aaaa-0000-0000-000000000003', 'B3', 'bar', 1, 'available', 22, true),
  ('33333333-aaaa-0000-0000-000000000004', 'B4', 'bar', 1, 'available', 23, true),
  ('33333333-aaaa-0000-0000-000000000005', 'B5', 'bar', 1, 'available', 24, true);

COMMENT ON TABLE tables IS 'Seed-Daten für Tische eingefügt';
