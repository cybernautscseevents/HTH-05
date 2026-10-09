
from sqlalchemy import (
    Column,
    Integer,
    BigInteger,
    String,
    Date,
    DateTime,
    Time,
    Boolean,
    ForeignKey,
    Enum,
    UniqueConstraint,
    Text,
    JSON,
)
from sqlalchemy.dialects.mysql import MEDIUMBLOB, MEDIUMTEXT

from database import Base

from datetime import datetime
# =========================================================
# 1. USERS
# =========================================================

class User(Base):
    __tablename__ = "users"

    user_id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    username = Column(
        String(50),
        nullable=False,
        unique=True
    )

    password_hash = Column(
        String(255),
        nullable=False
    )

    # Roles are stored as strings because existing deployments may contain
    # additional staff labels (for example pharmacist or lab_technician).
    # Authorization remains restricted by explicit role allowlists in main.py.
    role = Column(String(30), nullable=False)

    phone = Column(
        String(15),
        nullable=True
    )

    email = Column(
        String(100),
        nullable=True
    )

    active = Column(
        Boolean,
        nullable=False,
        default=True
    )

    created_at = Column(
    DateTime,
    nullable=False,
    default=datetime.now
)

    last_login = Column(
        DateTime,
        nullable=True
    )


# =========================================================
# 2. STAFF
# =========================================================

class Staff(Base):
    __tablename__ = "staff"

    staff_id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    user_id = Column(
        Integer,
        ForeignKey(
            "users.user_id",
            ondelete="CASCADE"
        ),
        nullable=False,
        unique=True
    )

    name = Column(
        String(100),
        nullable=False
    )

    department = Column(
        String(100),
        nullable=True
    )

    specialization = Column(
        String(100),
        nullable=True
    )


# =========================================================
# 3. PATIENTS
# =========================================================

class Patient(Base):
    __tablename__ = "patients"

    patient_id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    user_id = Column(
        Integer,
        ForeignKey(
            "users.user_id",
            ondelete="SET NULL"
        ),
        nullable=True,
        unique=True
    )

    registration_no = Column(
        String(30),
        nullable=False,
        unique=True,
        index=True
    )

    name = Column(
        String(100),
        nullable=False
    )

    date_of_birth = Column(
        Date,
        nullable=True
    )

    photo_url = Column(
        String(500),
        nullable=True
    )

    disease_condition = Column(
        String(255),
        nullable=True
    )

    preferred_language = Column(
        String(30),
        nullable=True,
        default="English"
    )

    emergency_contact = Column(
        String(15),
        nullable=True
    )

    registration_date = Column(
        DateTime,
        nullable=False
    )

    registered_by = Column(
        Integer,
        ForeignKey(
            "staff.staff_id",
            ondelete="SET NULL"
        ),
        nullable=True
    )


# =========================================================
# 4. MEDICAL HISTORY
# =========================================================

class MedicalHistory(Base):
    __tablename__ = "medical_history"

    history_id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    patient_id = Column(
        Integer,
        ForeignKey(
            "patients.patient_id",
            ondelete="CASCADE"
        ),
        nullable=False
    )

    medicine_name = Column(
        String(150),
        nullable=True
    )

    medicine_type = Column(
        String(100),
        nullable=True
    )

    dosage = Column(
        String(100),
        nullable=True
    )

    frequency = Column(
        String(100),
        nullable=True
    )

    start_date = Column(
        Date,
        nullable=True
    )

    end_date = Column(
        Date,
        nullable=True
    )

    reason = Column(
        String(255),
        nullable=True
    )

    notes = Column(
        String(1000),
        nullable=True
    )

    created_at = Column(
    DateTime,
    nullable=False,
    default=datetime.now
)

    created_by = Column(
        Integer,
        ForeignKey(
            "users.user_id",
            ondelete="SET NULL"
        ),
        nullable=True
    )

    visit_id = Column(
        BigInteger,
        ForeignKey(
            "visits.visit_id",
            ondelete="CASCADE"
        ),
        nullable=True
    )

    # =========================================================
# 5. VISITS
# =========================================================

