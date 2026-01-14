-- =====================================================
-- RLS Testing Script
-- =====================================================
-- Testet RLS-Policies für verschiedene Rollen (Inhaber, Kellner, Koch)

-- 1. Test-Daten vorbereiten
INSERT INTO restaurants (id, owner_id, name)
VALUES ('00000000-0000-0000-0000-000000000001'::uuid, '10000000-0000-0000-0000-000000000001'::uuid, 
        'Test Restaurant');

-- Inhaber
INSERT INTO employees (id, restaurant_id, email, first_name, last_name, employee_number, role, status)
VALUES ('10000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-000000000001'::uuid,
        'inhaber@test.de', 'Max', 'Inhaber', 'EMP001', 'Inhaber', 'active');

-- Kellner
INSERT INTO employees (id, restaurant_id, email, first_name, last_name, employee_number, role, status)
VALUES ('20000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-000000000001'::uuid,
        'kellner@test.de', 'Anna', 'Kellner', 'EMP002', 'Kellner', 'active');

-- Koch
INSERT INTO employees (id, restaurant_id, email, first_name, last_name, employee_number, role, status)
VALUES ('30000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-000000000001'::uuid,
        'koch@test.de', 'Peter', 'Koch', 'EMP003', 'Koch', 'active');

-- Test-Daten: Kategorie und Produkt
INSERT INTO categories (id, restaurant_id, name)
VALUES ('40000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-000000000001'::uuid, 'Getränke');

INSERT INTO products (id, restaurant_id, category_id, name, price)
VALUES ('50000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-000000000001'::uuid,
        '40000000-0000-0000-0000-000000000001'::uuid, 'Bier', 4.50);

-- =====================================================
-- TEST 1: Inhaber sieht sein Restaurant
-- =====================================================
-- Set auth context for Inhaber
SET LOCAL jwt.claims = '{"sub": "10000000-0000-0000-0000-000000000001", "email": "inhaber@test.de"}';

SELECT 'TEST 1: Inhaber sieht sein Restaurant' as test;
SELECT id, name FROM restaurants;
-- Expected: 1 row (sein Restaurant)

-- =====================================================
-- TEST 2: Inhaber sieht alle seine Mitarbeiter
-- =====================================================
SELECT 'TEST 2: Inhaber sieht alle seine Mitarbeiter' as test;
SELECT id, first_name, last_name, role FROM employees;
-- Expected: 3 rows (Inhaber, Kellner, Koch)

-- =====================================================
-- TEST 3: Inhaber sieht alle Produkte
-- =====================================================
SELECT 'TEST 3: Inhaber sieht alle Produkte' as test;
SELECT id, name, price FROM products;
-- Expected: 1 row

-- =====================================================
-- TEST 4: Kellner sieht nur sich selbst
-- =====================================================
SET LOCAL jwt.claims = '{"sub": "20000000-0000-0000-0000-000000000001", "email": "kellner@test.de"}';

SELECT 'TEST 4: Kellner sieht nur sich selbst (employees)' as test;
SELECT id, first_name, last_name, role FROM employees;
-- Expected: 1 row (nur sich selbst)

-- =====================================================
-- TEST 5: Kellner sieht Produkte (über restaurant_id via employees join)
-- =====================================================
SELECT 'TEST 5: Kellner sieht Produkte seines Restaurants' as test;
SELECT id, name, price FROM products;
-- Expected: 1 row (Produkt des Restaurants)

-- =====================================================
-- TEST 6: Koch sieht nur sich selbst
-- =====================================================
SET LOCAL jwt.claims = '{"sub": "30000000-0000-0000-0000-000000000001", "email": "koch@test.de"}';

SELECT 'TEST 6: Koch sieht nur sich selbst (employees)' as test;
SELECT id, first_name, last_name, role FROM employees;
-- Expected: 1 row (nur sich selbst)

-- =====================================================
-- TEST 7: Inhaber kann Produkt einfügen
-- =====================================================
SET LOCAL jwt.claims = '{"sub": "10000000-0000-0000-0000-000000000001", "email": "inhaber@test.de"}';

SELECT 'TEST 7: Inhaber fügt neues Produkt ein' as test;
INSERT INTO products (id, restaurant_id, category_id, name, price)
VALUES ('51111111-1111-1111-1111-111111111111'::uuid, '00000000-0000-0000-0000-000000000001'::uuid,
        '40000000-0000-0000-0000-000000000001'::uuid, 'Wein', 8.00)
RETURNING id, name, price;

-- =====================================================
-- TEST 8: Kellner KANN NICHT Produkt einfügen (RLS sollte das blockieren)
-- =====================================================
SET LOCAL jwt.claims = '{"sub": "20000000-0000-0000-0000-000000000001", "email": "kellner@test.de"}';

SELECT 'TEST 8: Kellner versucht Produkt einzufügen (sollte fehlschlagen)' as test;
INSERT INTO products (id, restaurant_id, category_id, name, price)
VALUES ('52222222-2222-2222-2222-222222222222'::uuid, '00000000-0000-0000-0000-000000000001'::uuid,
        '40000000-0000-0000-0000-000000000001'::uuid, 'Schnaps', 5.00)
RETURNING id, name, price;
-- Expected: Error (permission denied) weil Kellner nicht INSERT darf

-- =====================================================
-- Cleanup (optional)
-- =====================================================
-- DELETE FROM products WHERE restaurant_id = '00000000-0000-0000-0000-000000000001'::uuid;
-- DELETE FROM categories WHERE restaurant_id = '00000000-0000-0000-0000-000000000001'::uuid;
-- DELETE FROM employees WHERE restaurant_id = '00000000-0000-0000-0000-000000000001'::uuid;
-- DELETE FROM restaurants WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;
