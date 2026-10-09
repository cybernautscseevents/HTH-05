-- Saathi / Aiven MySQL schema reconciliation proposal
-- REVIEW ONLY. This file was prepared for review and has NOT been executed.
-- Target observed during audit: defaultdb, MySQL 8.4.8.
--
-- Critical operator gates before any execution:
--   1. Compare Jeevan's latest local mitra_assist schema and data with Aiven.
--   2. Confirm Aiven is the intended source of truth and decide how any local-only
--      admissions/history should be reconciled. This script does not import them.
--   3. Take and restore-test a complete Aiven backup (instructions in the task report).
--   4. Run the read-only preflight below and stop if observed state differs.
--   5. Review the matching backend model/API changes before using this DDL.
--
-- MySQL DDL implicitly commits and may rebuild/lock tables. This is deliberately
-- not wrapped in a transaction and is not safe to rerun after partial execution.
-- Do not run Base.metadata.create_all(), reset_database.py, or this file without
-- explicit owner approval and a maintenance window.

-- -----------------------------------------------------------------------------
-- READ-ONLY PREFLIGHT: run against the intended database and review all results.
-- -----------------------------------------------------------------------------
SELECT DATABASE() AS selected_database, VERSION() AS mysql_version;

SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
ORDER BY TABLE_NAME;

-- Save these aggregate counts as the before-migration baseline. Compare the
-- same counts after DDL; no row contents are returned.
SELECT table_name, row_count
FROM (
  SELECT 'appointment_reschedule_requests' AS table_name, COUNT(*) AS row_count FROM appointment_reschedule_requests
  UNION ALL SELECT 'appointments', COUNT(*) FROM appointments
  UNION ALL SELECT 'audit_log', COUNT(*) FROM audit_log
  UNION ALL SELECT 'medical_history', COUNT(*) FROM medical_history
  UNION ALL SELECT 'medication_adherence', COUNT(*) FROM medication_adherence
  UNION ALL SELECT 'medicine_schedules', COUNT(*) FROM medicine_schedules
  UNION ALL SELECT 'medicines', COUNT(*) FROM medicines
  UNION ALL SELECT 'notifications', COUNT(*) FROM notifications
  UNION ALL SELECT 'patient_activations', COUNT(*) FROM patient_activations
  UNION ALL SELECT 'patient_devices', COUNT(*) FROM patient_devices
  UNION ALL SELECT 'patient_doctor_assignments', COUNT(*) FROM patient_doctor_assignments
  UNION ALL SELECT 'patient_sessions', COUNT(*) FROM patient_sessions
  UNION ALL SELECT 'patients', COUNT(*) FROM patients
  UNION ALL SELECT 'prescription_items', COUNT(*) FROM prescription_items
  UNION ALL SELECT 'prescriptions', COUNT(*) FROM prescriptions
  UNION ALL SELECT 'reports', COUNT(*) FROM reports
  UNION ALL SELECT 'staff', COUNT(*) FROM staff
  UNION ALL SELECT 'users', COUNT(*) FROM users
  UNION ALL SELECT 'visits', COUNT(*) FROM visits
) AS before_counts
ORDER BY table_name;

SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
    'visits', 'patient_admissions', 'users', 'prescription_items',
    'medical_history', 'prescriptions', 'reports', 'appointments'
  )
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT TABLE_NAME, INDEX_NAME, NON_UNIQUE,
       GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS indexed_columns
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('visits', 'reports', 'appointments')
GROUP BY TABLE_NAME, INDEX_NAME, NON_UNIQUE
ORDER BY TABLE_NAME, INDEX_NAME;

-- These must remain zero before the corresponding tightening/widening steps.
-- They report aggregates only; no patient rows or values are returned.
SELECT COUNT(*) AS visits_with_null_doctor_id
FROM visits WHERE doctor_id IS NULL;

SELECT COUNT(*) AS visits_with_reason_over_500_chars
FROM visits WHERE CHAR_LENGTH(reason) > 500;

SELECT COUNT(*) AS prescription_items_with_null_dosage
FROM prescription_items WHERE dosage IS NULL;

SELECT COUNT(*) AS report_version_duplicate_groups
FROM (
  SELECT visit_id, version_no
  FROM reports
  GROUP BY visit_id, version_no
  HAVING COUNT(*) > 1
) AS duplicate_versions;

-- STOP if the database/table/column/index state does not match this proposal.
-- In particular, this audit observed patient_admissions absent and these visits
-- columns absent: admission_status, assigned_doctor_id, discharge_status.

-- -----------------------------------------------------------------------------
-- PROPOSED ONE-TIME DDL. Execute only after all operator gates above are met.
-- -----------------------------------------------------------------------------

