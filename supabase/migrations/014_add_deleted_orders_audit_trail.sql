-- =====================================================
-- Add Soft-Delete Audit Trail for Orders
-- =====================================================
-- Erstellt: 2026-01-15
-- Beschreibung: Admin-Kontrollierte Löschung von Bestellungen
--              mit vollständigem Audit Trail
-- =====================================================

-- Ergänze orders um Lösch-Metadaten
ALTER TABLE orders 
  ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES employees(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS deletion_reason TEXT,
  ADD COLUMN IF NOT EXISTS deletion_timestamp TIMESTAMPTZ;

-- Erstelle Indexe für Performance
CREATE INDEX IF NOT EXISTS idx_orders_deleted_by ON orders(deleted_by) 
  WHERE deletion_timestamp IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_deletion_timestamp ON orders(deletion_timestamp) 
  WHERE deletion_timestamp IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_deleted_status ON orders(status, deletion_timestamp);

-- =====================================================
-- VIEW: Deleted Orders für Admin-Übersicht (heute)
-- =====================================================
CREATE OR REPLACE VIEW deleted_orders_view AS
SELECT 
  o.id,
  o.number as order_number,
  o.table_id,
  COALESCE(t.number::TEXT, 'System') as table_number,
  o.total as order_total,
  o.subtotal as order_net,
  o.tax_amount as order_tax,
  o.payment_method,
  o.status,
  o.created_by,
  (COALESCE(ew.first_name, 'Unknown') || ' ' || COALESCE(ew.last_name, '')) as waiter_name,
  o.completed_at,
  o.deleted_by,
  (COALESCE(ed.first_name, 'Unknown') || ' ' || COALESCE(ed.last_name, '')) as deleted_by_name,
  o.deletion_reason,
  o.deletion_timestamp,
  EXTRACT(EPOCH FROM (NOW() - o.deletion_timestamp)) / 3600 as hours_since_deletion,
  COUNT(oi.id) OVER (PARTITION BY o.id) as item_count,
  STRING_AGG(p.name, ', ' ORDER BY p.name) as product_names
FROM orders o
LEFT JOIN tables t ON o.table_id = t.id
LEFT JOIN employees ew ON o.created_by = ew.id
LEFT JOIN employees ed ON o.deleted_by = ed.id
LEFT JOIN order_items oi ON o.id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.id
WHERE o.deletion_timestamp IS NOT NULL
  AND DATE(o.deletion_timestamp) >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY 
  o.id, o.number, o.table_id, t.number, o.total, o.subtotal, o.tax_amount,
  o.payment_method, o.status, o.created_by, ew.first_name, ew.last_name,
  o.completed_at, o.deleted_by, ed.first_name, ed.last_name, 
  o.deletion_reason, o.deletion_timestamp
ORDER BY o.deletion_timestamp DESC;

-- =====================================================
-- VIEW: Active Orders (nicht gelöschte) für normale Arbeit
-- =====================================================
CREATE OR REPLACE VIEW active_orders_view AS
SELECT *
FROM orders
WHERE deletion_timestamp IS NULL;

-- =====================================================
-- FUNCTION: Sichere Bestellung löschen mit Audit Trail
-- =====================================================
CREATE OR REPLACE FUNCTION delete_order_with_audit(
  p_order_id UUID,
  p_deleted_by_id UUID,
  p_deletion_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_result JSONB;
  v_user_role TEXT;
BEGIN
  -- 1. Validierung: User muss Admin/Manager sein
  SELECT role INTO v_user_role
  FROM employees
  WHERE id = p_deleted_by_id;

  IF v_user_role NOT IN ('Inhaber', 'Manager') THEN
    RAISE EXCEPTION 'Permission denied: Only Manager/Admin can delete orders';
  END IF;

  -- 2. Lade Bestelldetails
  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id;

  IF v_order IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  -- 3. Prüfe: Muss abkassiert sein (completed)
  IF v_order.status != 'completed' THEN
    RAISE EXCEPTION 'Cannot delete: Order must be completed. Current status: %', v_order.status;
  END IF;

  -- 4. Prüfe: Darf nicht bereits gelöscht sein
  IF v_order.deletion_timestamp IS NOT NULL THEN
    RAISE EXCEPTION 'Order already deleted on %', v_order.deletion_timestamp;
  END IF;

  -- 5. Soft-Delete: Setze Metadaten
  UPDATE orders
  SET 
    deleted_by = p_deleted_by_id,
    deletion_reason = COALESCE(p_deletion_reason, 'Admin deletion'),
    deletion_timestamp = NOW()
  WHERE id = p_order_id;

  -- 6. Erstelle Audit-Log JSON
  v_result := jsonb_build_object(
    'success', true,
    'order_id', v_order.id,
    'order_number', v_order.number,
    'table_number', (SELECT number FROM tables WHERE id = v_order.table_id),
    'original_total', v_order.total,
    'deleted_at', NOW()::TEXT,
    'deleted_by', p_deleted_by_id,
    'deletion_reason', COALESCE(p_deletion_reason, 'Admin deletion'),
    'message', 'Order soft-deleted successfully'
  );

  RETURN v_result;

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM,
    'order_id', p_order_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- FUNCTION: Restore deleted order (Admin only)
-- =====================================================
CREATE OR REPLACE FUNCTION restore_deleted_order(
  p_order_id UUID,
  p_restored_by_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_result JSONB;
  v_user_role TEXT;
BEGIN
  -- Validierung: User muss Admin/Manager sein
  SELECT role INTO v_user_role
  FROM employees
  WHERE id = p_restored_by_id;

  IF v_user_role NOT IN ('Inhaber', 'Manager') THEN
    RAISE EXCEPTION 'Permission denied: Only Manager/Admin can restore orders';
  END IF;

  -- Lade Bestelldetails
  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id;

  IF v_order IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  -- Prüfe: Muss gelöscht sein
  IF v_order.deletion_timestamp IS NULL THEN
    RAISE EXCEPTION 'Order is not deleted';
  END IF;

  -- Restore: Lösche Lösch-Metadaten
  UPDATE orders
  SET 
    deleted_by = NULL,
    deletion_reason = NULL,
    deletion_timestamp = NULL
  WHERE id = p_order_id;

  v_result := jsonb_build_object(
    'success', true,
    'order_id', v_order.id,
    'restored_at', NOW()::TEXT,
    'restored_by', p_restored_by_id,
    'message', 'Order restored successfully'
  );

  RETURN v_result;

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM,
    'order_id', p_order_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- RLS: Update policies für Soft-Delete awareness
-- =====================================================

-- Kellner: Kann nur active (nicht gelöschte) Bestellungen sehen
DROP POLICY IF EXISTS "employees_see_orders_own_restaurant" ON orders;
CREATE POLICY "employees_see_orders_own_restaurant"
  ON orders FOR SELECT
  USING (
    restaurant_id IN (
      SELECT restaurant_id FROM employees 
      WHERE id = auth.uid() OR email = auth.jwt() ->> 'email'
    )
    AND deletion_timestamp IS NULL  -- Kellner sieht nur aktive Bestellungen
  );

-- Manager/Admin: Sieht ALLE Bestellungen (auch gelöschte)
DROP POLICY IF EXISTS "managers_see_all_orders" ON orders;
CREATE POLICY "managers_see_all_orders"
  ON orders FOR SELECT
  USING (
    restaurant_id IN (
      SELECT restaurant_id FROM employees 
      WHERE (id = auth.uid() OR email = auth.jwt() ->> 'email')
        AND role IN ('Inhaber', 'Manager')
    )
  );

-- Nur Inhaber/Manager dürfen Bestellungen "löschen" (Soft-Delete via UPDATE)
DROP POLICY IF EXISTS "managers_can_soft_delete_orders" ON orders;
CREATE POLICY "managers_can_soft_delete_orders"
  ON orders FOR UPDATE
  USING (
    restaurant_id IN (
      SELECT restaurant_id FROM employees 
      WHERE (id = auth.uid() OR email = auth.jwt() ->> 'email')
        AND role IN ('Inhaber', 'Manager')
    )
  )
  WITH CHECK (
    restaurant_id IN (
      SELECT restaurant_id FROM employees 
      WHERE (id = auth.uid() OR email = auth.jwt() ->> 'email')
        AND role IN ('Inhaber', 'Manager')
    )
  );

-- =====================================================
-- COMMENTS für Dokumentation
-- =====================================================
COMMENT ON COLUMN orders.deleted_by IS 'Employee (Manager/Admin) der die Bestellung gelöscht hat';
COMMENT ON COLUMN orders.deletion_reason IS 'Grund für die Löschung (z.B. "Doppel-Eintrag", "Kunden-Wunsch", "Kassierfehler")';
COMMENT ON COLUMN orders.deletion_timestamp IS 'Zeitstempel wann die Bestellung gelöscht wurde (Soft-Delete)';
COMMENT ON VIEW deleted_orders_view IS 'Admin-Übersicht aller gelöschten Bestellungen mit vollständigem Audit Trail';
COMMENT ON VIEW active_orders_view IS 'Alle aktiven (nicht gelöschten) Bestellungen';
COMMENT ON FUNCTION delete_order_with_audit IS 'Sichere Bestellung löschen mit Validierung + Audit Trail';
COMMENT ON FUNCTION restore_deleted_order IS 'Gelöschte Bestellung wiederherstellen (Admin only)';
