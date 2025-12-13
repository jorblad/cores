-- WarehouseCore PostgreSQL Schema
-- This is a PostgreSQL-compatible version of the WarehouseCore additional tables

-- Storage zone types (simulating ENUM)
CREATE TYPE zone_type AS ENUM ('shelf', 'rack', 'case', 'vehicle', 'stage', 'warehouse', 'other');

-- Storage Zones table
CREATE TABLE IF NOT EXISTS storage_zones (
    zone_id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    type zone_type NOT NULL DEFAULT 'other',
    description TEXT,
    parent_zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    capacity INT NULL,
    location VARCHAR(255) NULL,
    barcode VARCHAR(255),
    metadata JSONB NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    label_url VARCHAR(512),
    led_strip_id INT,
    led_start INT,
    led_end INT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_zone_type ON storage_zones(type);
CREATE INDEX IF NOT EXISTS idx_zone_active ON storage_zones(is_active);
CREATE INDEX IF NOT EXISTS idx_zone_parent ON storage_zones(parent_zone_id);
CREATE INDEX IF NOT EXISTS idx_zone_barcode ON storage_zones(barcode);

-- Add zone reference to cases table if needed
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cases' AND column_name = 'zone_id') THEN
        ALTER TABLE cases ADD COLUMN zone_id INT NULL;
    END IF;
END $$;

-- Device movements table
CREATE TABLE IF NOT EXISTS device_movements (
    movement_id SERIAL PRIMARY KEY,
    device_id INT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    from_zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    to_zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    from_case_id INT NULL REFERENCES cases(id) ON DELETE SET NULL,
    to_case_id INT NULL REFERENCES cases(id) ON DELETE SET NULL,
    moved_by INT NULL REFERENCES users(id) ON DELETE SET NULL,
    movement_type VARCHAR(50) NOT NULL DEFAULT 'transfer',
    reason TEXT,
    metadata JSONB NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_movement_device ON device_movements(device_id);
CREATE INDEX IF NOT EXISTS idx_movement_from_zone ON device_movements(from_zone_id);
CREATE INDEX IF NOT EXISTS idx_movement_to_zone ON device_movements(to_zone_id);
CREATE INDEX IF NOT EXISTS idx_movement_type ON device_movements(movement_type);
CREATE INDEX IF NOT EXISTS idx_movement_created ON device_movements(created_at);

-- Scan events table
CREATE TABLE IF NOT EXISTS scan_events (
    scan_id SERIAL PRIMARY KEY,
    device_id INT NULL REFERENCES devices(id) ON DELETE SET NULL,
    zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    case_id INT NULL REFERENCES cases(id) ON DELETE SET NULL,
    scanner_id VARCHAR(100),
    scanned_by INT NULL REFERENCES users(id) ON DELETE SET NULL,
    scan_type VARCHAR(50) NOT NULL DEFAULT 'identify',
    barcode_value VARCHAR(255) NOT NULL,
    scan_result VARCHAR(50) NOT NULL DEFAULT 'success',
    metadata JSONB NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_scan_device ON scan_events(device_id);
CREATE INDEX IF NOT EXISTS idx_scan_zone ON scan_events(zone_id);
CREATE INDEX IF NOT EXISTS idx_scan_type ON scan_events(scan_type);
CREATE INDEX IF NOT EXISTS idx_scan_created ON scan_events(created_at);
CREATE INDEX IF NOT EXISTS idx_scan_barcode ON scan_events(barcode_value);

-- Defect reports table
CREATE TABLE IF NOT EXISTS defect_reports (
    defect_id SERIAL PRIMARY KEY,
    device_id INT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    reported_by INT NULL REFERENCES users(id) ON DELETE SET NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'minor',
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    description TEXT NOT NULL,
    resolution TEXT,
    resolved_by INT NULL REFERENCES users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMP NULL,
    metadata JSONB NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_defect_device ON defect_reports(device_id);
CREATE INDEX IF NOT EXISTS idx_defect_status ON defect_reports(status);
CREATE INDEX IF NOT EXISTS idx_defect_severity ON defect_reports(severity);
CREATE INDEX IF NOT EXISTS idx_defect_created ON defect_reports(created_at);

-- LED Controllers table
CREATE TABLE IF NOT EXISTS led_controllers (
    id SERIAL PRIMARY KEY,
    controller_id VARCHAR(100) NOT NULL UNIQUE,
    topic_suffix VARCHAR(100),
    status_data JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    last_seen TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_led_controller_id ON led_controllers(controller_id);
CREATE INDEX IF NOT EXISTS idx_led_active ON led_controllers(is_active);

-- Label templates table
CREATE TABLE IF NOT EXISTS label_templates (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    template_type VARCHAR(50) NOT NULL DEFAULT 'device',
    width_mm DECIMAL(10,2) DEFAULT 62,
    height_mm DECIMAL(10,2) DEFAULT 29,
    template_content TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product packages table (for website catalog)
CREATE TABLE IF NOT EXISTS product_packages (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) UNIQUE,
    description TEXT,
    short_description VARCHAR(500),
    price DECIMAL(10,2) DEFAULT 0.00,
    category VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    website_visible BOOLEAN DEFAULT FALSE,
    website_description TEXT,
    website_image_url VARCHAR(512),
    website_sort_order INT DEFAULT 0,
    alias_json TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_package_code ON product_packages(code);
CREATE INDEX IF NOT EXISTS idx_package_category ON product_packages(category);
CREATE INDEX IF NOT EXISTS idx_package_active ON product_packages(is_active);
CREATE INDEX IF NOT EXISTS idx_package_website ON product_packages(website_visible);

-- Product package items junction table
CREATE TABLE IF NOT EXISTS product_package_items (
    id SERIAL PRIMARY KEY,
    package_id INT NOT NULL REFERENCES product_packages(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity INT DEFAULT 1,
    is_optional BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_pkg_item_package ON product_package_items(package_id);
CREATE INDEX IF NOT EXISTS idx_pkg_item_product ON product_package_items(product_id);

-- Product dependencies table
CREATE TABLE IF NOT EXISTS product_dependencies (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    required_product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    dependency_type VARCHAR(50) DEFAULT 'requires',
    quantity INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(product_id, required_product_id)
);
CREATE INDEX IF NOT EXISTS idx_dep_product ON product_dependencies(product_id);
CREATE INDEX IF NOT EXISTS idx_dep_required ON product_dependencies(required_product_id);

-- API Keys table
CREATE TABLE IF NOT EXISTS api_keys (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    key_hash VARCHAR(255) NOT NULL UNIQUE,
    key_prefix VARCHAR(20) NOT NULL,
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    permissions TEXT DEFAULT '[]',
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP,
    last_used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_api_key_hash ON api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_api_key_active ON api_keys(is_active);
CREATE INDEX IF NOT EXISTS idx_api_key_user ON api_keys(user_id);

-- Add device current_zone_id column if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'devices' AND column_name = 'current_zone_id') THEN
        ALTER TABLE devices ADD COLUMN current_zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'devices' AND column_name = 'current_case_id') THEN
        ALTER TABLE devices ADD COLUMN current_case_id INT NULL REFERENCES cases(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Default storage zones
INSERT INTO storage_zones (code, name, type, description, is_active) VALUES
('MAIN-WH', 'Main Warehouse', 'warehouse', 'Primary warehouse location', TRUE),
('SHELF-A1', 'Shelf A1', 'shelf', 'Shelf section A1', TRUE),
('STAGE', 'Stage Area', 'stage', 'Event staging area', TRUE)
ON CONFLICT (code) DO NOTHING;

-- Default label template
INSERT INTO label_templates (name, description, template_type, width_mm, height_mm, is_default) VALUES
('Default Device Label', 'Standard device label 62x29mm', 'device', 62, 29, TRUE)
ON CONFLICT (name) DO NOTHING;
