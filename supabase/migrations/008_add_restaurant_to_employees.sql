-- =====================================================
-- Add restaurant_id to employees table
-- =====================================================
-- Erstellt: 2026-01-14
-- Beschreibung: Verknüpfung Mitarbeiter mit Restaurants
-- =====================================================

-- Falls restaurants-Tabelle noch nicht existiert (für Multi-Tenant)
CREATE TABLE IF NOT EXISTS restaurants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL, -- Bezug zu auth.users
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  email TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Alter employees: add restaurant_id
ALTER TABLE employees 
ADD COLUMN IF NOT EXISTS restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
ALTER TABLE employees 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active'; -- 'active', 'inactive', 'on_leave'

-- Index für Performance
CREATE INDEX IF NOT EXISTS idx_employees_restaurant ON employees(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_employees_status ON employees(status);
CREATE INDEX IF NOT EXISTS idx_restaurants_owner ON restaurants(owner_id);

-- Update roles table mit Standard-Rollen (granulare Permissions)
INSERT INTO roles (name, description, permissions) VALUES
  ('Inhaber', 'Admin mit Vollzugriff inkl. Reports', '{
    "employees": true,
    "roles": true,
    "pos": true,
    "orders": true,
    "kitchen": true,
    "reports": true,
    "revenue": true,
    "cash": true,
    "settings": true
  }'::jsonb),
  ('Kellner', 'Service & Verkauf', '{
    "pos": true,
    "orders": true,
    "tips": true
  }'::jsonb),
  ('Barkeeper', 'Getränke & Verkauf (gleiche Rechte wie Kellner)', '{
    "pos": true,
    "orders": true,
    "tips": true
  }'::jsonb),
  ('Koch', 'Küchenbetrieb - nur Bestellungen sehen & Status aktualisieren', '{
    "kitchen": true,
    "orders_view": true
  }'::jsonb)
ON CONFLICT (name) DO NOTHING;

COMMENT ON TABLE restaurants IS 'Restaurants/Locations';
COMMENT ON TABLE employees IS 'Mitarbeiter pro Restaurant';
COMMENT ON COLUMN employees.restaurant_id IS 'Zugehöriges Restaurant';
COMMENT ON COLUMN employees.status IS 'Status: active, inactive, on_leave';
