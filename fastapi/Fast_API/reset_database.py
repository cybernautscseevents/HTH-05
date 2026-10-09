import os
import env_config

from database import SessionLocal, engine
from models import User, Staff
from auth import get_password_hash
from sqlalchemy import text

def reset_database():
    doctor_password = os.getenv("INITIAL_DOCTOR_PASSWORD", "8277")
    receptionist_password = os.getenv("INITIAL_RECEPTIONIST_PASSWORD", "3398")

    db = SessionLocal()
    try:
        print("Starting permanent database reset...")

        # 1. Disable Foreign Key Checks for clean truncation
        db.execute(text("SET FOREIGN_KEY_CHECKS = 0;"))

        # 2. Truncate all patient and clinical tables
        patient_tables = [
            "medication_adherence",
            "prescription_items",
            "prescriptions",
            "medical_history",
            "reports",
            "visits",
            "patient_devices",
            "patient_activations",
            "patient_doctor_assignments",
            "appointments",
            "patient_sessions",
            "medicine_schedules",
            "audit_log",
            "patients",
        ]

        for table in patient_tables:
            try:
                db.execute(text(f"TRUNCATE TABLE `{table}`;"))
                print(f"  Truncated table: {table}")
            except Exception as e:
                print(f"  Warning on table {table}: {e}")

        # 3. Clean up staff and users (preserve admin if exists, delete all others)
        admin_user = db.query(User).filter(User.role == "admin").first()
        admin_user_id = admin_user.user_id if admin_user else None

        if admin_user_id:
            db.execute(text(f"DELETE FROM `staff` WHERE `user_id` != {admin_user_id};"))
            db.execute(text(f"DELETE FROM `users` WHERE `user_id` != {admin_user_id};"))
        else:
            db.execute(text("TRUNCATE TABLE `staff`;"))
            db.execute(text("TRUNCATE TABLE `users`;"))

        db.commit()

        # 4. Re-enable Foreign Key Checks
        db.execute(text("SET FOREIGN_KEY_CHECKS = 1;"))
        db.commit()

        print("Clinical data and test accounts wiped.")

        # 5. Ensure Admin exists
        if not admin_user:
            admin_user = User(
                username="admin",
                password_hash=get_password_hash("admin123"),
                role="admin",
                phone="9999999999",
                email="admin@saathi.com",
                active=True,
            )
            db.add(admin_user)
            db.commit()
            db.refresh(admin_user)

            admin_staff = Staff(
                user_id=admin_user.user_id,
                name="System Administrator",
                department="IT",
                specialization="Systems",
            )
            db.add(admin_staff)
            db.commit()
            print("  Created default admin account (username: admin, password: admin123)")

        # 6. Re-create clean Doctor account (doctor1)
        doctor_user = User(
            username="doctor1",
            password_hash=get_password_hash(doctor_password),
            role="doctor",
            phone="9876543210",
            email="doctor@saathi.com",
            active=True,
        )
        db.add(doctor_user)
        db.commit()
        db.refresh(doctor_user)

        doctor_staff = Staff(
            user_id=doctor_user.user_id,
            name="Dr. Meera",
            department="General Medicine",
            specialization="General Physician",
        )
        db.add(doctor_staff)
        db.commit()
        print(f"  Created default doctor account (username: doctor1, password: {doctor_password})")

        # 7. Re-create clean Receptionist account (receptionist1)
        receptionist_user = User(
            username="receptionist1",
            password_hash=get_password_hash(receptionist_password),
            role="receptionist",
            phone="9876543211",
            email="receptionist@saathi.com",
            active=True,
        )
        db.add(receptionist_user)
        db.commit()
        db.refresh(receptionist_user)

        receptionist_staff = Staff(
            user_id=receptionist_user.user_id,
            name="Receptionist",
            department="Reception",
            specialization=None,
        )
        db.add(receptionist_staff)
        db.commit()
        print(f"  Created default receptionist account (username: receptionist1, password: {receptionist_password})")

        # 8. Print final summary table counts
        print("\n--- FINAL DATABASE STATE ---")
        all_tables = [
            "patients",
            "users",
            "staff",
            "visits",
            "reports",
            "prescriptions",
            "prescription_items",
            "medical_history",
            "medication_adherence",
            "patient_devices",
            "patient_activations",
            "patient_doctor_assignments",
            "medicines",
        ]
        for t in all_tables:
            try:
                cnt = db.execute(text(f"SELECT count(*) FROM `{t}`;")).scalar()
                print(f"  {t}: {cnt} records")
            except Exception as e:
                print(f"  {t}: error ({e})")

        print("\nDatabase reset completed successfully!")

    except Exception as ex:
        db.rollback()
        print(f"ERROR during database reset: {ex}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    reset_database()
