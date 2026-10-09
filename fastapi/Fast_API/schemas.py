from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from datetime import date, datetime, time
import re


# =========================================================
# 1. PATIENT CREATE / UPDATE
# =========================================================

class PatientCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    date_of_birth: Optional[date] = None
    photo_url: Optional[str] = None
    disease_condition: Optional[str] = None
    preferred_language: str = "English"
    emergency_contact: Optional[str] = None
    assigned_doctor_id: Optional[int] = None

    @field_validator("name")
    def validate_name(cls, v):
        trimmed = v.strip()
        if len(trimmed) < 2:
            raise ValueError("Patient full name must be at least 2 characters")
        return trimmed

    @field_validator("emergency_contact")
    def validate_phone(cls, v):
        if not v:
            return v
        digits = "".join(filter(str.isdigit, v))
        if len(digits) != 10:
            raise ValueError("Phone number must be exactly 10 digits")
        return digits

    @field_validator("date_of_birth")
    def validate_dob(cls, v):
        if v and v > date.today():
            raise ValueError("Date of birth cannot be in the future")
        return v


class DoctorAssignmentCreate(BaseModel):
    doctor_id: int = Field(gt=0)


# =========================================================
# 2. MEDICAL HISTORY CREATE
# =========================================================

class MedicalHistoryCreate(BaseModel):
    medicine_name: Optional[str] = None
    medicine_type: Optional[str] = None
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    reason: Optional[str] = None
    notes: Optional[str] = None
    created_by: Optional[int] = None
    visit_id: Optional[int] = None


# =========================================================
# 3. STAFF CREATE / UPDATE / STATUS
# =========================================================

class StaffCreate(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=8, max_length=128)
    role: str
    name: str = Field(min_length=2, max_length=100)
    department: Optional[str] = None
    specialization: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None

    @field_validator("username")
    def validate_username(cls, v):
        trimmed = v.strip()
        if not re.match(r"^[a-zA-Z0-9._-]+$", trimmed):
            raise ValueError("Username can only contain letters, numbers, dots, hyphens, and underscores")
        return trimmed

    @field_validator("role")
    def validate_role(cls, v):
        if v not in {"doctor", "receptionist", "admin"}:
            raise ValueError("Role must be doctor, receptionist, or admin")
        return v

    @field_validator("phone")
    def validate_phone(cls, v):
        if not v:
            return v
        digits = "".join(filter(str.isdigit, v))
        if len(digits) != 10:
            raise ValueError("Phone number must be exactly 10 digits")
        return digits

    @field_validator("email")
    def validate_email(cls, v):
        if not v:
            return v
        email_regex = r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$"
        if not re.match(email_regex, v.strip()):
            raise ValueError("Enter a valid email address")
        return v.strip().lower()


class StaffUpdate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    department: Optional[str] = None
    specialization: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    role: Optional[str] = None

    @field_validator("phone")
    def validate_phone(cls, v):
        if not v:
            return v
        digits = "".join(filter(str.isdigit, v))
        if len(digits) != 10:
            raise ValueError("Phone number must be exactly 10 digits")
        return digits

    @field_validator("email")
    def validate_email(cls, v):
        if not v:
            return v
        email_regex = r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$"
        if not re.match(email_regex, v.strip()):
            raise ValueError("Enter a valid email address")
        return v.strip().lower()


class StaffStatusUpdate(BaseModel):
    active: bool


class StaffPasswordUpdate(BaseModel):
    new_password: str = Field(min_length=6, max_length=128)


# =========================================================
# 4. DEVICE ACTIVATION
# =========================================================

class ActivationCreate(BaseModel):
    device_identifier: str = Field(min_length=3, max_length=255)
    expires_in_minutes: int = Field(default=30, ge=1, le=1440)


class DeviceActivate(BaseModel):
    patient_id: Optional[int] = None
    registration_no: Optional[str] = None
    device_identifier: Optional[str] = "Patient Primary Device"
    activation_code: str = Field(min_length=4, max_length=128)


# =========================================================
# 5. VISIT & CONSULTATION CREATE
# =========================================================

class VisitCreate(BaseModel):
    visit_type: Optional[str] = "consultation"
    reason: Optional[str] = None
    notes: Optional[str] = None
    temperature: Optional[str] = None
    blood_pressure: Optional[str] = None
    pulse: Optional[str] = None
    spo2: Optional[str] = None
    weight: Optional[str] = None
    height: Optional[str] = None


