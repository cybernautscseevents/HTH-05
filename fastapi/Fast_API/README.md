# Saathi – Healthcare Management System

Saathi is a healthcare management system designed to help doctors and receptionists manage patient information, medical history, visits, and doctor reports through a secure web-based API.

## 🚀 Features

### 👤 Patient Management
- Register new patients
- Generate unique patient registration numbers
- Search patients by:
  - Name
  - Registration number
  - Disease/condition
- View patient details

### 🏥 Medical History
- Add patient's medical history
- Store:
  - Medicine name
  - Medicine type
  - Dosage
  - Frequency
  - Start date
  - End date
  - Reason
  - Notes
- Doctors can view patient medical history

### 👨‍⚕️ Doctor Management
- Secure doctor login
- JWT-based authentication
- Doctors can:
  - View patients
  - Create visits
  - Create medical reports
  - View previous reports
  - View medical history

### 👩‍💼 Receptionist Management
- Secure receptionist login
- Search patients
- View patient details
- Register patients
- Restricted access to medical information

### 📋 Doctor Reports
- Create diagnosis reports
- Add clinical notes
- Store voice transcripts
- Track report versions
- Associate reports with patients, visits, and doctors

## 🔐 Authentication

Saathi uses JWT (JSON Web Token) authentication.

User roles include:

- Doctor
- Receptionist
- Patient
- Admin



## 🛠️ Technologies Used

### Backend
- Python
- FastAPI
- SQLAlchemy
- MySQL
- PyMySQL
- Pydantic
- JWT Authentication
- Passlib
- Bcrypt

### Database configuration and deployment

For local development, set `DATABASE_URL` in the backend `.env` file. For Aiven, set `AIVEN_DB_PASSWORD` and optionally override `AIVEN_DB_HOST`, `AIVEN_DB_PORT`, `AIVEN_DB_NAME`, and `AIVEN_DB_USER`; the defaults target this project's Aiven service. Set `AIVEN_CA_CERT` to the path of the Aiven CA certificate. Aiven connections validate the server certificate against that CA and check the hostname. Passwords are passed separately to SQLAlchemy, so punctuation does not need URL escaping. When `AIVEN_DB_PASSWORD` is set, Aiven settings take precedence over `DATABASE_URL`.

On Render, configure these values in the backend service's environment settings and provide the CA certificate as a secret file, with `AIVEN_CA_CERT` set to its mounted path. Do not put the password or certificate in the repository or a committed environment file.

Application startup performs only a read-only `SELECT 1` connection check. It does not create tables, apply schema changes, or seed accounts. This checkout has no Alembic configuration or migration history, so compare the deployed schema with the ORM and review any changes before applying them manually. Back up Aiven before any approved schema or data import operation.

### 🔌 API Contract & Access Control

The API enforces strict role-based access control (RBAC) and patient-level ownership checks:

| Endpoint | Method | Allowed Roles | Access Level / Rules |
|---|---|---|---|
| `/patients/{patient_id}/visits` | GET | `admin`, `doctor`, `patient` | **Doctor/Admin:** Can read any patient's visits.<br>**Patient:** Can ONLY read their own visits. Cross-patient requests return **403 Forbidden**. |
| `/patients/{patient_id}/reports` | GET | `admin`, `doctor`, `patient` | **Doctor/Admin:** Can read any patient's reports.<br>**Patient:** Can ONLY read their own reports. Cross-patient requests return **403 Forbidden**. |
| `/patients/{patient_id}/medical-history` | GET | `admin`, `doctor`, `patient` | **Doctor/Admin:** Can read any patient's medical history.<br>**Patient:** Can ONLY read their own medical history. Cross-patient requests return **403 Forbidden**. |
| `/patients/me/discharge-summary` | POST (multipart `file`) | `patient` | Analyzes a PDF, JPG, or PNG in memory and returns structured extraction, source metadata, and a patient-friendly summary for review. |
| `/patients/me/discharge-reports` | GET | `patient` | Lists only the authenticated patient's saved discharge reports. |
| `/patients/me/discharge-reports` | POST (JSON) | `patient` | Saves an analyzed report to the authenticated patient's record; repeated uploads with the same SHA-256 document reference are deduplicated. |
| `/patients/me/discharge-chat` | POST (JSON with `report_id`) | `patient` | Answers a question using only the selected saved report and returns the report source. Cross-patient report IDs are rejected. |

### Discharge document summaries

The patient discharge-analysis endpoints use GroqCloud. Set `GROQ_API_KEY` on the backend and optionally select a model with `GROQ_MODEL`. PDFs with embedded text are extracted by `pypdf`; scanned PDFs require the configured OCR packages and Tesseract binary. Uploads are limited to 12 MB and PDFs to 30 pages. Document text is sent to Groq for analysis, so deployers must configure an appropriate data-processing arrangement before using this with real patient records.

### Admission and discharge workflow

`GENERAL_WARD_BED_COUNT` and `SPECIAL_WARD_BED_COUNT` set the regular numbered beds shown in stored admission records. Admission is not blocked when those counts are zero or all numbered beds are occupied: the API assigns the next numbered bed in that ward. Receptionists can record admission only after the latest completed doctor visit is marked admitted. The discharge summary is available when that visit is marked discharged and its report is final.

---

## 📁 Project Structure

```text
Saathi/
│
├── main.py
├── models.py
├── schemas.py
├── database.py
├── auth.py
│
├── create_doctor.py
├── create_receptionist.py
│
├── requirements.txt
│
└── README.md


## Patient discharge document analysis (GroqCloud)

The patient app posts an authenticated PDF/image to `/patients/me/discharge-summary`. PDF text is extracted with `pypdf`; scanned-image OCR uses the existing optional Pillow/Tesseract path. Analysis uses the official Groq Python SDK and returns validated structured JSON, source metadata, and a patient-friendly summary. Configure `GROQ_API_KEY` and optionally `GROQ_MODEL` in the backend environment; the default is `openai/gpt-oss-20b`. The API key must never be added to Flutter configuration. Install the complete API dependencies with `pip install -r requirements.txt` (or only the AI/PDF additions with `pip install -r requirements-ai.txt`).

The patient reviews an extraction before saving it. Saving stores the extracted report text, structured fields, original filename, MIME type, upload time, hospital/doctor details, and SHA-256 document reference in `patient_discharge_reports`. The original binary is not retained. The patient app lists these saved reports in Prescriptions, Medicines, Appointments, Health Summary, and the report-grounded AI chat. Extracted report instructions remain attributed to the uploaded source; they do not automatically book an appointment or activate medicine reminders. Kannada explanations are generated through the same report-grounded chat endpoint.

Before deployment, review and apply `migrations/2026-10-09_patient_discharge_reports.sql` against a backup of the target database. The migration has not been run as part of this change. Do not use `Base.metadata.create_all()` against a deployed database. AI results must be reviewed by a qualified clinician and do not replace medical advice.
