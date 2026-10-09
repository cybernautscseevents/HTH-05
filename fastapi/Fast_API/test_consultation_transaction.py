"""Isolated SQLite regression tests for the consultation persistence flow."""
import unittest
from datetime import date, datetime, time

from fastapi import HTTPException
from sqlalchemy import Integer, create_engine, text
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

import main
from database import Base
from models import (
    Medicine,
    MedicineSchedule,
    Patient,
    PatientDoctorAssignment,
    Prescription,
    PrescriptionItem,
    Report,
    Staff,
    User,
    Visit,
)
from schemas import ConsultationCreate, ReportCreate, VisitCreate


class ConsultationTransactionTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        # Emulate the existing Aiven visits shape, which lacks the three columns
        # in the newer Visit ORM mapping.
        with self.engine.begin() as connection:
            connection.execute(text("""
                CREATE TABLE visits (
                    visit_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    patient_id INTEGER NOT NULL,
                    doctor_id INTEGER NULL,
                    staff_id INTEGER NOT NULL,
                    visit_date DATETIME NOT NULL,
                    reason VARCHAR(255),
                    status VARCHAR(50) NOT NULL,
                    notes TEXT,
                    visit_type VARCHAR(100) NOT NULL DEFAULT 'consultation',
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    temperature VARCHAR(50), blood_pressure VARCHAR(50),
                    pulse VARCHAR(50), spo2 VARCHAR(50), weight VARCHAR(50), height VARCHAR(50)
                )
            """))

        table_names = [
            "users", "staff", "patients", "patient_doctor_assignments", "medicines",
            "reports", "prescriptions", "prescription_items", "medicine_schedules", "notifications",
        ]
        selected_tables = [Base.metadata.tables[name] for name in table_names]
        for table in selected_tables:
            for column in table.columns:
                if column.type.__class__.__name__ == "BigInteger":
                    column.type = Integer()
        Base.metadata.create_all(self.engine, tables=selected_tables)

        self.db = Session(self.engine)
        self.db.add_all([
            User(user_id=1, username="demo-doctor", password_hash="test", role="doctor", active=True),
            User(user_id=2, username="demo-patient", password_hash="test", role="patient", active=True),
        ])
        self.db.flush()
        self.db.add(Staff(staff_id=1, user_id=1, name="Dr Fictional"))
        self.db.add(Patient(
            patient_id=49, user_id=2, registration_no="DEMO-49", name="Fictional Patient",
            registration_date=datetime(2026, 10, 9), preferred_language="English",
        ))
        self.db.add(Patient(
            patient_id=50, user_id=None, registration_no="DEMO-50", name="Other Fictional Patient",
            registration_date=datetime(2026, 10, 9), preferred_language="English",
        ))
        self.db.flush()
        self.db.add(PatientDoctorAssignment(
            patient_id=49, doctor_id=1, assigned_by=1, status="active",
        ))
        self.db.add(Medicine(
            medicine_id=1, name="Dolo 650", generic_name="Paracetamol",
            medicine_type="tablet", strength="650 mg", active=True,
        ))
        self.db.commit()

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(self.engine, tables=[
            Base.metadata.tables[name] for name in [
                "users", "staff", "patients", "patient_doctor_assignments", "medicines",
                "reports", "prescriptions", "prescription_items", "medicine_schedules", "notifications",
            ]
        ])
        with self.engine.begin() as connection:
            connection.execute(text("DROP TABLE visits"))
        self.engine.dispose()

    @staticmethod
    def consultation_data():
        return ConsultationCreate.model_validate({
            "visit_type": "consultation",
            "reason": "fever",
            "diagnosis": "Synthetic viral fever",
            "clinical_notes": "Fictional demo details",
            "medicines": [{
                "medicine_id": 1,
                "medicine_name": "Dolo 650",
                "medicine_type": "Tablet",
                "strength": "650 mg",
                "dosage": "1 tablet",
                "frequency": "2x daily (08:00 AM, 08:00 PM)",
                "duration": "6 days",
                "instructions": "After food",
                "food_timing": "After Food",
                "start_date": "2026-10-09",
                "end_date": "2026-10-14",
                "reminder_times": ["08:00:00", "20:00:00"],
            }],
        })

    def test_visits_load_save_reopen_and_patient_prescription_read(self):
        patient_user = {"user_id": 2, "role": "patient", "patient_id": 49}
        self.assertEqual(main.list_visits(49, self.db, patient_user), [])

        result = main.create_consultation(
            49, self.consultation_data(), self.db,
            {"user_id": 1, "role": "doctor"},
        )
        self.assertTrue(result["success"])
        visits = main.list_visits(49, self.db, patient_user)
        self.assertEqual(len(visits), 1)
        self.assertEqual(visits[0]["visit_id"], result["visit_id"])
        self.assertEqual(visits[0]["admission_status"], "not_admitted")

        records = main.patient_clinical_records(49, self.db, patient_user)
        saved = records["visits"][0]["prescription"]["items"][0]
        self.assertEqual(saved["medicine_name"], "Dolo 650")
        self.assertEqual(saved["dosage"], "1 tablet")
        self.assertEqual(saved["instructions"], "After food")
        self.assertEqual(saved["food_timing"], "After Food")
        self.assertEqual(saved["start_date"], "2026-10-09")
        self.assertEqual(saved["end_date"], "2026-10-14")
        self.assertEqual(saved["reminder_times"], ["08:00:00", "20:00:00"])
        self.assertEqual(self.db.query(Report).count(), 1)
        self.assertEqual(self.db.query(Prescription).count(), 1)
        self.assertEqual(self.db.query(PrescriptionItem).count(), 1)
        self.assertEqual(self.db.query(MedicineSchedule).count(), 2)
        schedules = self.db.query(MedicineSchedule).order_by(MedicineSchedule.time_slot).all()
        self.assertEqual([schedule.time_slot for schedule in schedules], [time(8), time(20)])
        self.assertEqual([schedule.start_date for schedule in schedules], [date(2026, 10, 9)] * 2)
        self.assertEqual([schedule.end_date for schedule in schedules], [date(2026, 10, 14)] * 2)

    def test_legacy_orm_operations_reproduce_both_unknown_column_failures(self):
        # The old GET /visits ORM entity query selected every mapped column.
        with self.assertRaises(OperationalError) as get_failure:
            self.db.query(Visit).first()
        self.assertIn("assigned_doctor_id", str(get_failure.exception))
        self.db.rollback()

        # The old consultation ORM insert likewise named the absent columns.
        self.db.add(Visit(
            patient_id=49, doctor_id=1, staff_id=1,
            admission_status="not_admitted", assigned_doctor_id=None,
            discharge_status=None, status="completed", visit_type="consultation",
        ))
        with self.assertRaises(OperationalError) as post_failure:
            self.db.flush()
        self.assertTrue(any(
            missing in str(post_failure.exception)
            for missing in ("assigned_doctor_id", "admission_status", "discharge_status")
        ))
        self.db.rollback()

    def test_database_failure_rolls_back_every_consultation_write(self):
        with self.engine.begin() as connection:
            connection.execute(text("""
                CREATE TRIGGER fail_reminder_insert BEFORE INSERT ON medicine_schedules
                BEGIN SELECT RAISE(ABORT, 'synthetic schedule failure'); END
            """))
        with self.assertRaises(HTTPException) as failure:
            main.create_consultation(
                49, self.consultation_data(), self.db,
                {"user_id": 1, "role": "doctor"},
            )
        self.assertEqual(failure.exception.status_code, 500)
        self.assertEqual(self.db.query(Visit.visit_id).count(), 0)
        self.assertEqual(self.db.query(Report.report_id).count(), 0)
        self.assertEqual(self.db.query(Prescription.prescription_id).count(), 0)
        self.assertEqual(self.db.query(PrescriptionItem.item_id).count(), 0)
        self.assertEqual(self.db.query(MedicineSchedule.schedule_id).count(), 0)

    def test_status_fields_without_schema_are_rejected_before_write(self):
        data = self.consultation_data().model_copy(update={"discharge_status": "not_discharged"})
        with self.assertRaises(HTTPException) as failure:
            main.create_consultation(49, data, self.db, {"user_id": 1, "role": "doctor"})
        self.assertEqual(failure.exception.status_code, 409)
        self.assertEqual(self.db.query(Visit.visit_id).count(), 0)

    def test_visit_specific_assignment_without_schema_is_not_silently_downgraded(self):
        data = self.consultation_data().model_copy(update={"assigned_doctor_id": 2})
        with self.assertRaises(HTTPException) as failure:
            main.create_consultation(49, data, self.db, {"user_id": 1, "role": "doctor"})
        self.assertEqual(failure.exception.status_code, 409)
        self.assertEqual(self.db.query(Visit.visit_id).count(), 0)

    def test_patient_cannot_read_another_patients_consultation(self):
        with self.assertRaises(HTTPException) as failure:
            main.patient_clinical_records(
                50, self.db, {"user_id": 2, "role": "patient", "patient_id": 49},
            )
        self.assertEqual(failure.exception.status_code, 403)

    def test_existing_doctor_report_and_receptionist_visit_paths_still_work(self):
        doctor = {"user_id": 1, "role": "doctor"}
        created = main.create_visit(
            49, VisitCreate(visit_type="consultation", reason="checkup"), self.db, doctor,
        )
        saved_report = main.create_report(
            49, ReportCreate(visit_id=created["visit_id"], diagnosis="Fictional diagnosis"),
            self.db, doctor,
        )
        self.assertEqual(saved_report["visit_id"], created["visit_id"])
        receptionist_visits = main.list_visits(
            49, self.db, {"user_id": 3, "role": "receptionist"},
        )
        self.assertEqual(len(receptionist_visits), 1)


if __name__ == "__main__":
    unittest.main()
