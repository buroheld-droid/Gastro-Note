# Mitarbeiterverwaltung - Implementierungsübersicht

## ✅ Was wurde implementiert

### 1. **Datenbank-Struktur** (`supabase/migrations/008_add_restaurant_to_employees.sql`)
- `restaurants` Tabelle für Multi-Tenant Support (owner_id basiert)
- `employees` Tabelle erweitert um:
  - `restaurant_id` - Zugehöriges Restaurant
  - `status` - active/inactive/on_leave
- `roles` Tabelle mit Standard-Rollen:
  - Inhaber (Admin) - alle Rechte
  - Kellner - POS & Bestellungen
  - Barkeeper - Getränke & Bestellungen  
  - Manager - Reports ohne Zahlungen

### 2. **Domain Model** (`lib/features/employees/domain/employee.dart`)
- `Employee` Klasse mit vollständigen Mitarbeiterdaten
- `EmployeeRole` Enum (owner, waiter, bartender, manager)
- `EmployeeStatus` Enum (active, inactive, on_leave)
- Automatische JSON-Serialisierung

### 3. **Repository** (`lib/features/employees/data/employees_repository.dart`)
- `getByRestaurant()` - Alle Mitarbeiter eines Restaurants
- `getById()` - Einzelnen Mitarbeiter laden
- `create()` - Neuen Mitarbeiter erstellen
- `update()` - Mitarbeiter aktualisieren
- `delete()` - Soft-Delete (deletedAt setzen)
- `updateStatus()` - Status ändern
- `updateRole()` - Rolle ändern
- Error-Handling mit aussagekräftigen Fehlermeldungen

### 4. **Riverpod Provider** (`lib/features/employees/providers/employees_provider.dart`)
- `employeesProvider(restaurantId)` - Alle Mitarbeiter
- `activeEmployeesProvider(restaurantId)` - Nur aktive
- `employeeByIdProvider(id)` - Einzelner Mitarbeiter
- `invalidateEmployeesProvider()` - Cache invalidieren

### 5. **UI Screen** (`lib/features/employees/presentation/employees_screen.dart`)
- Mitarbeiterliste mit Filtervarianten
- **Mitarbeiterkarte** mit:
  - Name, Vorname, Nachname
  - Rollenfarben (Inhaber=Lila, Manager=Blau, Kellner=Grün, Barkeeper=Orange)
  - Status-Chips (Aktiv=Grün, Inaktiv=Grau, Abwesend=Gelb)
  - Email anzeige
  - Edit/Delete Buttons
- **Mitarbeiter-Form Dialog** mit:
  - Vorname, Nachname, Personalnummer (Pflicht)
  - Email, Telefon, PIN (Optional)
  - Rolle (Dropdown)
  - Status (Dropdown)
  - Notizen
  - Create/Update mit Validierung
- **Delete Dialog** mit Soft-Delete Bestätigung

### 6. **Navigation** (`lib/core/router/app_router.dart`)
- Employees Screen in Router integriert
- Mock `restaurantId` für Development (später durch echte User-ID ersetzen)
- Path: `/employees`

### 7. **Provider-Integration** (`lib/core/providers/repository_providers.dart`)
- `employeesRepositoryProvider` registriert

## 📊 Datenfluss

```
UI (EmployeesScreen)
  ↓
Riverpod Provider (employeesProvider)
  ↓
Repository (EmployeesRepository)
  ↓
Supabase Client
  ↓
PostgreSQL DB
```

## 🔐 Sicherheit (TODO - nächste Phase)

### Geplante RLS-Policies:
```sql
-- Admin/Inhaber sieht alle Mitarbeiter des Restaurants
CREATE POLICY "admin_see_restaurant_employees"
  ON employees FOR SELECT
  USING (restaurant_id = current_user_restaurant());

-- Mitarbeiter sehen nur ihre eigenen Daten
CREATE POLICY "employees_see_only_self"
  ON employees FOR SELECT
  USING (id = auth.uid());
```

## 🚀 Verwendung im Code

```dart
// In einem Screen:
EmployeesScreen(restaurantId: 'restaurant-001')

// In einem Provider:
ref.watch(employeesProvider('restaurant-001'))

// Mitarbeiter erstellen:
final repo = ref.read(employeesRepositoryProvider);
final newEmployee = await repo.create(employee);

// Cache invalidieren nach Änderungen:
ref.read(invalidateEmployeesProvider)();
```

## 🎯 Nächste Schritte

1. **Migration deployen**: `supabase db push`
2. **RLS-Policies** implementieren (08_rls_employees.sql)
3. **Auth-Integration**: Real user_id statt mock restaurantId
4. **Roles & Permissions**: Basis-Zugriffskontrolle
5. **PIN-Login**: Terminal-Login für Kellner/Barkeeper
6. **Audit-Logs**: Wer hat wann was geändert

## 📝 Mock-Daten für Testing

```sql
-- In Supabase SQL Editor:
INSERT INTO restaurants (owner_id, name) VALUES
  ('owner-user-id', 'Mein Restaurant');

INSERT INTO employees (restaurant_id, employee_number, first_name, last_name, role, status) VALUES
  ('restaurant-001', 'E001', 'Max', 'Mustermann', 'owner', 'active'),
  ('restaurant-001', 'E002', 'Anna', 'Schmidt', 'waiter', 'active'),
  ('restaurant-001', 'E003', 'Tom', 'Barmann', 'bartender', 'active');
```
