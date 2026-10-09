import os
import env_config

from database import SessionLocal
from models import User, Staff
from auth import get_password_hash

initial_password = os.getenv("INITIAL_RECEPTIONIST_PASSWORD")
if not initial_password:
    raise RuntimeError(
        "INITIAL_RECEPTIONIST_PASSWORD environment variable is not set. "
        "Please configure INITIAL_RECEPTIONIST_PASSWORD in your environment or .env file."
    )

db = SessionLocal()

try:
    existing_user = (
        db.query(User)
        .filter(User.username == "receptionist1")
        .first()
    )

    if existing_user:
        print("receptionist1 already exists")

    else:
        receptionist_user = User(
            username="receptionist1",
            password_hash=get_password_hash(initial_password),
            role="receptionist",
            phone="9876543211",
            email="receptionist@saathi.com",
            active=True
        )

        db.add(receptionist_user)
        db.commit()
        db.refresh(receptionist_user)

        receptionist_staff = Staff(
            user_id=receptionist_user.user_id,
            name="Receptionist",
            department="Reception",
            specialization=None
        )

        db.add(receptionist_staff)
        db.commit()

        print("Receptionist account created successfully!")
        print("Username: receptionist1")
        print("User ID:", receptionist_user.user_id)

finally:
    db.close()