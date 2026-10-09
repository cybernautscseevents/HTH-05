import os
from dotenv import load_dotenv

load_dotenv()

def get_required_env(var_name: str) -> str:
    value = os.getenv(var_name)
    if not value or not value.strip():
        raise RuntimeError(f"Missing required environment variable: {var_name}")
    return value.strip()
