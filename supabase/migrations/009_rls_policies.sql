-- =====================================================
-- Row Level Security (RLS) Policies
-- =====================================================
-- Erstellt: 2026-01-14
-- Beschreibung: Granulare Zugriffskontrolle pro Rolle
-- =====================================================

-- PREREQUISITE: RLS muss auf allen Tabellen aktiviert sein (idempotent)
DO $$
BEGIN
  ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
  ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
  ALTER TABLE products ENABLE ROW LEVEL SECURITY;
  ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
  ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
  ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
  ALTER TABLE tables ENABLE ROW LEVEL SECURITY;
EXCEPTION
  WHEN OTHERS THEN NULL; -- Ignoriere Fehler wenn bereits aktiviert
END $$;

-- =====================================================
-- HELPER FUNCTION: Get user's restaurant
-- =====================================================
CREATE OR REPLACE FUNCTION get_user_restaurant()
RETURNS UUID AS $$
  SELECT restaurant_id 
  FROM employees 
  WHERE id = auth.uid() OR email = auth.jwt() ->> 'email'
  LIMIT 1;
$$ LANGUAGE SQL STABLE;

-- =====================================================
-- RPC FUNCTION: Get Employee Revenue Summary
-- =====================================================
CREATE OR REPLACE FUNCTION get_employee_revenue_summary(p_restaurant_id UUID)
RETURNS TABLE(
  employee_id UUID,
  full_name TEXT,
  email TEXT,
  role TEXT,
  status TEXT,
  total_revenue NUMERIC,
  order_count BIGINT,
  average_order_value NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    e.id,
    (e.first_name || ' ' || e.last_name) as full_name,
    e.email,
    e.role,
    e.status,
    COALESCE(SUM(o.total::numeric), 0) as total_revenue,
    COUNT(o.id) as order_count,
    COALESCE(AVG(o.total::numeric), 0) as average_order_value
  FROM employees e
  LEFT JOIN orders o ON o.employee_id = e.id AND o.status = 'completed'
  WHERE e.restaurant_id = p_restaurant_id
  GROUP BY e.id, e.first_name, e.last_name, e.email, e.role, e.status
  ORDER BY total_revenue DESC;
END;
$$ LANGUAGE plpgsql STABLE;

DROP POLICY IF EXISTS "restaurants_owner_see_own_restaurant" ON restaurants;
CREATE POLICY "restaurants_owner_see_own_restaurant"
  ON restaurants FOR SELECT
  USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "restaurants_owner_update_own" ON restaurants;
CREATE POLICY "restaurants_owner_update_own"
  ON restaurants FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "restaurants_owner_delete_own" ON restaurants;
CREATE POLICY "restaurants_owner_delete_own"
  ON restaurants FOR DELETE
  USING (owner_id = auth.uid());
-- =====================================================
-- EMPLOYEES TABLE - RLS Policies
-- =====================================================

DROP POLICY IF EXISTS "employees_inhaber_see_all" ON employees;
-- INHABER: Sieht alle Mitarbeiter seines Restaurants
CREATE POLICY "employees_inhaber_see_all"
  ON employees FOR SELECT
  USING (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "employees_see_own_data" ON employees;
-- EMPLOYEE: Sieht nur sich selbst
CREATE POLICY "employees_see_own_data"
  ON employees FOR SELECT
  USING (
    email = auth.jwt() ->> 'email' 
    OR id = auth.uid()
  );

DROP POLICY IF EXISTS "employees_inhaber_update" ON employees;
-- INHABER: Kann alle Mitarbeiter seines Restaurants updaten
CREATE POLICY "employees_inhaber_update"
  ON employees FOR UPDATE
  USING (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "employees_inhaber_delete" ON employees;
-- INHABER: Kann Mitarbeiter loeschen (Soft-Delete)
CREATE POLICY "employees_inhaber_delete"
  ON employees FOR DELETE
  USING (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "employees_inhaber_insert" ON employees;
-- INHABER: Kann neue Mitarbeiter erstellen
CREATE POLICY "employees_inhaber_insert"
  ON employees FOR INSERT
  WITH CHECK (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

-- =====================================================
-- PRODUCTS TABLE - RLS Policies
-- =====================================================

DROP POLICY IF EXISTS "products_see_restaurant_products" ON products;
-- Alle Mitarbeiter eines Restaurants sehen Produkte
CREATE POLICY "products_see_restaurant_products"
  ON products FOR SELECT
  USING (
    restaurant_id IN (
      SELECT restaurant_id FROM employees 
      WHERE email = auth.jwt() ->> 'email' OR id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "products_inhaber_manage" ON products;
-- INHABER: Kann Produkte seines Restaurants verwalten
CREATE POLICY "products_inhaber_manage"
  ON products FOR UPDATE
  USING (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "products_inhaber_delete" ON products;
CREATE POLICY "products_inhaber_delete"
  ON products FOR DELETE
  USING (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "products_inhaber_insert" ON products;
-- INHABER: Kann neue Produkte erstellen
CREATE POLICY "products_inhaber_insert"
  ON products FOR INSERT
  WITH CHECK (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
    AND (
      category_id IS NULL
      OR category_id IN (
        SELECT id FROM categories 
        WHERE restaurant_id IN (
          SELECT id FROM restaurants WHERE owner_id = auth.uid()
        )
      )
    )
  );

-- =====================================================
-- CATEGORIES TABLE - RLS Policies
-- =====================================================

DROP POLICY IF EXISTS "categories_see_restaurant_categories" ON categories;
-- Alle sehen Kategorien ihres Restaurants
CREATE POLICY "categories_see_restaurant_categories"
  ON categories FOR SELECT
  USING (
    restaurant_id IN (
      SELECT restaurant_id FROM employees 
      WHERE email = auth.jwt() ->> 'email' OR id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "categories_inhaber_manage" ON categories;
-- INHABER: Kann Kategorien verwalten
CREATE POLICY "categories_inhaber_manage"
  ON categories FOR UPDATE
  USING (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "categories_inhaber_delete" ON categories;
CREATE POLICY "categories_inhaber_delete"
  ON categories FOR DELETE
  USING (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "categories_inhaber_insert" ON categories;
CREATE POLICY "categories_inhaber_insert"
  ON categories FOR INSERT
  WITH CHECK (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

-- =====================================================
-- ORDERS TABLE - RLS Policies
-- =====================================================

DROP POLICY IF EXISTS "orders_service_see_own" ON orders;
-- KELLNER/BARKEEPER: Sieht nur ihre eigenen Bestellungen
CREATE POLICY "orders_service_see_own"
  ON orders FOR SELECT
  USING (
    employee_id = auth.uid() 
    OR employee_id IN (
      SELECT id FROM employees 
      WHERE email = auth.jwt() ->> 'email'
    )
  );

DROP POLICY IF EXISTS "orders_koch_see_all_restaurant" ON orders;
-- KOCH: Sieht alle Orders seines Restaurants
CREATE POLICY "orders_koch_see_all_restaurant"
  ON orders FOR SELECT
  USING (
    restaurant_id IN (
      SELECT restaurant_id FROM employees 
      WHERE (email = auth.jwt() ->> 'email' OR id = auth.uid())
      AND (role = 'Koch' OR role = 'Inhaber' OR role = 'Manager')
    )
  );

DROP POLICY IF EXISTS "orders_inhaber_see_all" ON orders;
-- INHABER: Sieht ALLE Orders
CREATE POLICY "orders_inhaber_see_all"
  ON orders FOR SELECT
  USING (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "orders_koch_update_status" ON orders;
-- KOCH: Kann Order-Status aendern (Offen  In Bearbeitung  Fertig)
CREATE POLICY "orders_koch_update_status"
  ON orders FOR UPDATE
  USING (
    restaurant_id IN (
      SELECT restaurant_id FROM employees 
      WHERE (email = auth.jwt() ->> 'email' OR id = auth.uid())
      AND role = 'Koch'
    )
  )
  WITH CHECK (
    restaurant_id IN (
      SELECT restaurant_id FROM employees 
      WHERE (email = auth.jwt() ->> 'email' OR id = auth.uid())
      AND role = 'Koch'
    )
  );

DROP POLICY IF EXISTS "orders_service_update_own" ON orders;
-- KELLNER/BARKEEPER: Kann eigene Orders aktualisieren
CREATE POLICY "orders_service_update_own"
  ON orders FOR UPDATE
  USING (
    employee_id IN (
      SELECT id FROM employees 
      WHERE email = auth.jwt() ->> 'email' OR id = auth.uid()
    )
  )
  WITH CHECK (
    employee_id IN (
      SELECT id FROM employees 
      WHERE email = auth.jwt() ->> 'email' OR id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "orders_inhaber_update_all" ON orders;
-- INHABER: Kann alle Orders aktualisieren
CREATE POLICY "orders_inhaber_update_all"
  ON orders FOR UPDATE
  USING (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "orders_inhaber_delete" ON orders;
-- INHABER: Kann Orders l�schen (Soft-Delete)
CREATE POLICY "orders_inhaber_delete"
  ON orders FOR DELETE
  USING (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

-- =====================================================
-- ORDER_ITEMS TABLE - RLS Policies
-- =====================================================

DROP POLICY IF EXISTS "order_items_see_own_restaurant" ON order_items;
-- Alle k�nnen Order-Items ihres Restaurants sehen
CREATE POLICY "order_items_see_own_restaurant"
  ON order_items FOR SELECT
  USING (
    order_id IN (
      SELECT id FROM orders 
      WHERE restaurant_id IN (
        SELECT restaurant_id FROM employees 
        WHERE email = auth.jwt() ->> 'email' OR id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "order_items_manage_own_restaurant" ON order_items;
-- Alle k�nnen Order-Items ihres Restaurants manipulieren
CREATE POLICY "order_items_manage_own_restaurant"
  ON order_items FOR UPDATE
  USING (
    order_id IN (
      SELECT id FROM orders 
      WHERE restaurant_id IN (
        SELECT restaurant_id FROM employees 
        WHERE email = auth.jwt() ->> 'email' OR id = auth.uid()
      )
    )
  )
  WITH CHECK (
    order_id IN (
      SELECT id FROM orders 
      WHERE restaurant_id IN (
        SELECT restaurant_id FROM employees 
        WHERE email = auth.jwt() ->> 'email' OR id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "order_items_delete_own_restaurant" ON order_items;
CREATE POLICY "order_items_delete_own_restaurant"
  ON order_items FOR DELETE
  USING (
    order_id IN (
      SELECT id FROM orders 
      WHERE restaurant_id IN (
        SELECT restaurant_id FROM employees 
        WHERE email = auth.jwt() ->> 'email' OR id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "order_items_insert_own_restaurant" ON order_items;
CREATE POLICY "order_items_insert_own_restaurant"
  ON order_items FOR INSERT
  WITH CHECK (
    order_id IN (
      SELECT id FROM orders 
      WHERE restaurant_id IN (
        SELECT restaurant_id FROM employees 
        WHERE email = auth.jwt() ->> 'email' OR id = auth.uid()
      )
    )
  );

-- =====================================================
-- TABLES TABLE - RLS Policies
-- =====================================================

DROP POLICY IF EXISTS "tables_see_restaurant_tables" ON tables;
-- Alle Mitarbeiter sehen Tische ihres Restaurants
CREATE POLICY "tables_see_restaurant_tables"
  ON tables FOR SELECT
  USING (
    restaurant_id IN (
      SELECT restaurant_id FROM employees 
      WHERE email = auth.jwt() ->> 'email' OR id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "tables_inhaber_manage" ON tables;
-- INHABER: Kann Tische verwalten
CREATE POLICY "tables_inhaber_manage"
  ON tables FOR UPDATE
  USING (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "tables_inhaber_delete" ON tables;
CREATE POLICY "tables_inhaber_delete"
  ON tables FOR DELETE
  USING (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "tables_inhaber_insert" ON tables;
CREATE POLICY "tables_inhaber_insert"
  ON tables FOR INSERT
  WITH CHECK (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "tables_service_update_status" ON tables;
-- Alle Mitarbeiter koennen Tischstatus aktualisieren
CREATE POLICY "tables_service_update_status"
  ON tables FOR UPDATE
  USING (
    restaurant_id IN (
      SELECT restaurant_id FROM employees 
      WHERE email = auth.jwt() ->> 'email' OR id = auth.uid()
    )
  )
  WITH CHECK (
    restaurant_id IN (
      SELECT restaurant_id FROM employees 
      WHERE email = auth.jwt() ->> 'email' OR id = auth.uid()
    )
  );

-- =====================================================
-- GRANTS - Oeffentlicher Zugriff auf Tabellen
-- =====================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON restaurants TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON employees TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON products TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON categories TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON orders TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON order_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tables TO authenticated;

-- =====================================================
-- RPC FUNCTION GRANTS
-- =====================================================
GRANT EXECUTE ON FUNCTION get_employee_revenue_summary(UUID) TO authenticated;

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON POLICY "restaurants_owner_see_own_restaurant" ON restaurants 
  IS 'Inhaber sieht nur sein eigenes Restaurant';

COMMENT ON POLICY "employees_inhaber_see_all" ON employees 
  IS 'Inhaber sieht alle Mitarbeiter seines Restaurants';

COMMENT ON POLICY "employees_see_own_data" ON employees 
  IS 'Mitarbeiter sieht nur seine eigenen Daten';

COMMENT ON POLICY "orders_koch_see_all_restaurant" ON orders 
  IS 'Koch sieht alle Bestellungen seines Restaurants (fuer Kueche-Display)';

COMMENT ON POLICY "orders_koch_update_status" ON orders 
  IS 'Koch kann Order-Status aendern (Workflow-Sicherheit)';
