# Patient report storage — approval required

Read-only `information_schema` inspection on 9 October 2026 found no
`patient_discharge_reports` table in the locally configured Aiven database.
The deployed API advertises the correct POST/GET/chat routes. Render's actual
database configuration, deployed SHA and authenticated request logs could not
be inspected because its dashboard requires sign-in.

The save endpoint queries this table before inserting. Without it, MySQL raises
error 1146; extraction is independent of the table and can still succeed.
The existing `reports` table requires a clinician, visit and diagnosis and
cannot preserve uploaded documents without fabricating clinical records.

## Proposed correction

Review `2026-10-09_patient_discharge_reports.sql`. It creates exactly one table,
with a signed INT foreign key matching `patients.patient_id`, MEDIUMTEXT source
text, JSON extraction, and a unique `(patient_id, document_reference)` key.
It does not alter existing tables or update any existing patient/staff rows.
The application never executes this migration or calls `create_all()` on Aiven.
No schema change has been applied by this fix.

The owner approved this single table conditional on verified backup/restore.
A full TLS-verified dump succeeded and was restored to isolated MySQL 8.0.46;
all 29 tables matched source row counts and SHA-256 row fingerprints. Aiven is
MySQL 8.4.8. One verification metadata query initially failed because Aiven
uses ANSI_QUOTES; using correctly quoted SQL completed verification. Permission
to resume after that initial failure is pending. Backups and credentials remain
in a private directory outside the repository.

Isolated MySQL tests use the restored schema without production rows and copy
Aiven's SQL mode. Save, retrieve, rollback, concurrent deduplication and patient
ownership pass. The complete PDF round trip passes with mocked Groq. A live
Groq attempt extracted, saved and retrieved successfully, but chat returned
503 (rate limiting). Another live extraction attempt returned 502 validation
failure. These are reported as live failures, not mocked successes.

## Backup and execution, only after explicit approval

Use MySQL 8 client tools, a protected local backup directory outside the repo,
and credentials entered at the password prompt. Substitute the actual host,
port, user, database and existing CA path from your deployment configuration.
Do not put a password in a command or commit backups.

```powershell
mysqldump --host=<host> --port=<port> --user=<user> --password --ssl-mode=VERIFY_IDENTITY --ssl-ca=<ca-path> --single-transaction --routines --triggers --events --no-tablespaces --result-file=<protected-backup-path.sql> <database>
mysql --host=<host> --port=<port> --user=<user> --password --ssl-mode=VERIFY_IDENTITY --ssl-ca=<ca-path> <database>
```

Require a successful dump (exit code 0) and verify restoration in an isolated
database before proceeding. In the MySQL session, first run these read-only
queries on the exact database used by Render:

```sql
SELECT DATABASE();
SHOW CREATE TABLE patients;
SELECT TABLE_NAME, ENGINE FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('patients', 'patient_discharge_reports');
```

After backup validation and approval, use the MySQL `SOURCE` command with the
absolute path to the reviewed SQL file. Verify using `SHOW CREATE TABLE
patient_discharge_reports`. MySQL DDL commits implicitly; do not claim a
transaction can undo it. Do not run the broader staff reconciliation migration.

Redeploy the pushed branch and check `/` for `build_commit`. A newly built APK
adds visible save/retry feedback; provisioning the missing table is essential
for persistence even with the existing APK. Shared database write verification
still requires approval; isolated tests use only fictional records.