class Visit(Base):
    __tablename__ = "visits"

    visit_id = Column(
        BigInteger,
        primary_key=True,
        index=True
    )

    patient_id = Column(
        Integer,
        ForeignKey(
            "patients.patient_id",
            ondelete="RESTRICT"
        ),
        nullable=False
    )

    doctor_id = Column(
        Integer,
        ForeignKey(
            "staff.staff_id",
            ondelete="RESTRICT"
        ),
        nullable=False
    )
    staff_id = Column(
        Integer,
        ForeignKey(
            "staff.staff_id",
            ondelete="RESTRICT"
        ),
        nullable=False
    )
    visit_date = Column(
        DateTime,
        nullable=False,
        default=datetime.now
    )

    visit_type = Column(
        String(100),
        nullable=True
    )

    assigned_doctor_id = Column(
        Integer,
        ForeignKey("staff.staff_id", ondelete="SET NULL"),
        nullable=True,
    )

    admission_status = Column(
        String(20), nullable=False, default="not_admitted",
        server_default="not_admitted",
    )

    discharge_status = Column(String(20), nullable=True)


    status = Column(
        String(50),
        nullable=False,
        default="completed"
    )

    reason = Column(
        String(500),
        nullable=True
    )

    notes = Column(
        String(2000),
        nullable=True
    )

    temperature = Column(
        String(50),
        nullable=True
    )

    blood_pressure = Column(
        String(50),
        nullable=True
    )

    pulse = Column(
        String(50),
        nullable=True
    )

    spo2 = Column(
        String(50),
        nullable=True
    )

    weight = Column(
        String(50),
        nullable=True
    )

    height = Column(
        String(50),
        nullable=True
    )


    created_at = Column(
        DateTime,
        nullable=False,
        default=datetime.now
    )


# Current doctor ownership is intentionally separate from Visit.doctor_id.
# Visits retain the clinician responsible for that specific consultation.
class PatientDoctorAssignment(Base):
    __tablename__ = "patient_doctor_assignments"

    assignment_id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.patient_id", ondelete="CASCADE"), nullable=False, index=True)
    doctor_id = Column(Integer, ForeignKey("staff.staff_id", ondelete="RESTRICT"), nullable=False, index=True)
    assigned_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    status = Column(Enum("active", "inactive"), nullable=False, default="active", index=True)
    assigned_at = Column(DateTime, nullable=False, default=datetime.now)
    created_at = Column(DateTime, nullable=False, default=datetime.now)
    updated_at = Column(DateTime, nullable=False, default=datetime.now, onupdate=datetime.now)


# A catalogue is deliberately separate from a prescription.  A prescription
# retains the clinician-confirmed display values even if the catalogue changes.
class Medicine(Base):
    __tablename__ = "medicines"

    medicine_id = Column(Integer, primary_key=True, index=True)
    name = Column(String(150), nullable=False, unique=True, index=True)
    generic_name = Column(String(150), nullable=True, index=True)
    brand_name = Column(String(150), nullable=True)
    medicine_type = Column(String(100), nullable=True)
    strength = Column(String(100), nullable=True)
    dosage_form = Column(String(100), nullable=True)
    active = Column(Boolean, nullable=False, default=True, index=True)
    created_at = Column(DateTime, nullable=False, default=datetime.now)


class Prescription(Base):
    __tablename__ = "prescriptions"

    prescription_id = Column(BigInteger, primary_key=True, index=True)
    report_id = Column(BigInteger, ForeignKey("reports.report_id", ondelete="RESTRICT"), nullable=False, index=True)
    patient_id = Column(Integer, ForeignKey("patients.patient_id", ondelete="RESTRICT"), nullable=False, index=True)
    doctor_id = Column(Integer, ForeignKey("staff.staff_id", ondelete="RESTRICT"), nullable=False)
    prescription_notes = Column(String(5000), nullable=True)
    voice_transcript = Column(String(10000), nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.now)


