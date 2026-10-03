CREATE OR REPLACE FUNCTION deduct_inventory_on_order_prepare()
RETURNS TRIGGER AS $$
DECLARE
    r RECORD;
    v_name TEXT;
    v_available NUMERIC;
BEGIN
    -- PENDING -> PREPARING: take the ingredients out of stock
    IF OLD.status = 'PENDING' AND NEW.status = 'PREPARING' THEN
        FOR r IN
            SELECT mii.inventory_id,
                   SUM(mii.quantity_required * oi.quantity) AS total_needed
            FROM order_items oi
            JOIN menu_item_ingredients mii ON mii.menu_item_id = oi.menu_item_id
            WHERE oi.order_id = NEW.id
            GROUP BY mii.inventory_id
            ORDER BY mii.inventory_id
        LOOP
            UPDATE inventory
            SET quantity = quantity - r.total_needed
            WHERE id = r.inventory_id
              AND quantity >= r.total_needed;

            IF NOT FOUND THEN
                SELECT item_name, quantity INTO v_name, v_available
                FROM inventory WHERE id = r.inventory_id;

                RAISE EXCEPTION 'Insufficient inventory for %: needed %, available %',
                    v_name, r.total_needed, v_available
                    USING ERRCODE = 'INV01';
            END IF;
        END LOOP;

    -- PREPARING -> CANCELLED: put the ingredients back
    ELSIF OLD.status = 'PREPARING' AND NEW.status = 'CANCELLED' THEN
        UPDATE inventory inv
        SET quantity = inv.quantity + s.total_used
        FROM (
            SELECT mii.inventory_id,
                   SUM(mii.quantity_required * oi.quantity) AS total_used
            FROM order_items oi
            JOIN menu_item_ingredients mii ON mii.menu_item_id = oi.menu_item_id
            WHERE oi.order_id = NEW.id
            GROUP BY mii.inventory_id
        ) s
        WHERE inv.id = s.inventory_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;