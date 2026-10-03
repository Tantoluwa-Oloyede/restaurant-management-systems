-- The view must stop depending on paid_at before the column can be dropped
CREATE OR REPLACE VIEW daily_sales_report AS
SELECT
    DATE(created_at) AS sale_date,
    COUNT(id) AS total_orders,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS average_order_value
FROM orders
WHERE status = 'PAID'
GROUP BY DATE(created_at)
ORDER BY sale_date DESC;

DROP TRIGGER IF EXISTS trg_orders_set_paid_at ON orders;
DROP FUNCTION IF EXISTS set_order_paid_at();
ALTER TABLE orders DROP COLUMN IF EXISTS paid_at;
ALTER TABLE orders ALTER COLUMN total_amount DROP NOT NULL;