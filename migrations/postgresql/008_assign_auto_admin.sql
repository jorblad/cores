-- Migration 008: Auto-assign Admin Role to N. Thielmann
-- This migration automatically grants admin privileges to the user "N. Thielmann"

-- Find user "N. Thielmann" and assign core `admin` and `warehouse_admin` roles (Postgres-compatible)
-- This avoids MySQL variables and uses idempotent INSERT ... SELECT with ON CONFLICT DO NOTHING.

-- Insert `admin` role assignment if user exists
INSERT INTO user_roles (userid, roleid, assigned_at, is_active)
SELECT u.userid, r.roleid, NOW(), TRUE
FROM users u
JOIN roles r ON r.name = 'admin'
WHERE (
  (COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '')) ILIKE '%thielmann%'
  OR u.username ILIKE '%thielmann%'
  OR u.email ILIKE '%thielmann%'
)
ON CONFLICT (userid, roleid) DO NOTHING;

-- Insert `warehouse_admin` role assignment if user exists
INSERT INTO user_roles (userid, roleid, assigned_at, is_active)
SELECT u.userid, r.roleid, NOW(), TRUE
FROM users u
JOIN roles r ON r.name = 'warehouse_admin'
WHERE (
  (COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '')) ILIKE '%thielmann%'
  OR u.username ILIKE '%thielmann%'
  OR u.email ILIKE '%thielmann%'
)
ON CONFLICT (userid, roleid) DO NOTHING;

-- Output a simple status note (psql will show the notices/row counts)
-- Note: this migration is intentionally conservative and idempotent.
