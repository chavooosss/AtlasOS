import hashlib
import pathlib
import shutil
import ssl
import subprocess
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
CERT = ROOT / "config/includes.chroot/usr/local/share/ca-certificates/atlasos-meb-fatihca.crt"
HOOK = ROOT / "config/hooks/normal/030-atlasos-meb-ca.hook.chroot"
PACKAGES = ROOT / "config/package-lists/atlasos-live.list.chroot"
DOC = ROOT / "docs/security/meb-classroom-ca.md"
EXPECTED_SHA256 = "c4f804d093ba785debc69b5917f299fe6ea9e8aa2e6683e83f4dc9cd51c08e75"


class MebCertificateIntegrationTests(unittest.TestCase):
    def test_published_root_fingerprint_and_x509_constraints(self):
        self.assertTrue(CERT.is_file())
        pem = CERT.read_text(encoding="ascii")
        der = ssl.PEM_cert_to_DER_cert(pem)
        self.assertEqual(hashlib.sha256(der).hexdigest(), EXPECTED_SHA256)
        self.assertTrue(shutil.which("openssl"), "openssl is required for X.509 metadata checks")
        result = subprocess.run(
            ["openssl", "x509", "-in", str(CERT), "-noout", "-subject", "-issuer",
             "-serial", "-dates"],
            text=True, capture_output=True, check=True,
        )
        output = result.stdout
        self.assertIn("CN=fatihca", output)
        self.assertIn("serial=61ACD7EC449990BC4301100EEC8CAEDA", output)
        constraints = subprocess.run(
            ["openssl", "x509", "-in", str(CERT), "-noout", "-ext", "basicConstraints"],
            text=True, capture_output=True, check=True,
        )
        self.assertIn("CA:TRUE", constraints.stdout)
        usage = subprocess.run(
            ["openssl", "x509", "-in", str(CERT), "-noout", "-ext", "keyUsage"],
            text=True, capture_output=True, check=True,
        )
        self.assertIn("Certificate Sign", usage.stdout)
        verify = subprocess.run(
            ["openssl", "verify", "-check_ss_sig", "-CAfile", str(CERT), str(CERT)],
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(verify.returncode, 0, verify.stderr)

    def test_live_image_installs_system_ca_bundle_and_keeps_tls_verification(self):
        self.assertIn("ca-certificates", PACKAGES.read_text(encoding="utf-8").splitlines())
        hook = HOOK.read_text(encoding="utf-8")
        self.assertIn("/usr/local/share/ca-certificates/atlasos-meb-fatihca.crt", hook)
        self.assertIn("update-ca-certificates", hook)
        self.assertNotIn("--ignore-certificate-errors", hook)
        self.assertNotIn("curl -k", hook)

    def test_documentation_does_not_claim_school_chain_is_proven(self):
        doc = DOC.read_text(encoding="utf-8")
        self.assertIn("MEB-CERT-DSL", doc)
        self.assertIn("does not prove", doc)
        self.assertIn(EXPECTED_SHA256, doc)


if __name__ == "__main__":
    unittest.main()
