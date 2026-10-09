import os
import env_config

from database import SessionLocal
from models import User, Staff
from auth import get_password_hash

initial_password = os.getenv("INITIAL_DOCTOR_PASSWORD")
if not initial_password:
    raise RuntimeError(
        "INITIAL_DOCTOR_PASSWORD environment variable is not set. "
        "Please configure INITIAL_DOCTOR_PASSWORD in your environment or .env file."
    )

db = SessionLocal()

try:
    # Check if doctor already exists
    existing_user = (
        db.query(User)
        .filter(User.username == "doctor1")
        .first()
    )

    if existing_user:
        print("doctor1 already exists")
    else:
        # Create user
        doctor_user = User(
            username="doctor1",
            password_hash=get_password_hash(initial_password),
            role="doctor",
            phone="9876543210",
            email="doctor@saathi.com",
            active=True
        )

        db.add(doctor_user)
        db.commit()
        db.refresh(doctor_user)

        # Create staff record
        doctor_staff = Staff(
            user_id=doctor_user.user_id,
            name="Dr. Meera",
            department="General Medicine",
            specialization="General Physician"
        )

        db.add(doctor_staff)
        db.commit()

        print("Doctor account created successfully!")
        print("Username: doctor1")
        print("User ID:", doctor_user.user_id)

finally:
    db.close()