-- Add preparation status fields to order_items table
CREATE TYPE preparation_status AS ENUM ('pending', 'in_progress', 'ready', 'delivered');

ALTER TABLE order_items 
  ADD COLUMN preparation_status preparation_status DEFAULT 'pending',
  ADD COLUMN prepared_at TIMESTAMPTZ,
  ADD COLUMN prepared_by UUID REFERENCES employees(id);

-- Create index for faster filtering by status
CREATE INDEX idx_order_items_preparation_status ON order_items(preparation_status);
CREATE INDEX idx_order_items_prepared_at ON order_items(prepared_at);

-- Add category_type to categories table for kitchen/bar filtering
ALTER TABLE categories 
  ADD COLUMN category_type TEXT DEFAULT 'food' CHECK (category_type IN ('food', 'drinks', 'other'));

-- Update existing categories (adjust names based on your actual data)
UPDATE categories SET category_type = 'drinks' 
WHERE LOWER(name) LIKE '%drink%' 
   OR LOWER(name) LIKE '%getränk%' 
   OR LOWER(name) LIKE '%bar%';

UPDATE categories SET category_type = 'food' 
WHERE category_type IS NULL OR category_type = 'food';

-- Create view for kitchen items
CREATE OR REPLACE VIEW kitchen_items_view AS
SELECT 
  oi.*,
  o.table_id,
  o.created_at as order_created_at,
  rt.table_number,
  rt.area,
  c.name as category_name,
  c.category_type
FROM order_items oi
JOIN orders o ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
JOIN categories c ON p.category_id = c.id
LEFT JOIN tables rt ON o.table_id = rt.id
WHERE o.status = 'open' 
  AND c.category_type = 'food'
  AND oi.preparation_status IN ('pending', 'in_progress', 'ready')
ORDER BY o.created_at ASC, oi.created_at ASC;

-- Create view for bar items
CREATE OR REPLACE VIEW bar_items_view AS
SELECT 
  oi.*,
  o.table_id,
  o.created_at as order_created_at,
  rt.table_number,
  rt.area,
  c.name as category_name,
  c.category_type
FROM order_items oi
JOIN orders o ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
JOIN categories c ON p.category_id = c.id
LEFT JOIN tables rt ON o.table_id = rt.id
WHERE o.status = 'open' 
  AND c.category_type = 'drinks'
  AND oi.preparation_status IN ('pending', 'in_progress', 'ready')
ORDER BY o.created_at ASC, oi.created_at ASC;
