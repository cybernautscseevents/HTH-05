-- REVIEW ONLY: required to persist visit admission/discharge state and historical
-- per-visit doctor assignment on databases that predate these Visit fields.
-- This file has NOT been executed against Aiven.
--
-- Required operator steps before execution:
-- 1. Take and restore-test a full backup of the target database.
-- 2. Confirm this is the intended database and its schema matches the preflight.
-- 3. Schedule a maintenance window; MySQL DDL implicitly commits and may lock visits.
-- 4. Review this script and approve the schema change explicitly.

-- Read-only preflight. Stop if any of these columns already exists or the result
-- differs from the audited Aiven schema; edit the reviewed DDL before execution.
SELECT DATABASE() AS selected_database, VERSION() AS mysql_version;
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'visits'
ORDER BY ORDINAL_POSITION;
SELECT COUNT(*) AS reasons_over_500_chars
FROM visits WHERE CHAR_LENGTH(reason) > 500;
SELECT staff_id FROM staff ORDER BY staff_id LIMIT 0;

-- Adds nullable state to historical rows without inventing past admission,
-- discharge, or assignment values. The patient_doctor_assignments table remains
-- the source of the patient's current doctor; this column records visit history.
ALTER TABLE visits
  ADD COLUMN admission_status VARCHAR(20) NULL DEFAULT NULL,
  ADD COLUMN assigned_doctor_id INT NULL,
  ADD COLUMN discharge_status VARCHAR(20) NULL,
  ADD INDEX idx_visits_assigned_doctor_id (assigned_doctor_id),
  ADD CONSTRAINT fk_visits_assigned_doctor
    FOREIGN KEY (assigned_doctor_id) REFERENCES staff (staff_id) ON DELETE SET NULL,
  MODIFY COLUMN reason VARCHAR(500) NULL;

-- Read-only postflight; run only after an approved execution.
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'visits'
  AND COLUMN_NAME IN ('admission_status', 'assigned_doctor_id', 'discharge_status', 'reason')
ORDER BY COLUMN_NAME;
SELECT TABLE_NAME, INDEX_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columns_in_index
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'visits'
  AND INDEX_NAME = 'idx_visits_assigned_doctor_id'
GROUP BY TABLE_NAME, INDEX_NAME;
