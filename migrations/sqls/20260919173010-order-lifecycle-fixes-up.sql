--  Status transition rules: only check when the status actually changes.
--    Custom error code ORD01 lets the backend recognise this error.
CREATE OR REPLACE FUNCTION enforce_order_status_transition()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        IF NOT (
            (OLD.status = 'PENDING'   AND NEW.status IN ('PREPARING', 'CANCELLED')) OR
            (OLD.status = 'PREPARING' AND NEW.status IN ('SERVED', 'CANCELLED')) OR
            (OLD.status = 'SERVED'    AND NEW.status IN ('PAID', 'CANCELLED'))
        ) THEN
            RAISE EXCEPTION 'Invalid order status transition: % -> %', OLD.status, NEW.status
                USING ERRCODE = 'ORD01';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--  paid_at: the moment an order was actually paid
ALTER TABLE orders ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;

UPDATE orders SET paid_at = updated_at WHERE status = 'PAID' AND paid_at IS NULL;
cccccc
CREATE OR REPLACE FUNCTION set_order_paid_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'PAID' AND OLD.status IS DISTINCT FROM 'PAID' THEN
        NEW.paid_at := NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_orders_set_paid_at
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION set_order_paid_at();

--  total_amount can no longer be NULL
UPDATE orders SET total_amount = 0 WHERE total_amount IS NULL;
ALTER TABLE orders ALTER COLUMN total_amount SET NOT NULL;




--  Daily sales now group by the day the order was PAID.
CREATE OR REPLACE VIEW daily_sales_report AS
SELECT
    DATE(paid_at AT TIME ZONE 'UTC') AS sale_date,
    COUNT(id) AS total_orders,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS average_order_value
FROM orders
WHERE status = 'PAID' AND paid_at IS NOT NULL
GROUP BY DATE(paid_at AT TIME ZONE 'UTC')
ORDER BY sale_date DESC;

--  Audit log: use the real actor supplied by the app
CREATE OR REPLACE FUNCTION log_order_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_actor UUID;
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        v_actor := NULLIF(current_setting('app.user_id', true), '')::UUID;

        INSERT INTO order_events (order_id, actor_id, old_status, new_status, event_data)
        VALUES (
            NEW.id,
            v_actor,
            OLD.status,
            NEW.status,
            jsonb_build_object('timestamp', NOW(), 'total_amount', NEW.total_amount)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;