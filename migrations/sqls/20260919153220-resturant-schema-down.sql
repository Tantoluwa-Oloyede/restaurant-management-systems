-- Drop Views
DROP VIEW IF EXISTS daily_sales_report;
DROP VIEW IF EXISTS low_stock_alerts;

-- Drop Triggers
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
DROP TRIGGER IF EXISTS trg_tables_updated_at ON tables;
DROP TRIGGER IF EXISTS trg_menu_items_updated_at ON menu_items;
DROP TRIGGER IF EXISTS trg_inventory_updated_at ON inventory;
DROP TRIGGER IF EXISTS trg_orders_updated_at ON orders;
DROP TRIGGER IF EXISTS trg_reservations_updated_at ON reservations;
DROP TRIGGER IF EXISTS trg_enforce_order_status_transition ON orders;
DROP TRIGGER IF EXISTS trg_log_order_status_change ON orders;
DROP TRIGGER IF EXISTS trg_deduct_inventory_on_order_prepare ON orders;

-- Drop Functions
DROP FUNCTION IF EXISTS set_updated_at() CASCADE;
DROP FUNCTION IF EXISTS enforce_order_status_transition() CASCADE;
DROP FUNCTION IF EXISTS log_order_status_change() CASCADE;
DROP FUNCTION IF EXISTS deduct_inventory_on_order_prepare() CASCADE;

-- Drop Tables (reverse order of dependencies)
DROP TABLE IF EXISTS system_audit_logs;
DROP TABLE IF EXISTS order_events;
DROP TABLE IF EXISTS order_idempotency_keys;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS menu_item_ingredients;
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS menu_items;
DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS tables;
DROP TABLE IF EXISTS staff_shifts;
DROP TABLE IF EXISTS otps;
DROP TABLE IF EXISTS users;

-- Drop Indexes (if not auto-removed)
DROP INDEX IF EXISTS idx_staff_shifts_user;
DROP INDEX IF EXISTS idx_reservations_slot;
DROP INDEX IF EXISTS idx_inventory_stock_alert;
DROP INDEX IF EXISTS idx_orders_table;
DROP INDEX IF EXISTS idx_orders_status;

-- Drop Enums
DROP TYPE IF EXISTS user_role;
DROP TYPE IF EXISTS table_status;
DROP TYPE IF EXISTS order_status;
DROP TYPE IF EXISTS reservation_status;
DROP TYPE IF EXISTS otp_purpose;
DROP TYPE IF EXISTS idempotency_status;
DROP TYPE IF EXISTS shift_status;

-- Drop Extensions
DROP EXTENSION IF EXISTS "uuid-ossp";
DROP EXTENSION IF EXISTS "pgcrypto";
DROP EXTENSION IF EXISTS "btree_gist";
