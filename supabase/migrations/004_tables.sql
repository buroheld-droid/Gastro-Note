-- =====================================================
-- Gastro Note POS - Tables Management
-- =====================================================
-- Erstellt: 2026-01-13
-- Beschreibung: Tischverwaltung mit Bereichen und Status
-- =====================================================

-- Tische
CREATE TABLE tables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_number TEXT NOT NULL UNIQUE,
  area TEXT NOT NULL, -- 'indoor', 'outdoor', 'bar'
  capacity INTEGER NOT NULL DEFAULT 2,
  status TEXT DEFAULT 'available', -- 'available', 'occupied', 'reserved'
  current_order_id UUID, -- Aktuell offene Bestellung
  is_active BOOLEAN DEFAULT true,
  notes TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Index für Performance
CREATE INDEX idx_tables_area ON tables(area);
CREATE INDEX idx_tables_status ON tables(status);
CREATE INDEX idx_tables_active ON tables(is_active) WHERE deleted_at IS NULL;

-- Trigger für updated_at
CREATE TRIGGER update_tables_updated_at BEFORE UPDATE ON tables
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Verknüpfung orders.table_number zu tables.id anpassen
-- ACHTUNG: Falls orders bereits Daten hat, diese vorher migrieren!
ALTER TABLE orders DROP COLUMN IF EXISTS table_number;
ALTER TABLE orders ADD COLUMN table_id UUID REFERENCES tables(id) ON DELETE SET NULL;
CREATE INDEX idx_orders_table ON orders(table_id);

COMMENT ON TABLE tables IS 'Tische mit Bereichen und Status';
COMMENT ON COLUMN tables.area IS 'Bereich: indoor, outdoor, bar';
COMMENT ON COLUMN tables.status IS 'Status: available, occupied, reserved';
