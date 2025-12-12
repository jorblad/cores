#!/bin/bash
# SQLite to PostgreSQL Migration Script
# This script exports SQLite data and imports it into PostgreSQL

set -e

# Configuration
SQLITE_DB="/data/rentalcore.db"
PG_HOST="${DB_HOST:-postgres}"
PG_PORT="${DB_PORT:-5432}"
PG_DB="${DB_NAME:-rentalcore}"
PG_USER="${DB_USER:-rentalcore}"
PG_PASS="${DB_PASSWORD:-rentalcore123}"

export PGPASSWORD="$PG_PASS"

echo "🔄 Starting SQLite to PostgreSQL migration..."

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL..."
until pg_isready -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" 2>/dev/null; do
    sleep 2
done
echo "✅ PostgreSQL is ready"

# Create tables based on existing schema
echo "📋 Creating PostgreSQL schema..."

psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" <<'EOSQL'
-- Drop existing tables if any (for clean migration)
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS led_controller_zone_types CASCADE;
DROP TABLE IF EXISTS led_controllers CASCADE;
DROP TABLE IF EXISTS zone_types CASCADE;
DROP TABLE IF EXISTS app_settings CASCADE;
DROP TABLE IF EXISTS api_keys CASCADE;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    "userID" SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    timezone VARCHAR(50) DEFAULT 'Europe/Berlin',
    language VARCHAR(10) DEFAULT 'en',
    avatar_path VARCHAR(255),
    notification_preferences TEXT,
    last_active TIMESTAMP,
    login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP,
    two_factor_enabled BOOLEAN DEFAULT false,
    two_factor_secret VARCHAR(255)
);

-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
    session_id VARCHAR(255) PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users("userID") ON DELETE CASCADE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Roles table
CREATE TABLE IF NOT EXISTS roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User roles junction table
CREATE TABLE IF NOT EXISTS user_roles (
    user_id INTEGER NOT NULL REFERENCES users("userID") ON DELETE CASCADE,
    role_id INTEGER NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigned_by INTEGER,
    PRIMARY KEY (user_id, role_id)
);

