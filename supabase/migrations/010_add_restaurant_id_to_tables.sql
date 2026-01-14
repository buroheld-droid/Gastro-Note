-- =====================================================
-- Add restaurant_id to multiple tables for multi-tenant support
-- =====================================================
-- Erstellt: 2026-01-14
-- Beschreibung: Ergänzung der restaurant_id Spalte in allen Tabellen für RLS
-- =====================================================

-- ADD restaurant_id TO ORDERS
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_orders_restaurant ON orders(restaurant_id) WHERE restaurant_id IS NOT NULL;
COMMENT ON COLUMN orders.restaurant_id IS 'Zugehöriges Restaurant';

-- ADD restaurant_id TO CATEGORIES
ALTER TABLE categories 
ADD COLUMN IF NOT EXISTS restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_categories_restaurant ON categories(restaurant_id) WHERE restaurant_id IS NOT NULL;
COMMENT ON COLUMN categories.restaurant_id IS 'Zugehöriges Restaurant';

-- ADD restaurant_id TO PRODUCTS (direkt für Performance)
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_products_restaurant ON products(restaurant_id) WHERE restaurant_id IS NOT NULL;
COMMENT ON COLUMN products.restaurant_id IS 'Zugehöriges Restaurant (Denormalisierung für RLS Performance)';

-- ADD restaurant_id TO TABLES
ALTER TABLE tables 
ADD COLUMN IF NOT EXISTS restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_tables_restaurant ON tables(restaurant_id) WHERE restaurant_id IS NOT NULL;
COMMENT ON COLUMN tables.restaurant_id IS 'Zugehöriges Restaurant';

-- ADD restaurant_id TO ORDER_ITEMS (für Konsistenz und Performance)
ALTER TABLE order_items 
ADD COLUMN IF NOT EXISTS restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_order_items_restaurant ON order_items(restaurant_id) WHERE restaurant_id IS NOT NULL;
COMMENT ON COLUMN order_items.restaurant_id IS 'Zugehöriges Restaurant (Denormalisierung)';

-- ADD employee_id TO ORDERS (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name='orders' AND column_name='employee_id'
  ) THEN
    ALTER TABLE orders ADD COLUMN employee_id UUID REFERENCES employees(id) ON DELETE SET NULL;
    CREATE INDEX idx_orders_employee ON orders(employee_id) WHERE employee_id IS NOT NULL;
    COMMENT ON COLUMN orders.employee_id IS 'Mitarbeiter der die Bestellung aufgenommen hat';
  END IF;
END $$;
