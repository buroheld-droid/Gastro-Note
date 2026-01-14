-- =====================================================
-- Gastro Note POS - Initial Schema Migration
-- =====================================================
-- Erstellt: 2026-01-13
-- Beschreibung: Basis-Tabellen für Kassensystem
-- =====================================================

-- Rollen für Mitarbeiter
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  permissions JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Mitarbeiter
CREATE TABLE employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_number TEXT UNIQUE NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT UNIQUE,
  phone TEXT,
  pin_code TEXT, -- 4-6 stelliger PIN für Login später
  role_id UUID REFERENCES roles(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ -- Soft Delete
);

-- Kategorien für Produkte
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  color TEXT, -- Hex-Farbe für UI (z.B. '#22C55E')
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Produkte
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  sku TEXT UNIQUE, -- Artikelnummer
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  price DECIMAL(10,2) NOT NULL,
  cost_price DECIMAL(10,2), -- Einkaufspreis (optional)
  tax_rate DECIMAL(5,2) DEFAULT 19.00, -- MwSt in %
  unit TEXT DEFAULT 'Stück', -- Einheit (Stück, kg, l, etc.)
  stock_quantity INTEGER DEFAULT 0,
  track_stock BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  image_url TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Modifikatoren/Extras (z.B. "Extra Käse", "Ohne Zwiebeln")
CREATE TABLE modifiers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  price_adjustment DECIMAL(10,2) DEFAULT 0.00, -- Aufpreis
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Verknüpfung Produkte <-> Modifikatoren
CREATE TABLE product_modifiers (
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  modifier_id UUID REFERENCES modifiers(id) ON DELETE CASCADE,
  is_default BOOLEAN DEFAULT false,
  PRIMARY KEY (product_id, modifier_id)
);

-- Schichten (für Kassenabschluss)
CREATE TABLE shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shift_number TEXT UNIQUE NOT NULL,
  employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ,
  starting_cash DECIMAL(10,2) DEFAULT 0.00, -- Startkasse
  expected_cash DECIMAL(10,2), -- Erwarteter Bargeld-Bestand
  actual_cash DECIMAL(10,2), -- Tatsächlicher Bargeld-Bestand
  cash_difference DECIMAL(10,2), -- Differenz
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Bestellungen
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number TEXT UNIQUE NOT NULL,
  employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
  shift_id UUID REFERENCES shifts(id) ON DELETE SET NULL,
  table_number TEXT, -- Tischnummer (optional, für Restaurant-Modus)
  customer_name TEXT,
  order_type TEXT DEFAULT 'dine_in', -- dine_in, takeaway, delivery
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  discount_amount DECIMAL(10,2) DEFAULT 0.00,
  total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  status TEXT DEFAULT 'open', -- open, completed, cancelled
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ
);

-- Bestellpositionen
CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL, -- Snapshot des Produktnamens
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price DECIMAL(10,2) NOT NULL,
  tax_rate DECIMAL(5,2) NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,
  tax_amount DECIMAL(10,2) NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  modifiers JSONB DEFAULT '[]', -- Array von {id, name, price}
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Zahlungen
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  payment_method TEXT NOT NULL, -- cash, card, other
  amount DECIMAL(10,2) NOT NULL,
  received_amount DECIMAL(10,2), -- Erhaltener Betrag (bei Bargeld)
  change_amount DECIMAL(10,2), -- Rückgeld
  reference TEXT, -- Transaktions-Referenz (bei Kartenzahlung)
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indizes für Performance
CREATE INDEX idx_employees_role ON employees(role_id);
CREATE INDEX idx_employees_active ON employees(is_active) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_active ON products(is_active) WHERE deleted_at IS NULL;
CREATE INDEX idx_orders_employee ON orders(employee_id);
CREATE INDEX idx_orders_shift ON orders(shift_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created ON orders(created_at DESC);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_shifts_employee ON shifts(employee_id);

-- Trigger für updated_at Timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_roles_updated_at BEFORE UPDATE ON roles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON employees
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_modifiers_updated_at BEFORE UPDATE ON modifiers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_shifts_updated_at BEFORE UPDATE ON shifts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Kommentare für Dokumentation
COMMENT ON TABLE roles IS 'Mitarbeiter-Rollen mit Berechtigungen';
COMMENT ON TABLE employees IS 'Mitarbeiter des Restaurants';
COMMENT ON TABLE categories IS 'Produktkategorien';
COMMENT ON TABLE products IS 'Produkte/Artikel';
COMMENT ON TABLE modifiers IS 'Modifikatoren/Extras für Produkte';
COMMENT ON TABLE shifts IS 'Kassenschichten';
COMMENT ON TABLE orders IS 'Bestellungen';
COMMENT ON TABLE order_items IS 'Bestellpositionen';
COMMENT ON TABLE payments IS 'Zahlungen';
