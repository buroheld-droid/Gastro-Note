-- =====================================================
-- Gastro Note POS - Row Level Security (RLS)
-- =====================================================
-- Erstellt: 2026-01-13
-- Beschreibung: RLS Policies (vorerst permissive, 
--               da Login/Auth später implementiert wird)
-- =====================================================

-- RLS für alle Tabellen aktivieren
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE modifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_modifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- WICHTIG: Diese Policies sind sehr permissive!
-- Sobald Auth implementiert ist, müssen diese 
-- angepasst werden, um nur authentifizierten 
-- Mitarbeitern Zugriff zu gewähren.
-- =====================================================

-- Temporäre permissive Policies für Entwicklung (ALLE dürfen ALLES)
-- Diese sollten später durch role-basierte Policies ersetzt werden!

CREATE POLICY "Enable all for anon - roles" ON roles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon - employees" ON employees FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon - categories" ON categories FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon - products" ON products FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon - modifiers" ON modifiers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon - product_modifiers" ON product_modifiers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon - shifts" ON shifts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon - orders" ON orders FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon - order_items" ON order_items FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for anon - payments" ON payments FOR ALL USING (true) WITH CHECK (true);

-- =====================================================
-- TODO: Später zu implementierende auth-basierte Policies
-- =====================================================
-- Beispiel für zukünftige Policies:
-- 
-- CREATE POLICY "Employees can view all employees" ON employees
--   FOR SELECT USING (auth.uid() IN (SELECT id FROM employees WHERE is_active = true));
--
-- CREATE POLICY "Only managers can insert employees" ON employees
--   FOR INSERT WITH CHECK (
--     auth.uid() IN (
--       SELECT e.id FROM employees e 
--       JOIN roles r ON e.role_id = r.id 
--       WHERE r.permissions->>'can_manage_employees' = 'true'
--     )
--   );
-- =====================================================

COMMENT ON POLICY "Enable all for anon - roles" ON roles IS 'TEMPORARY: Remove after implementing auth';
COMMENT ON POLICY "Enable all for anon - employees" ON employees IS 'TEMPORARY: Remove after implementing auth';
COMMENT ON POLICY "Enable all for anon - categories" ON categories IS 'TEMPORARY: Remove after implementing auth';
COMMENT ON POLICY "Enable all for anon - products" ON products IS 'TEMPORARY: Remove after implementing auth';