-- Add fields required by the current Visit model without inventing historical
-- admission/discharge state. Existing visits receive NULL (unknown/not recorded).
-- assigned_doctor_id starts NULL; no backfill from doctor_id is assumed because
-- the application treats consultation doctor and assigned doctor as distinct.
ALTER TABLE visits
  ADD COLUMN admission_status VARCHAR(20) NULL DEFAULT NULL,
  ADD COLUMN assigned_doctor_id INT NULL,
  ADD COLUMN discharge_status VARCHAR(20) NULL,
  ADD INDEX idx_visits_assigned_doctor_id (assigned_doctor_id),
  ADD CONSTRAINT fk_visits_assigned_doctor
    FOREIGN KEY (assigned_doctor_id) REFERENCES staff (staff_id) ON DELETE SET NULL;

-- doctor_id is NOT NULL in the ORM; preflight must show zero NULL values.
-- Widen reason to the API's 500-character limit (no truncation).
-- Make visit_type nullable to match the API/ORM's optional field; retain its
-- existing database default for direct inserts that omit the column.
ALTER TABLE visits
  MODIFY COLUMN doctor_id INT NOT NULL,
  MODIFY COLUMN visit_type VARCHAR(100) NULL DEFAULT 'consultation',
  MODIFY COLUMN reason VARCHAR(500) NULL;

-- Convert the fixed enum to the ORM's extensible string type. Current enum values
-- fit VARCHAR(30); this preserves them and permits future supported staff labels.
ALTER TABLE users
  MODIFY COLUMN role VARCHAR(30)
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

-- Convert the fixed medicine-type enum to the ORM's free-form string type while
-- retaining existing values and the current 'tablet' default. dosage is currently
-- nullable in Aiven; preflight confirms no NULLs before matching ORM NOT NULL.
ALTER TABLE prescription_items
  MODIFY COLUMN medicine_type VARCHAR(100)
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT 'tablet',
  MODIFY COLUMN dosage VARCHAR(100) NOT NULL;

-- Create the missing table to match PatientAdmission. It starts empty; do not
-- synthesize records from visits or import local records without a separate plan.
CREATE TABLE patient_admissions (
  admission_id INT NOT NULL AUTO_INCREMENT,
  patient_id INT NOT NULL,
  visit_id BIGINT NOT NULL,
  ward_type VARCHAR(20) NOT NULL,
  bed_number VARCHAR(30) NOT NULL,
  id_proof_name VARCHAR(255) NULL,
  id_proof_mime VARCHAR(100) NULL,
  id_proof_data MEDIUMBLOB NULL,
  admitted_by INT NULL,
  admitted_at DATETIME NOT NULL,
  released_at DATETIME NULL,
  PRIMARY KEY (admission_id),
  UNIQUE KEY uq_patient_admissions_visit_id (visit_id),
  KEY idx_patient_admissions_patient_id (patient_id),
  CONSTRAINT fk_patient_admissions_patient
    FOREIGN KEY (patient_id) REFERENCES patients (patient_id) ON DELETE CASCADE,
  CONSTRAINT fk_patient_admissions_visit
    FOREIGN KEY (visit_id) REFERENCES visits (visit_id) ON DELETE CASCADE,
  CONSTRAINT fk_patient_admissions_admitted_by
    FOREIGN KEY (admitted_by) REFERENCES users (user_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Performance-only index used by appointment status filters. No rows are changed.
ALTER TABLE appointments
  ADD INDEX idx_appointments_status (status);

-- Intentionally unchanged:
--   * audit_log, medicine_schedules, patient_sessions are preserved.
--   * existing reports UNIQUE(visit_id, version_no) is preserved. Add the same
--     UniqueConstraint to the Report ORM model and fix create_report() to allocate
--     the next version under a per-visit lock before deploying the backend.
--   * Existing additional indexes are preserved; do not drop them as cleanup.
--   * Cloud TEXT columns remain TEXT. Update ORM String mappings to Text rather
--     than shrinking cloud columns and risking truncation.
--   * medical_history.history_id remains BIGINT. Update ORM Integer to BigInteger
--     rather than narrowing existing identifiers.

-- -----------------------------------------------------------------------------
-- POST-MIGRATION READ-ONLY VALIDATION (run only after an approved migration).
-- -----------------------------------------------------------------------------
SELECT DATABASE() AS selected_database;

SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('visits', 'patient_admissions', 'users', 'prescription_items')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT TABLE_NAME, INDEX_NAME, NON_UNIQUE,
       GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS indexed_columns
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('visits', 'reports', 'appointments', 'patient_admissions')
GROUP BY TABLE_NAME, INDEX_NAME, NON_UNIQUE
ORDER BY TABLE_NAME, INDEX_NAME;

SELECT COUNT(*) AS patient_admissions_rows FROM patient_admissions;
SELECT COUNT(*) AS visits_rows FROM visits;
SELECT COUNT(*) AS reports_rows FROM reports;
SELECT 1 AS connection_check;

-- Repeat the before_counts UNION ALL query and compare every pre-existing table.
-- The 19 existing table counts must be unchanged; patient_admissions begins at 0.

-- Re-run full ORM-vs-database schema comparison and application smoke tests before
-- opening the service to writes. No rollback DDL is provided: restoring a verified
-- backup to a separate instance is safer than reverse-altering live tables.
