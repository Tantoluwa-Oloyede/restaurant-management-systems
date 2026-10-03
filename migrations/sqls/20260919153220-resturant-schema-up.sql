-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- ENUM TYPES
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('ADMIN', 'WAITER', 'KITCHEN');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE table_status AS ENUM ('AVAILABLE', 'OCCUPIED', 'RESERVED', 'OUT_OF_SERVICE');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE order_status AS ENUM ('PENDING', 'PREPARING', 'SERVED', 'PAID', 'CANCELLED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE reservation_status AS ENUM ('PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE otp_purpose AS ENUM ('EMAIL_VERIFICATION', 'PASSWORD_RESET');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE idempotency_status AS ENUM ('PROCESSING', 'COMPLETED', 'FAILED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE shift_status AS ENUM ('ACTIVE', 'ENDED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- USERS
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'WAITER',
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

--  OTPs
CREATE TABLE IF NOT EXISTS otps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    otp_hash VARCHAR(255) NOT NULL,
    purpose otp_purpose NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    attempts INT DEFAULT 0,
    used BOOLEAN DEFAULT FALSE,
    blocked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- STAFF SHIFTS & TRACKING
CREATE TABLE IF NOT EXISTS staff_shifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    clock_in TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    clock_out TIMESTAMPTZ,
    status shift_status NOT NULL DEFAULT 'ACTIVE',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (clock_out IS NULL OR clock_out > clock_in)
);

CREATE INDEX IF NOT EXISTS idx_staff_shifts_user ON staff_shifts(user_id, status);

-- SEATING / TABLES
CREATE TABLE IF NOT EXISTS tables (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_number INT UNIQUE NOT NULL,
    capacity INT NOT NULL CHECK (capacity > 0),
    status table_status NOT NULL DEFAULT 'AVAILABLE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

--  RESERVATIONS (TSTZRANGE EXCLUDE to prevent overlapping bookings)
CREATE TABLE IF NOT EXISTS reservations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_id UUID NOT NULL REFERENCES tables(id) ON DELETE CASCADE,
    customer_name VARCHAR(100) NOT NULL,
    customer_phone VARCHAR(20) NOT NULL,
    party_size INT NOT NULL CHECK (party_size > 0),
    booking_slot TSTZRANGE NOT NULL,
    status reservation_status NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (lower(booking_slot) < upper(booking_slot))
);

-- Database-Level Double Booking Prevention
ALTER TABLE reservations DROP CONSTRAINT IF EXISTS reservation_table_no_overlap;
ALTER TABLE reservations
ADD CONSTRAINT reservation_table_no_overlap
EXCLUDE USING GIST (
    table_id WITH =,
    booking_slot WITH &&
)
WHERE (status IN ('PENDING', 'CONFIRMED'));

CREATE INDEX IF NOT EXISTS idx_reservations_slot ON reservations USING GIST (booking_slot);

-- MENU (BOM ARCHITECTURE)
CREATE TABLE IF NOT EXISTS menu_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(150) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    category VARCHAR(50) NOT NULL,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- INVENTORY (INGREDIENTS)
CREATE TABLE IF NOT EXISTS inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_name VARCHAR(100) UNIQUE NOT NULL,
    quantity NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (quantity >= 0),
    unit VARCHAR(20) NOT NULL,
    reorder_level NUMERIC(10, 2) NOT NULL DEFAULT 10.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventory_stock_alert ON inventory(quantity, reorder_level);

-- Bill of Materials (Junction Table linking Menu to Raw Inventory)
CREATE TABLE IF NOT EXISTS menu_item_ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    inventory_id UUID NOT NULL REFERENCES inventory(id) ON DELETE RESTRICT,
    quantity_required NUMERIC(10, 2) NOT NULL CHECK (quantity_required > 0),
    UNIQUE(menu_item_id, inventory_id)
);

-- ORDERS
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_id UUID NOT NULL REFERENCES tables(id) ON DELETE RESTRICT,
    waiter_id UUID REFERENCES users(id) ON DELETE SET NULL,
    kitchen_staff_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status order_status NOT NULL DEFAULT 'PENDING',
    total_amount NUMERIC(10, 2) DEFAULT 0.00 CHECK (total_amount >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

--ORDER ITEMS
CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0)
);

