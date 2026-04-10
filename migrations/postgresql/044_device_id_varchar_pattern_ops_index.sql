-- Migration 044: Add a varchar_pattern_ops index on devices(deviceID) for
-- efficient LIKE 'prefix%' queries under non-C database collations. This index
-- is used by device ID allocation logic to find the next available device ID
-- counter.
--
-- The existing plain btree index idx_devices_deviceid_pattern (created in
-- migration 030) is kept alongside this index.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_devices_deviceid_pattern_ops
    ON devices(deviceID varchar_pattern_ops);
