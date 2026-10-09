import os
import ssl
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

from aiven_tls import load_aiven_ca


def make_ca_pem(common_name: str = "Saathi test CA") -> bytes:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, common_name)])
    now = datetime.now(timezone.utc)
    certificate = (
        x509.CertificateBuilder()
        .subject_name(name)
        .issuer_name(name)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(minutes=1))
        .not_valid_after(now + timedelta(days=30))
        .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
        .sign(key, hashes.SHA256())
    )
    return certificate.public_bytes(serialization.Encoding.PEM)


class AivenTlsTests(unittest.TestCase):
    def setUp(self):
        self.ca_one = make_ca_pem("First CA").decode("ascii")
        self.ca_two = make_ca_pem("Fallback CA").decode("ascii")
        self.temp_dirs = []

    def tearDown(self):
        for directory in self.temp_dirs:
            directory.cleanup()

    def load(self, env):
        context, directory = load_aiven_ca(env)
        if directory is not None:
            self.temp_dirs.append(directory)
        return context, directory

    def assert_verified(self, context):
        self.assertEqual(context.verify_mode, ssl.CERT_REQUIRED)
        self.assertTrue(context.check_hostname)

    def test_existing_certificate_file_is_used_before_pem_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ca.pem"
            path.write_text(self.ca_one, encoding="ascii")
            context, temp_dir = self.load(
                {"AIVEN_CA_CERT": str(path), "AIVEN_CA_CERT_PEM": self.ca_two}
            )
        self.assertIsNone(temp_dir)
        self.assert_verified(context)
        subjects = {cert["subject"][0][0][1] for cert in context.get_ca_certs()}
        self.assertIn("First CA", subjects)
        self.assertNotIn("Fallback CA", subjects)

    def test_missing_certificate_path_without_fallback_fails_clearly(self):
        with self.assertRaisesRegex(RuntimeError, "does not point to an existing file"):
            load_aiven_ca({"AIVEN_CA_CERT": "C:/missing/ca.pem"})

    def test_missing_path_falls_back_to_pem_and_restricts_file_permissions(self):
        context, directory = self.load(
            {"AIVEN_CA_CERT": "/missing/ca.pem", "AIVEN_CA_CERT_PEM": self.ca_one}
        )
        self.assertIsNotNone(directory)
        cert_path = Path(directory.name) / "ca.pem"
        self.assertTrue(cert_path.is_file())
        if os.name != "nt":
            self.assertEqual(cert_path.stat().st_mode & 0o777, 0o600)
        self.assert_verified(context)

    def test_pem_text_works_without_a_file_path(self):
        context, directory = self.load({"AIVEN_CA_CERT_PEM": self.ca_one})
        self.assertIsNotNone(directory)
        self.assert_verified(context)

    def test_legacy_ca_pem_environment_variable_is_supported(self):
        context, directory = self.load({"ca.pem": self.ca_one})
        self.assertIsNotNone(directory)
        self.assert_verified(context)

    def test_malformed_pem_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "PEM is invalid"):
            load_aiven_ca({"AIVEN_CA_CERT_PEM": "not a certificate"})

    def test_non_ca_certificate_is_rejected(self):
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Not a CA")])
        now = datetime.now(timezone.utc)
        cert = (
            x509.CertificateBuilder()
            .subject_name(name)
            .issuer_name(name)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now - timedelta(minutes=1))
            .not_valid_after(now + timedelta(days=30))
            .sign(key, hashes.SHA256())
        )
        with self.assertRaisesRegex(RuntimeError, "PEM is invalid"):
            load_aiven_ca(
                {"AIVEN_CA_CERT_PEM": cert.public_bytes(serialization.Encoding.PEM).decode()}
            )

    def test_no_certificate_configuration_fails_clearly(self):
        with self.assertRaisesRegex(RuntimeError, "requires an existing"):
            load_aiven_ca({})


if __name__ == "__main__":
    unittest.main()