CREATE INDEX IF NOT EXISTS idx_orders_table ON orders(table_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

-- IDEMPOTENCY KEYS
CREATE TABLE IF NOT EXISTS order_idempotency_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    idempotency_key VARCHAR(100) NOT NULL,
    request_hash TEXT NOT NULL,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    response_data JSONB,
    status idempotency_status NOT NULL DEFAULT 'PROCESSING',
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, idempotency_key)
);

-- ORDER EVENTS
CREATE TABLE IF NOT EXISTS order_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    old_status order_status,
    new_status order_status NOT NULL,
    event_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- SYSTEM AUDIT LOGS
CREATE TABLE IF NOT EXISTS system_audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- AUTOMATION & STATE ENFORCEMENT (PL/pgSQL TRIGGERS)

--  Automatic updated_at Timestamps
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_tables_updated_at BEFORE UPDATE ON tables FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_menu_items_updated_at BEFORE UPDATE ON menu_items FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_inventory_updated_at BEFORE UPDATE ON inventory FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_reservations_updated_at BEFORE UPDATE ON reservations FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- State Enforcement for Order Status Transitions
CREATE OR REPLACE FUNCTION enforce_order_status_transition()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF OLD.status = 'CANCELLED' AND NEW.status <> 'CANCELLED' THEN
            RAISE EXCEPTION 'Cancelled orders cannot be reopened.';
        END IF;

        IF OLD.status = 'PAID' AND NEW.status <> 'PAID' THEN
            RAISE EXCEPTION 'Paid orders cannot be modified.';
        END IF;

        IF OLD.status = 'PENDING' AND NEW.status NOT IN ('PREPARING', 'CANCELLED') THEN
            RAISE EXCEPTION 'Pending orders can only move to PREPARING or CANCELLED.';
        END IF;

        IF OLD.status = 'PREPARING' AND NEW.status NOT IN ('SERVED', 'CANCELLED') THEN
            RAISE EXCEPTION 'Preparing orders can only move to SERVED or CANCELLED.';
        END IF;

        IF OLD.status = 'SERVED' AND NEW.status NOT IN ('PAID', 'CANCELLED') THEN
            RAISE EXCEPTION 'Served orders can only move to PAID or CANCELLED.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_order_status_transition
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION enforce_order_status_transition();

-- Order Status Audit Logging
CREATE OR REPLACE FUNCTION log_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO order_events (order_id, actor_id, old_status, new_status, event_data)
        VALUES (
            NEW.id,
            COALESCE(NEW.kitchen_staff_id, NEW.waiter_id),
            OLD.status,
            NEW.status,
            jsonb_build_object('timestamp', NOW(), 'total_amount', NEW.total_amount)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_order_status_change
AFTER UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION log_order_status_change();

-- Recipe-Based Automated Inventory Deduction (BOM)
CREATE OR REPLACE FUNCTION deduct_inventory_on_order_prepare()
RETURNS TRIGGER AS $$
DECLARE
    item RECORD;
BEGIN
    -- Trigger inventory deduction when order moves to PREPARING
    IF OLD.status = 'PENDING' AND NEW.status = 'PREPARING' THEN
    FOR item IN
     SELECT
        mii.inventory_id,
        (mii.quantity_required * oi.quantity) AS total_deduction,
        inv.item_name, 
        inv.quantity AS current_stock
    FROM order_items oi
    JOIN menu_item_ingredients mii ON oi.menu_item_id = mii.menu_item_id
    JOIN inventory inv ON mii.inventory_id = inv.id
    WHERE oi.order_id = NEW.id
        LOOP
            IF item.current_stock < item.total_deduction THEN
                RAISE EXCEPTION 'Insufficient inventory for item %: needed %, available %', 
                    item.item_name, item.total_deduction, item.current_stock;
            END IF;

            UPDATE inventory
            SET quantity = quantity - item.total_deduction
            WHERE id = item.inventory_id;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_deduct_inventory_on_order_prepare
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION deduct_inventory_on_order_prepare();

--  REPORTING VIEWS (Daily Sales & Low Stock Alerts)
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

CREATE OR REPLACE VIEW low_stock_alerts AS
SELECT 
    id,
    item_name,
    quantity AS current_stock,
    reorder_level,
    unit
FROM inventory
WHERE quantity <= reorder_level;