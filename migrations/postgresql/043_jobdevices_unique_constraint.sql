-- Add a unique constraint on (deviceID, jobID) to the jobdevices table.
-- This is required so that the INSERT ... ON CONFLICT (deviceID, jobID) DO UPDATE
-- query used during outtake scanning works correctly in PostgreSQL.
--
-- Note: 000_combined_init.sql already defines PRIMARY KEY (jobid, deviceid) on
-- job_devices, which enforces uniqueness on the pair but in (jobid, deviceid) order.
-- PostgreSQL's ON CONFLICT clause requires an index whose column order exactly matches
-- the conflict target, so a separate index/constraint on (deviceid, jobid) is needed
-- for ON CONFLICT (deviceid, jobid) to work as expected.
--
-- Implementation approach (non-blocking for large tables):
--   Phase 1 – Remove duplicate rows inside a transaction with ACCESS EXCLUSIVE lock.
--             The stronger lock prevents new duplicates from racing in during cleanup.
--   Phase 2 – Build the unique index with CONCURRENTLY so the index build does NOT
--             hold an ACCESS EXCLUSIVE lock for its full duration. CONCURRENTLY cannot
--             run inside a transaction block, so it appears outside BEGIN/COMMIT.
--   Phase 3 – Promote the completed index to a named UNIQUE constraint. This takes
--             only a brief ACCESS EXCLUSIVE lock to update the catalog, not to scan
--             the table.
--
-- All three phases are idempotent: re-running this file after a partial failure is safe.

-- ─── Phase 1: Remove duplicate rows ────────────────────────────────────────────
BEGIN;

-- Take ACCESS EXCLUSIVE up-front so no concurrent writer can insert a new
-- duplicate row between the duplicate scan and the DELETE.
LOCK TABLE job_devices IN ACCESS EXCLUSIVE MODE;

DELETE FROM job_devices
WHERE ctid IN (
  SELECT ctid
  FROM (
    SELECT ctid,
           ROW_NUMBER() OVER (
             PARTITION BY deviceID, jobID
             ORDER BY (pack_ts IS NULL), pack_ts DESC, ctid DESC
           ) AS rn
    FROM job_devices
  ) ranked
  WHERE rn > 1
);

COMMIT;

-- ─── Phase 2: Build the unique index non-blocking ───────────────────────────────
-- CONCURRENTLY must run outside a transaction block (enforced by PostgreSQL).
-- IF NOT EXISTS makes this idempotent.
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_job_devices_deviceid_jobid
    ON job_devices(deviceid, jobid);

-- ─── Phase 3: Promote the index to a named UNIQUE constraint (idempotent) ───────
-- ADD CONSTRAINT USING INDEX takes only a brief catalog lock; the expensive
-- index build was already done non-blocking in Phase 2.
-- Skip if any unique constraint or primary key already covers (deviceid, jobid)
-- in that exact column order, OR if our named constraint already exists.
DO $$
DECLARE
    v_covered   boolean;
    v_idx_ready boolean;
BEGIN
    -- Check for an existing constraint (unique or pk) on (deviceid, jobid)
    SELECT EXISTS (
        SELECT 1
        FROM   pg_constraint c
        WHERE  c.contype  IN ('u', 'p')
          AND  c.conrelid = 'job_devices'::regclass
          AND  (
              SELECT array_agg(a.attname::text ORDER BY ck.ord)
              FROM   unnest(c.conkey::smallint[]) WITH ORDINALITY AS ck(attnum, ord)
              JOIN   pg_attribute a
                ON   a.attrelid = c.conrelid
               AND   a.attnum   = ck.attnum
          ) = ARRAY['deviceid', 'jobid']
    ) INTO v_covered;

    IF v_covered THEN
        RETURN;  -- Already covered; nothing to do
    END IF;

    -- Check that the index from Phase 2 is present and valid
    SELECT EXISTS (
        SELECT 1
        FROM   pg_class ic
        JOIN   pg_index i ON i.indexrelid = ic.oid
        WHERE  ic.relname    = 'idx_job_devices_deviceid_jobid'
          AND  i.indrelid    = 'job_devices'::regclass
          AND  i.indisunique = true
          AND  i.indisvalid  = true
    ) INTO v_idx_ready;

    IF v_idx_ready THEN
        ALTER TABLE job_devices
            ADD CONSTRAINT uq_job_devices_deviceid_jobid
            UNIQUE USING INDEX idx_job_devices_deviceid_jobid;
    END IF;
END;
$$;

