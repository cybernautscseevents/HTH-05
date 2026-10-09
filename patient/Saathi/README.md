# Saathi Care — Phase 1

Phase 1 implements hospital-controlled patient onboarding and device access for the chronic-care application.

## Included

- Patient-first Flutter welcome screen with no self-registration.
- QR scanning and unique-ID + one-time-code fallback.
- Persistent patient device session with no patient-facing logout button.
- Receptionist, doctor, and hospital-management staff login.
- Receptionist/management patient registration and QR generation.
- Management-only linked-device listing, re-linking, and remote logout.
- Immutable audit events for staff login, registration, linking, and revocation.
- FastAPI API with MySQL support and SQLite development fallback.

## Run locally

### Backend (quick SQLite development mode)

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`, with interactive documentation at `/docs`.

### Flutter app

```powershell
cd app
flutter pub get
flutter run
```

Android emulators use `http://10.0.2.2:8000` automatically. For a physical phone, use the computer's LAN address:

```powershell
flutter run --dart-define=API_URL=http://192.168.1.10:8000
```

### MySQL

```powershell
docker compose up -d mysql
Copy-Item backend/.env.example backend/.env
cd backend
uvicorn app.main:app --reload
```

Note: Prototype default credentials are no longer used. Configure passwords using environment variables.

## Security choices

The QR contains a random, short-lived, single-use activation token rather than a password or medical data. Manual linking requires both the patient ID and a six-digit activation code. Device session tokens are stored as SHA-256 digests by the backend and in platform secure storage by the app. A patient device can be logged out only by an authorized management account.

