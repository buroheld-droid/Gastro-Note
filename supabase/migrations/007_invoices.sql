-- =====================================================
-- Gastro Note POS - Invoices (Teilrechnungen)
-- =====================================================
-- Erstellt: 2026-01-14
-- Beschreibung: Teilrechnungen und Splits aus Orders
-- =====================================================

-- Teilrechnungen (für Splits einer Bestellung)
CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  invoice_number TEXT UNIQUE NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  status TEXT DEFAULT 'open', -- open, completed, cancelled
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Positionen der Teilrechnung (Referenz zu order_items)
CREATE TABLE invoice_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
  order_item_id UUID REFERENCES order_items(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price DECIMAL(10,2) NOT NULL,
  tax_rate DECIMAL(5,2) NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,
  tax_amount DECIMAL(10,2) NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Zahlungen können auf Invoices verlinkt sein (optional)
ALTER TABLE payments ADD COLUMN invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE;

-- Indizes
CREATE INDEX idx_invoices_order ON invoices(order_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);
CREATE INDEX idx_invoice_items_order_item ON invoice_items(order_item_id);
CREATE INDEX idx_payments_invoice ON payments(invoice_id);

-- Trigger für updated_at
CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE invoices IS 'Teilrechnungen bei Splits einer Bestellung';
COMMENT ON TABLE invoice_items IS 'Positionen einer Teilrechnung';
