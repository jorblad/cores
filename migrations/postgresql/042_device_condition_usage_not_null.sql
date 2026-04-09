-- Migration 042: Enforce NOT NULL on devices.condition_rating and
-- devices.usage_hours while preserving existing default semantics.
--
-- These columns were created as nullable but the Go model (models.Device) uses
-- non-nullable float64 fields, causing a runtime scan error whenever a device
-- row has NULL in either column (e.g. a device inserted with only
-- deviceID/productID/status). Backfill existing NULLs and add/keep DEFAULTs
-- so future inserts that omit the columns never produce a NULL.
--
-- Low-lock approach to minimise impact on active deployments:
--   Step 1 – Set column DEFAULTs and add NOT VALID CHECK constraints first
--            (ACCESS EXCLUSIVE for a brief metadata-only operation; no table scan).
--            DEFAULTs are committed before the backfill so any concurrent inserts
--            that arrive after this point will already receive non-NULL values,
--            preventing a race where new NULLs could be inserted between the
--            backfill and VALIDATE steps.
--   Step 2 – Backfill existing NULLs in a single combined UPDATE.
--   Step 3 – VALIDATE the constraints in a separate transaction so the full table
--            scan runs under ShareUpdateExclusiveLock, allowing concurrent reads
--            and writes throughout.
--   Step 4 – Convert to NOT NULL (PostgreSQL reuses the validated constraint,
--            so the lock is brief and metadata-only) and drop the helper
--            constraints.

-- Step 1: set DEFAULTs and add NOT VALID constraints (no table scan, committed
--         before the backfill so concurrent inserts already get non-NULL values).
BEGIN;

ALTER TABLE devices
    ALTER COLUMN condition_rating SET DEFAULT 5.0,
    ALTER COLUMN usage_hours SET DEFAULT 0.00,
    ADD CONSTRAINT devices_condition_rating_not_null
        CHECK (condition_rating IS NOT NULL) NOT VALID,
    ADD CONSTRAINT devices_usage_hours_not_null
        CHECK (usage_hours IS NOT NULL) NOT VALID;

COMMIT;

-- Step 2: backfill existing NULLs in a single combined pass.
BEGIN;

UPDATE devices
SET
    condition_rating = COALESCE(condition_rating, 5.0),
    usage_hours = COALESCE(usage_hours, 0.00)
WHERE condition_rating IS NULL OR usage_hours IS NULL;

COMMIT;

-- Step 3: validate constraints (ShareUpdateExclusiveLock — reads/writes allowed).
BEGIN;

ALTER TABLE devices
    VALIDATE CONSTRAINT devices_condition_rating_not_null,
    VALIDATE CONSTRAINT devices_usage_hours_not_null;

COMMIT;

-- Step 4: promote to NOT NULL (reuses validated constraint; brief lock) and
--         drop the now-redundant CHECK constraints.
BEGIN;

ALTER TABLE devices
    ALTER COLUMN condition_rating SET NOT NULL,
    ALTER COLUMN usage_hours SET NOT NULL,
    DROP CONSTRAINT devices_condition_rating_not_null,
    DROP CONSTRAINT devices_usage_hours_not_null;

COMMIT;