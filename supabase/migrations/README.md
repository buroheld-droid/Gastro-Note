# Supabase SQL Migrations

Diese Ordner enthält die SQL-Migrationsdateien für das Gastro Note POS-System.

## Ausführung im Supabase SQL Editor

### Reihenfolge der Ausführung:

1. **20260113_001_initial_schema.sql**
   - Erstellt alle Basis-Tabellen
   - Indizes für Performance
   - Trigger für `updated_at` Timestamps
   - Dauer: ~5 Sekunden

2. **20260113_002_rls_policies.sql**
   - Aktiviert Row Level Security (RLS)
   - ⚠️ **WICHTIG**: Policies sind aktuell sehr permissive (erlauben alles)
   - Muss später angepasst werden, sobald Auth implementiert ist
   - Dauer: ~2 Sekunden

3. **20260113_003_seed_data.sql**
   - Fügt Test-Daten ein:
     - 3 Rollen (Manager, Service, Küche)
     - 3 Test-Mitarbeiter
     - 4 Kategorien
     - 12 Produkte
     - 5 Modifikatoren
     - 1 Test-Schicht
   - Dauer: ~1 Sekunde

## Anleitung

1. Öffne [Supabase Dashboard](https://supabase.com/dashboard)
2. Gehe zu deinem Projekt: `rctzvwhhvccczidnhtdq`
3. Navigiere zu **SQL Editor** (linkes Menü)
4. Klicke auf **+ New query**
5. Kopiere den Inhalt der jeweiligen SQL-Datei
6. Füge ihn ein und klicke auf **Run** (oder `Ctrl+Enter`)
7. Wiederhole für alle 3 Dateien in der richtigen Reihenfolge

## Überprüfung

Nach dem Ausführen kannst du im **Table Editor** überprüfen, ob alle Tabellen erstellt wurden:

- roles
- employees
- categories
- products
- modifiers
- product_modifiers
- shifts
- orders
- order_items
- payments

## Datenbank-Schema

```
roles (Rollen)
  └─> employees (Mitarbeiter)
        └─> shifts (Schichten)
              └─> orders (Bestellungen)
                    ├─> order_items (Positionen)
                    └─> payments (Zahlungen)

categories (Kategorien)
  └─> products (Produkte)
        ├─> order_items
        └─> product_modifiers
              └─> modifiers (Extras)
```

## Nächste Schritte

Nach erfolgreicher Migration:
1. ✅ Flutter-App testen (sollte nun Daten von Supabase laden können)
2. ✅ API-Clients/Repositories im Flutter-Code implementieren
3. ✅ State-Management für POS-Flow aufbauen
4. ⏸️ Auth/Login später implementieren

## Rollback

Falls du die Tabellen löschen möchtest:

```sql
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS shifts CASCADE;
DROP TABLE IF EXISTS product_modifiers CASCADE;
DROP TABLE IF EXISTS modifiers CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column();
```