class PrescriptionItem(Base):
    __tablename__ = "prescription_items"

    # The deployed MySQL column uses a fixed ENUM; consultation writes validate
    # against those values instead of attempting a schema migration.
    item_id = Column(BigInteger, primary_key=True, index=True)
    prescription_id = Column(BigInteger, ForeignKey("prescriptions.prescription_id", ondelete="CASCADE"), nullable=False, index=True)
    medicine_id = Column(Integer, ForeignKey("medicines.medicine_id", ondelete="RESTRICT"), nullable=True, index=True)
    medicine_name = Column(String(150), nullable=False)
    medicine_type = Column(String(100), nullable=True)
    dosage = Column(String(100), nullable=False)
    route = Column(String(100), nullable=True)
    duration_days = Column(Integer, nullable=True)
    special_instructions = Column(String(1000), nullable=True)
    frequency = Column(String(100), nullable=True)
    strength = Column(String(100), nullable=True)
    food_timing = Column(String(50), nullable=True)


class MedicineSchedule(Base):
    """Maps to the existing MySQL medicine_schedules table."""
    __tablename__ = "medicine_schedules"

    schedule_id = Column(BigInteger, primary_key=True, index=True)
    item_id = Column(BigInteger, ForeignKey("prescription_items.item_id", ondelete="CASCADE"), nullable=False, index=True)
    time_slot = Column(Time, nullable=False)
    frequency = Column(
        Enum("once_daily", "twice_daily", "three_times_daily", "four_times_daily", "custom"),
        nullable=False,
        default="once_daily",
        server_default="once_daily",
    )
    start_date = Column(Date, nullable=True)
    end_date = Column(Date, nullable=True)
    reminder_enabled = Column(Boolean, nullable=False, default=True, server_default="1")


class Report(Base):
    __tablename__ = "reports"

    report_id = Column(
        BigInteger,
        primary_key=True,
        index=True
    )

    visit_id = Column(
        BigInteger,
        ForeignKey("visits.visit_id", ondelete="RESTRICT"),
        nullable=False
    )

    patient_id = Column(
        Integer,
        ForeignKey("patients.patient_id", ondelete="RESTRICT"),
        nullable=False
    )

    doctor_id = Column(
        Integer,
        ForeignKey("staff.staff_id", ondelete="RESTRICT"),
        nullable=False
    )

    previous_report_id = Column(
        BigInteger,
        ForeignKey("reports.report_id", ondelete="RESTRICT"),
        nullable=True
    )

    version_no = Column(
        Integer,
        nullable=False,
        default=1
    )

    diagnosis = Column(
        String(5000),
        nullable=False
    )

    clinical_notes = Column(
        String(5000),
        nullable=True
    )

    voice_transcript = Column(
        String(10000),
        nullable=True
    )

    report_datetime = Column(
        DateTime,
        nullable=False,
        default=datetime.now
    )

    is_final = Column(
        Boolean,
        nullable=False,
        default=True
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=datetime.now
    )


class PatientDischargeReport(Base):
    """Patient-uploaded report analysis, distinct from clinician-authored reports."""
    __tablename__ = "patient_discharge_reports"
    __table_args__ = (
        UniqueConstraint("patient_id", "document_reference", name="uq_patient_discharge_document"),
    )

    report_id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True, autoincrement=True)
    patient_id = Column(Integer, ForeignKey("patients.patient_id", ondelete="CASCADE"), nullable=False, index=True)
    hospital_name = Column(String(255), nullable=True)
    doctor_name = Column(String(255), nullable=True)
    uploaded_at = Column(DateTime, nullable=False, default=datetime.now)
    original_filename = Column(String(255), nullable=False)
    content_type = Column(String(100), nullable=False)
    document_reference = Column(String(64), nullable=False)
    extracted_text = Column(Text().with_variant(MEDIUMTEXT, "mysql"), nullable=False)
    structured_data = Column(JSON, nullable=False)
    summary = Column(Text, nullable=False)


# =========================================================
# 7. PATIENT DEVICE ACTIVATION
# =========================================================

class PatientDevice(Base):
    __tablename__ = "patient_devices"
    __table_args__ = (
        # This is a staff-selected label, not a globally unique hardware ID.
        UniqueConstraint("patient_id", "device_identifier", name="uq_patient_device_identifier"),
    )

    device_id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.patient_id", ondelete="CASCADE"), nullable=False, index=True)
    device_identifier = Column(String(255), nullable=False)
    status = Column(Enum("pending", "active", "revoked"), nullable=False, default="pending")
    linked_at = Column(DateTime, nullable=True)
    revoked_at = Column(DateTime, nullable=True)


