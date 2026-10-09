"""Secure Aiven CA certificate loading for local and hosted deployments."""

from __future__ import annotations

import os
import re
import ssl
import tempfile
from collections.abc import Mapping
from pathlib import Path
from tempfile import TemporaryDirectory

from cryptography import x509
from cryptography.x509.oid import ExtensionOID


_CERTIFICATE_BLOCK = re.compile(
    rb"-----BEGIN CERTIFICATE-----\s+.+?\s+-----END CERTIFICATE-----",
    re.DOTALL,
)


def _validate_ca_pem(pem_text: str) -> bytes:
    """Parse every PEM certificate and require at least one CA certificate."""
    if "\x00" in pem_text:
        raise ValueError("NUL byte in certificate")
    if "-----BEGIN CERTIFICATE-----" not in pem_text and "\\n" in pem_text:
        pem_text = pem_text.replace("\\n", "\n")
    pem_bytes = pem_text.encode("ascii")
    blocks = _CERTIFICATE_BLOCK.findall(pem_bytes)
    if not blocks:
        raise ValueError("No PEM certificate found")

    for block in blocks:
        certificate = x509.load_pem_x509_certificate(block)
        try:
            constraints = certificate.extensions.get_extension_for_oid(
                ExtensionOID.BASIC_CONSTRAINTS
            ).value
        except x509.ExtensionNotFound as exc:
            raise ValueError("Certificate has no CA constraints") from exc
        if not constraints.ca:
            raise ValueError("Certificate is not a CA")
    return pem_bytes


def _verified_context(*, cafile: str | None = None, cadata: str | None = None) -> ssl.SSLContext:
    context = ssl.create_default_context(cafile=cafile, cadata=cadata)
    context.verify_mode = ssl.CERT_REQUIRED
    context.check_hostname = True
    return context


def load_aiven_ca(
    environ: Mapping[str, str] | None = None,
) -> tuple[ssl.SSLContext, TemporaryDirectory[str] | None]:
    """Load a verified CA context, using a securely written temporary PEM as fallback.

    An existing ``AIVEN_CA_CERT`` path takes precedence. If the configured path
    is missing, ``AIVEN_CA_CERT_PEM`` and then the legacy ``ca.pem`` variable
    are checked. Returned temporary directories must remain alive for as long
    as connections may use the context.
    """
    values = os.environ if environ is None else environ
    ca_file = values.get("AIVEN_CA_CERT", "").strip()

    if ca_file and Path(ca_file).is_file():
        try:
            _validate_ca_pem(Path(ca_file).read_text(encoding="ascii"))
            context = _verified_context(cafile=ca_file)
        except (OSError, UnicodeError, ValueError, ssl.SSLError) as exc:
            raise RuntimeError("The configured Aiven CA certificate file is invalid.") from exc
        return context, None

    pem_text = values.get("AIVEN_CA_CERT_PEM", "")
    if not pem_text.strip():
        pem_text = values.get("ca.pem", "")
    if pem_text.strip():
        try:
            pem_bytes = _validate_ca_pem(pem_text.strip())
            # Keep the PEM out of logs and use a private, process-owned directory.
            temp_dir = tempfile.TemporaryDirectory(prefix="saathi-aiven-ca-")
            cert_path = Path(temp_dir.name) / "ca.pem"
            fd = os.open(cert_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            try:
                with os.fdopen(fd, "wb") as certificate_file:
                    certificate_file.write(pem_bytes)
                if os.name != "nt":
                    os.chmod(cert_path, 0o600)
                context = _verified_context(cafile=str(cert_path))
            except Exception:
                temp_dir.cleanup()
                raise
        except (OSError, UnicodeError, ValueError, ssl.SSLError) as exc:
            raise RuntimeError(
                "The configured Aiven CA PEM is invalid. Provide a CA certificate in PEM format."
            ) from exc
        return context, temp_dir

    if ca_file:
        raise RuntimeError(
            "AIVEN_CA_CERT does not point to an existing file and no CA PEM fallback is configured. "
            "Set AIVEN_CA_CERT_PEM, add a Render Secret File, or correct the local certificate path."
        )
    raise RuntimeError(
        "Aiven TLS requires an existing AIVEN_CA_CERT file or a valid "
        "AIVEN_CA_CERT_PEM certificate."
    )
