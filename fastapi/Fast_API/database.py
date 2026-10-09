import os
import ssl

from sqlalchemy import create_engine
from sqlalchemy.engine import URL, make_url
from sqlalchemy.orm import declarative_base, sessionmaker

from env_config import get_required_env


def _database_url() -> tuple[URL, dict[str, object]]:
    """Build an encoded URL and CA-verified TLS options for Aiven."""
    aiven_password = os.getenv("AIVEN_DB_PASSWORD")
    if aiven_password:
        url = URL.create(
            drivername="mysql+pymysql",
            username=os.getenv("AIVEN_DB_USER", "avnadmin"),
            password=aiven_password,
            host=os.getenv(
                "AIVEN_DB_HOST",
                "project-mysql-kritharthjain6-e607.c.aivencloud.com",
            ),
            port=int(os.getenv("AIVEN_DB_PORT", "18310")),
            database=os.getenv("AIVEN_DB_NAME", "defaultdb"),
        )
    else:
        url = make_url(get_required_env("DATABASE_URL"))

    connect_args: dict[str, object] = {}
    if url.host and url.host.lower().endswith(".aivencloud.com"):
        ca_file = os.getenv("AIVEN_CA_CERT")
        if not ca_file:
            raise RuntimeError("AIVEN_CA_CERT is required for verified Aiven TLS.")
        if not os.path.isfile(ca_file):
            raise RuntimeError("The configured Aiven CA certificate file does not exist.")
        tls_context = ssl.create_default_context()
        tls_context.load_verify_locations(cafile=ca_file)
        tls_context.verify_mode = ssl.CERT_REQUIRED
        tls_context.check_hostname = True
        connect_args["ssl"] = tls_context

    return url, connect_args


DATABASE_URL, _connect_args = _database_url()
engine = create_engine(
    DATABASE_URL,
    connect_args=_connect_args,
    pool_pre_ping=True,
    hide_parameters=True,
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