class ReportCreate(BaseModel):
    visit_id: int
    diagnosis: str = Field(min_length=1)
    clinical_notes: Optional[str] = None
    voice_transcript: Optional[str] = None
    is_final: bool = True


class PrescriptionItemCreate(BaseModel):
    medicine_id: Optional[int] = None
    medicine_name: str = Field(min_length=1, max_length=150)
    generic_name: Optional[str] = None
    medicine_type: Optional[str] = None
    strength: Optional[str] = None
    dosage: Optional[str] = "1 tablet"
    frequency: Optional[str] = "Once daily"
    duration: Optional[str] = "5 days"
    route: Optional[str] = None
    instructions: Optional[str] = None
    food_timing: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    reminder_times: List[time] = Field(default_factory=list, max_length=16)

    @field_validator("duration")
    def validate_duration(cls, v):
        if not v:
            return "5 days"
        digits = "".join(filter(str.isdigit, v))
        if not digits or int(digits) <= 0:
            return "5 days"
        return v


class MedicineCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    generic_name: Optional[str] = None
    brand_name: Optional[str] = None
    medicine_type: Optional[str] = None
    strength: Optional[str] = None
    dosage_form: Optional[str] = None

    @field_validator("name")
    def validate_name(cls, v):
        trimmed = v.strip()
        if not trimmed:
            raise ValueError("Medicine name cannot be empty")
        return trimmed


class VoiceExtractionRequest(BaseModel):
    transcript: str = Field(min_length=3, max_length=10000)


class ConsultationCreate(BaseModel):
    visit_type: Optional[str] = "consultation"
    admission_status: str = Field(default="not_admitted", pattern="^(admitted|not_admitted)$")
    discharge_status: Optional[str] = Field(default=None, pattern="^(discharged|not_discharged)$")
    assigned_doctor_id: Optional[int] = Field(default=None, gt=0)
    reason: Optional[str] = Field(default=None, max_length=500)
    notes: Optional[str] = Field(default=None, max_length=2000)
    temperature: Optional[str] = None
    blood_pressure: Optional[str] = None
    pulse: Optional[str] = None
    spo2: Optional[str] = None
    weight: Optional[str] = None
    height: Optional[str] = None

    diagnosis: str = Field(min_length=1, max_length=5000)
    clinical_notes: Optional[str] = Field(default=None, max_length=5000)
    voice_transcript: Optional[str] = Field(default=None, max_length=10000)
    is_final: bool = True

    medicines: List[PrescriptionItemCreate] = []

    @field_validator("diagnosis")
    def validate_diagnosis(cls, v):
        if not v or not v.strip():
            raise ValueError("Diagnosis is required for consultation")
        return v.strip()


# =========================================================
# 6. MEDICATION ADHERENCE
# =========================================================

class AdherenceRecordCreate(BaseModel):
    prescription_item_id: int = Field(gt=0)
    scheduled_date: date
    time_slot: str = Field(pattern=r"^(morning|afternoon|evening|night)$")
    status: str = Field(pattern=r"^(taken|snoozed|skipped)$")


class PatientDischargeReportSave(BaseModel):
    original_filename: str = Field(min_length=1, max_length=255)
    content_type: str = Field(pattern=r"^(application/pdf|image/jpeg|image/png)$")
    document_reference: str = Field(pattern=r"^[a-f0-9]{64}$")
    extracted_text: str = Field(min_length=40, max_length=60000)
    structured_data: dict
    summary: str = Field(min_length=1, max_length=8000)
    hospital_name: str | None = Field(default=None, max_length=255)
    doctor_name: str | None = Field(default=None, max_length=255)


class PatientDischargeChatRequest(BaseModel):
    report_id: int = Field(gt=0)
    question: str = Field(min_length=1, max_length=1000)
    language: str = Field(default="English", pattern=r"^(English|Kannada)$")


# =========================================================
# 7. APPOINTMENTS
# =========================================================

class AppointmentCreate(BaseModel):
    appointment_datetime: str
    reason: Optional[str] = Field(default=None, max_length=255)
    notes: Optional[str] = Field(default=None, max_length=2000)
    doctor_id: Optional[int] = None

class AppointmentRescheduleCreate(BaseModel):
    preferred_datetime: datetime
    reason: Optional[str] = Field(default=None, max_length=500)
