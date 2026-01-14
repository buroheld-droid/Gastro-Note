-- =====================================================
-- Gastro Note POS - Seed Data
-- =====================================================
-- Erstellt: 2026-01-13
-- Beschreibung: Initiale Test-Daten für Entwicklung
-- =====================================================

-- Standard-Rollen
INSERT INTO roles (id, name, description, permissions) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Manager', 'Vollzugriff auf alle Funktionen', '{"can_manage_employees": true, "can_manage_products": true, "can_view_reports": true, "can_close_shift": true, "can_void_orders": true}'),
  ('22222222-2222-2222-2222-222222222222', 'Service', 'Kann Bestellungen aufnehmen', '{"can_take_orders": true, "can_view_products": true}'),
  ('33333333-3333-3333-3333-333333333333', 'Küche', 'Kann Bestellungen einsehen', '{"can_view_orders": true}');

-- Test-Mitarbeiter
INSERT INTO employees (id, employee_number, first_name, last_name, email, pin_code, role_id, is_active) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'M001', 'Max', 'Mustermann', 'max@gastro.de', '1234', '11111111-1111-1111-1111-111111111111', true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'M002', 'Anna', 'Schmidt', 'anna@gastro.de', '5678', '22222222-2222-2222-2222-222222222222', true),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'M003', 'Tom', 'Weber', 'tom@gastro.de', '9999', '33333333-3333-3333-3333-333333333333', true);

-- Kategorien
INSERT INTO categories (id, name, description, color, sort_order, is_active) VALUES
  ('c1111111-1111-1111-1111-111111111111', 'Getränke', 'Alkoholfreie und alkoholische Getränke', '#0EA5E9', 1, true),
  ('c2222222-2222-2222-2222-222222222222', 'Speisen', 'Hauptgerichte und Beilagen', '#22C55E', 2, true),
  ('c3333333-3333-3333-3333-333333333333', 'Desserts', 'Süßspeisen und Nachspeisen', '#F59E0B', 3, true),
  ('c4444444-4444-4444-4444-444444444444', 'Snacks', 'Kleine Speisen und Snacks', '#8B5CF6', 4, true);

-- Produkte
INSERT INTO products (id, name, description, sku, category_id, price, tax_rate, is_active, sort_order) VALUES
  -- Getränke
  ('a1000001-0000-0000-0000-000000000001', 'Cola 0,33l', 'Coca Cola', 'DRK001', 'c1111111-1111-1111-1111-111111111111', 3.50, 19.00, true, 1),
  ('a1000002-0000-0000-0000-000000000002', 'Wasser 0,25l', 'Mineralwasser', 'DRK002', 'c1111111-1111-1111-1111-111111111111', 2.50, 19.00, true, 2),
  ('a1000003-0000-0000-0000-000000000003', 'Bier 0,5l', 'Pils vom Fass', 'DRK003', 'c1111111-1111-1111-1111-111111111111', 4.20, 19.00, true, 3),
  ('a1000004-0000-0000-0000-000000000004', 'Kaffee', 'Tasse Kaffee', 'DRK004', 'c1111111-1111-1111-1111-111111111111', 2.80, 19.00, true, 4),
  
  -- Speisen
  ('a2000001-0000-0000-0000-000000000001', 'Schnitzel', 'Wiener Schnitzel mit Pommes', 'SPE001', 'c2222222-2222-2222-2222-222222222222', 14.90, 19.00, true, 1),
  ('a2000002-0000-0000-0000-000000000002', 'Pizza Margherita', 'Klassische Pizza mit Tomate und Käse', 'SPE002', 'c2222222-2222-2222-2222-222222222222', 8.50, 7.00, true, 2),
  ('a2000003-0000-0000-0000-000000000003', 'Burger', 'Rindfleisch-Burger mit Pommes', 'SPE003', 'c2222222-2222-2222-2222-222222222222', 11.90, 19.00, true, 3),
  ('a2000004-0000-0000-0000-000000000004', 'Salat', 'Gemischter Salat', 'SPE004', 'c2222222-2222-2222-2222-222222222222', 7.50, 7.00, true, 4),
  
  -- Desserts
  ('a3000001-0000-0000-0000-000000000001', 'Tiramisu', 'Hausgemachtes Tiramisu', 'DES001', 'c3333333-3333-3333-3333-333333333333', 5.90, 7.00, true, 1),
  ('a3000002-0000-0000-0000-000000000002', 'Eis', '3 Kugeln Eis', 'DES002', 'c3333333-3333-3333-3333-333333333333', 4.50, 7.00, true, 2),
  
  -- Snacks
  ('a4000001-0000-0000-0000-000000000001', 'Pommes', 'Portion Pommes', 'SNK001', 'c4444444-4444-4444-4444-444444444444', 3.90, 19.00, true, 1),
  ('a4000002-0000-0000-0000-000000000002', 'Chicken Wings', '6 Stück Chicken Wings', 'SNK002', 'c4444444-4444-4444-4444-444444444444', 6.90, 19.00, true, 2);

-- Modifikatoren
INSERT INTO modifiers (id, name, price_adjustment, sort_order, is_active) VALUES
  ('a0000001-0000-0000-0000-000000000001', 'Extra Käse', 1.50, 1, true),
  ('a0000002-0000-0000-0000-000000000002', 'Ohne Zwiebeln', 0.00, 2, true),
  ('a0000003-0000-0000-0000-000000000003', 'Scharf', 0.00, 3, true),
  ('a0000004-0000-0000-0000-000000000004', 'Extra Sauce', 0.80, 4, true),
  ('a0000005-0000-0000-0000-000000000005', 'Mit Bacon', 2.00, 5, true);

-- Verknüpfung Produkte <-> Modifikatoren (Beispiele)
INSERT INTO product_modifiers (product_id, modifier_id, is_default) VALUES
  -- Pizza kann Extra Käse und Scharf haben
  ('a2000002-0000-0000-0000-000000000002', 'a0000001-0000-0000-0000-000000000001', false),
  ('a2000002-0000-0000-0000-000000000002', 'a0000003-0000-0000-0000-000000000003', false),
  
  -- Burger kann alle Modifikatoren haben
  ('a2000003-0000-0000-0000-000000000003', 'a0000002-0000-0000-0000-000000000002', false),
  ('a2000003-0000-0000-0000-000000000003', 'a0000003-0000-0000-0000-000000000003', false),
  ('a2000003-0000-0000-0000-000000000003', 'a0000004-0000-0000-0000-000000000004', false),
  ('a2000003-0000-0000-0000-000000000003', 'a0000005-0000-0000-0000-000000000005', false);

-- Test-Schicht
INSERT INTO shifts (id, shift_number, employee_id, started_at, starting_cash) VALUES
  ('b0000001-0000-0000-0000-000000000001', 'S-2026-001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now(), 100.00);

COMMENT ON TABLE roles IS 'Initiale Seed-Daten wurden eingefügt';
