-- =====================================================
-- Add role denormalization for RLS Performance
-- =====================================================
-- Erstellt: 2026-01-14
-- Beschreibung: Rolle als TEXT Spalte für RLS Policies
-- =====================================================

-- Add role column to employees (denormalized from roles table)
ALTER TABLE employees 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'Kellner';

-- Update existing roles based on role_id (if roles exist)
UPDATE employees e
SET role = COALESCE(r.name, 'Kellner')
FROM roles r
WHERE e.role_id = r.id AND e.role_id IS NOT NULL;

-- Fix any NULL or invalid role values before adding constraint
UPDATE employees
SET role = 'Kellner'
WHERE role IS NULL 
   OR role NOT IN ('Inhaber', 'Kellner', 'Barkeeper', 'Koch', 'Manager');

-- Create index for role-based queries
CREATE INDEX IF NOT EXISTS idx_employees_role ON employees(role) WHERE role IS NOT NULL;

-- Add constraint to ensure valid roles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage 
    WHERE constraint_name = 'check_valid_role'
  ) THEN
    ALTER TABLE employees
    ADD CONSTRAINT check_valid_role CHECK (role IN ('Inhaber', 'Kellner', 'Barkeeper', 'Koch', 'Manager'));
  END IF;
END $$;

COMMENT ON COLUMN employees.role IS 'Denormalisierte Rolle für RLS Performance (Inhaber, Kellner, Barkeeper, Koch, Manager)';
