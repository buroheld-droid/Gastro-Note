-- Ergänze orders Tabelle um Mitarbeiter-Tracking
ALTER TABLE orders 
  ADD COLUMN created_by UUID REFERENCES employees(id),
  ADD COLUMN completed_by UUID REFERENCES employees(id);

-- Ergänze payments um Mitarbeiter-Tracking (wer hat abkassiert)
ALTER TABLE payments 
  ADD COLUMN created_by UUID REFERENCES employees(id);

-- Erstelle Indexe für Performance
CREATE INDEX idx_orders_created_by ON orders(created_by);
CREATE INDEX idx_orders_completed_by ON orders(completed_by);
CREATE INDEX idx_payments_created_by ON payments(created_by);
CREATE INDEX idx_orders_status_created_at ON orders(status, created_at);

-- View für heutige Umsätze pro Kellner
CREATE OR REPLACE VIEW daily_employee_revenue_view AS
SELECT 
  e.id as employee_id,
  e.name as employee_name,
  e.role,
  COUNT(DISTINCT o.id) as order_count,
  SUM(p.amount) as total_revenue,
  SUM(COALESCE(p.amount, 0)) FILTER (WHERE p.payment_method = 'cash') as cash_revenue,
  SUM(COALESCE(p.amount, 0)) FILTER (WHERE p.payment_method = 'card') as card_revenue,
  MAX(p.created_at) as last_payment_at
FROM employees e
LEFT JOIN payments p ON e.id = p.created_by 
  AND DATE(p.created_at) = CURRENT_DATE
LEFT JOIN orders o ON p.order_id = o.id
WHERE DATE(p.created_at) = CURRENT_DATE 
   OR p.created_at IS NULL
GROUP BY e.id, e.name, e.role
ORDER BY total_revenue DESC NULLS LAST;

-- View für heutige Gesamt-Umsätze
CREATE OR REPLACE VIEW daily_revenue_summary_view AS
SELECT 
  DATE(created_at) as revenue_date,
  COUNT(DISTINCT id) as total_orders,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
  SUM(total) as total_revenue,
  SUM(subtotal) as total_net,
  SUM(tax_amount) as total_tax,
  COUNT(DISTINCT created_by) as employee_count,
  AVG(total) FILTER (WHERE status = 'completed') as avg_order_value
FROM orders
WHERE DATE(created_at) = CURRENT_DATE
GROUP BY DATE(created_at);

-- View für Echtzeit-Streaming (stündliche Umsätze)
CREATE OR REPLACE VIEW hourly_revenue_view AS
SELECT 
  DATE_TRUNC('hour', created_at) as hour,
  COUNT(DISTINCT id) as order_count,
  SUM(total) as revenue,
  SUM(subtotal) as net_revenue,
  SUM(tax_amount) as tax_revenue
FROM orders
WHERE DATE(created_at) = CURRENT_DATE AND status = 'completed'
GROUP BY DATE_TRUNC('hour', created_at)
ORDER BY hour DESC;