class PatientActivation(Base):
    __tablename__ = "patient_activations"

    activation_id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.patient_id", ondelete="CASCADE"), nullable=False, index=True)
    device_id = Column(Integer, ForeignKey("patient_devices.device_id", ondelete="CASCADE"), nullable=False, index=True)
    code_hash = Column(String(255), nullable=False)
    activation_code = Column(String(255), nullable=True)
    expires_at = Column(DateTime, nullable=False)
    used_at = Column(DateTime, nullable=True)
    created_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.now)


# =========================================================
# 8. MEDICATION ADHERENCE
# =========================================================

class MedicationAdherence(Base):
    __tablename__ = "medication_adherence"
    __table_args__ = (
        UniqueConstraint("patient_id", "prescription_item_id", "scheduled_date", "time_slot", name="uq_patient_item_schedule_slot"),
    )

    adherence_id = Column(BigInteger, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.patient_id", ondelete="CASCADE"), nullable=False, index=True)
    prescription_item_id = Column(BigInteger, ForeignKey("prescription_items.item_id", ondelete="CASCADE"), nullable=False, index=True)
    scheduled_date = Column(Date, nullable=False, index=True)
    time_slot = Column(String(30), nullable=False)
    status = Column(Enum("taken", "snoozed", "skipped"), nullable=False)
    recorded_at = Column(DateTime, nullable=False, default=datetime.now, onupdate=datetime.now)


# =========================================================
# 9. NOTIFICATIONS
# =========================================================

class Notification(Base):
    __tablename__ = "notifications"

    notification_id = Column(Integer, primary_key=True, index=True)
    title = Column(String(150), nullable=False)
    body = Column(Text, nullable=False)
    notification_type = Column(String(50), default="patient_registered")
    target_role = Column(String(30), default="doctor")
    target_user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=True)
    metadata_json = Column(Text, nullable=True)
    is_read = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.now)


class PatientAdmission(Base):
    __tablename__ = "patient_admissions"

    admission_id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.patient_id", ondelete="CASCADE"), nullable=False, index=True)
    visit_id = Column(BigInteger, ForeignKey("visits.visit_id", ondelete="CASCADE"), nullable=False, unique=True)
    ward_type = Column(String(20), nullable=False)
    bed_number = Column(String(30), nullable=False)
    # Nullable for new admissions; these columns are retained for compatibility
    # with earlier builds that briefly accepted uploaded ID documents.
    id_proof_name = Column(String(255), nullable=True)
    id_proof_mime = Column(String(100), nullable=True)
    id_proof_data = Column(MEDIUMBLOB, nullable=True)
    admitted_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    admitted_at = Column(DateTime, nullable=False, default=datetime.now)
    released_at = Column(DateTime, nullable=True)


# =========================================================
# 10. APPOINTMENTS
# =========================================================

class Appointment(Base):
    __tablename__ = "appointments"

    appointment_id = Column(BigInteger, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.patient_id", ondelete="CASCADE"), nullable=False, index=True)
    doctor_id = Column(Integer, ForeignKey("staff.staff_id", ondelete="RESTRICT"), nullable=False, index=True)
    appointment_datetime = Column(DateTime, nullable=False)
    reason = Column(String(255), nullable=True)
    status = Column(Enum("scheduled", "completed", "cancelled", "missed"), nullable=False, default="scheduled", index=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.now)
    created_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)

class AppointmentRescheduleRequest(Base):
    __tablename__ = "appointment_reschedule_requests"
    request_id = Column(BigInteger, primary_key=True, index=True)
    appointment_id = Column(BigInteger, ForeignKey("appointments.appointment_id", ondelete="CASCADE"), nullable=False, index=True)
    patient_id = Column(Integer, ForeignKey("patients.patient_id", ondelete="CASCADE"), nullable=False, index=True)
    preferred_datetime = Column(DateTime, nullable=False)
    reason = Column(String(500), nullable=True)
    status = Column(Enum("pending", "approved", "rejected"), nullable=False, default="pending", index=True)
    created_at = Column(DateTime, nullable=False, default=datetime.now)