-- Zone types table
CREATE TABLE IF NOT EXISTS zone_types (
    zone_type_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    color VARCHAR(7) DEFAULT '#808080',
    icon VARCHAR(50),
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- LED controllers table
CREATE TABLE IF NOT EXISTS led_controllers (
    id SERIAL PRIMARY KEY,
    controller_id VARCHAR(100) NOT NULL UNIQUE,
    display_name VARCHAR(255) NOT NULL,
    topic_suffix VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    last_seen TIMESTAMP,
    metadata JSONB,
    ip_address VARCHAR(45),
    hostname VARCHAR(255),
    firmware_version VARCHAR(50),
    mac_address VARCHAR(17),
    status_data JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- LED controller zone types junction table
CREATE TABLE IF NOT EXISTS led_controller_zone_types (
    controller_id INTEGER NOT NULL REFERENCES led_controllers(id) ON DELETE CASCADE,
    zone_type_id INTEGER NOT NULL REFERENCES zone_types(zone_type_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (controller_id, zone_type_id)
);

-- App settings table
CREATE TABLE IF NOT EXISTS app_settings (
    setting_key VARCHAR(100) PRIMARY KEY,
    setting_value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- API keys table
CREATE TABLE IF NOT EXISTS api_keys (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    api_key_hash VARCHAR(64) NOT NULL UNIQUE,
    user_id INTEGER REFERENCES users("userID") ON DELETE SET NULL,
    permissions TEXT,
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP,
    last_used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default admin role
INSERT INTO roles (role_name, description) VALUES ('admin', 'System Administrator') ON CONFLICT DO NOTHING;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_led_controllers_controller_id ON led_controllers(controller_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_hash ON api_keys(api_key_hash);

EOSQL

echo "✅ PostgreSQL schema created"

# Check if SQLite database exists
if [ -f "$SQLITE_DB" ]; then
    echo "📦 Migrating data from SQLite..."
    
    # Export users from SQLite and import to PostgreSQL
    echo "  → Migrating users..."
    sqlite3 -csv "$SQLITE_DB" "SELECT userID, username, email, password_hash, first_name, last_name, COALESCE(is_active, 1), created_at, updated_at, last_login, timezone, language FROM users;" | \
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "\copy users(\"userID\", username, email, password_hash, first_name, last_name, is_active, created_at, updated_at, last_login, timezone, language) FROM STDIN WITH CSV" 2>/dev/null || echo "  ⚠️  Users migration skipped (may already exist)"
    
    # Fix sequence for users
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT setval('users_\"userID\"_seq', COALESCE((SELECT MAX(\"userID\") FROM users), 1));" 2>/dev/null || true

    # Export roles
    echo "  → Migrating roles..."
    sqlite3 -csv "$SQLITE_DB" "SELECT role_id, role_name, description, created_at, updated_at FROM roles;" | \
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "\copy roles(role_id, role_name, description, created_at, updated_at) FROM STDIN WITH CSV" 2>/dev/null || echo "  ⚠️  Roles migration skipped"
    
    # Fix sequence for roles
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT setval('roles_role_id_seq', COALESCE((SELECT MAX(role_id) FROM roles), 1));" 2>/dev/null || true

    # Export user_roles
    echo "  → Migrating user_roles..."
    sqlite3 -csv "$SQLITE_DB" "SELECT user_id, role_id, assigned_at, assigned_by FROM user_roles;" | \
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "\copy user_roles(user_id, role_id, assigned_at, assigned_by) FROM STDIN WITH CSV" 2>/dev/null || echo "  ⚠️  User_roles migration skipped"

    # Export zone_types
    echo "  → Migrating zone_types..."
    sqlite3 -csv "$SQLITE_DB" "SELECT zone_type_id, name, description, color, icon, sort_order, COALESCE(is_active, 1), created_at, updated_at FROM zone_types;" | \
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "\copy zone_types(zone_type_id, name, description, color, icon, sort_order, is_active, created_at, updated_at) FROM STDIN WITH CSV" 2>/dev/null || echo "  ⚠️  Zone_types migration skipped"
    
    # Fix sequence
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT setval('zone_types_zone_type_id_seq', COALESCE((SELECT MAX(zone_type_id) FROM zone_types), 1));" 2>/dev/null || true

    # Export LED controllers
    echo "  → Migrating led_controllers..."
    sqlite3 -csv "$SQLITE_DB" "SELECT id, controller_id, display_name, topic_suffix, COALESCE(is_active, 1), last_seen, metadata, ip_address, hostname, firmware_version, mac_address, status_data, created_at, updated_at FROM led_controllers;" | \
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "\copy led_controllers(id, controller_id, display_name, topic_suffix, is_active, last_seen, metadata, ip_address, hostname, firmware_version, mac_address, status_data, created_at, updated_at) FROM STDIN WITH CSV" 2>/dev/null || echo "  ⚠️  LED controllers migration skipped"
    
    # Fix sequence
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT setval('led_controllers_id_seq', COALESCE((SELECT MAX(id) FROM led_controllers), 1));" 2>/dev/null || true

    echo "✅ Data migration complete"
else
    echo "⚠️  No SQLite database found at $SQLITE_DB, creating fresh database"
    
    # Create default admin user
    echo "👤 Creating default admin user..."
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" <<'EOSQL'
    INSERT INTO users (username, email, password_hash, first_name, last_name, is_active)
    VALUES ('admin', 'admin@localhost', '$2a$10$hDLnsj7m4ia1iStwQbGejeBbH6gjS1uRd9xtLiKPpPF5pIVF5r3gK', 'Admin', 'User', true)
    ON CONFLICT (username) DO NOTHING;
    
    -- Assign admin role
    INSERT INTO user_roles (user_id, role_id)
    SELECT u."userID", r.role_id
    FROM users u, roles r
    WHERE u.username = 'admin' AND r.role_name = 'admin'
    ON CONFLICT DO NOTHING;
EOSQL
    echo "✅ Default admin user created (username: admin, password: test123)"
fi

echo "🎉 Migration complete!"
