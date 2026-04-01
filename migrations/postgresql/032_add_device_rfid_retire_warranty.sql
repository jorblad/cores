-- Migration: 032_add_device_rfid_retire_warranty.sql
-- Description: Add RFID, retire_date, and warranty_end_date columns to devices table,
--              and conditionally remove the NOT NULL constraint on deviceid only if it
--              is not part of the primary key.
-- Date: 2026-04-01

ALTER TABLE devices
  ADD COLUMN IF NOT EXISTS rfid VARCHAR(255) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS retire_date DATE DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS warranty_end_date DATE DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_devices_rfid ON devices(rfid);
CREATE INDEX IF NOT EXISTS idx_devices_serialnumber ON devices(serialnumber);

DO $$
DECLARE
  is_deviceid_pk BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
     AND tc.table_schema = kcu.table_schema
     AND tc.table_name = kcu.table_name
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'devices'
      AND tc.constraint_type = 'PRIMARY KEY'
      AND kcu.column_name = 'deviceid'
  ) INTO is_deviceid_pk;

  IF NOT is_deviceid_pk THEN
    ALTER TABLE devices ALTER COLUMN deviceid DROP NOT NULL;
  END IF;
END $$;
