# MEB classroom CA trust

AtlasOS includes the certificate published by the Turkish Ministry of National
Education (MEB) at https://sertifika.meb.gov.tr/MEB_SERTIFIKASI.cer. The
official MEB certificate page is
https://oltu.meb.gov.tr/www/meb-sertifika/icerik/906.

## Pinned certificate identity

- Subject and issuer: DC=tr, DC=gov, DC=mebca, CN=fatihca
- Serial: 61ACD7EC449990BC4301100EEC8CAEDA
- SHA-256 fingerprint: C4:F8:04:D0:93:BA:78:5D:EB:C6:9B:59:17:F2:99:FE:6E:A9:E8:AA:2E:66:83:E8:3F:4D:C9:CD:51:C0:8E:75
- Validity: 2016-03-09 15:36:25 UTC through 2036-03-09 15:46:25 UTC
- Basic constraints: critical CA:TRUE
- Key usage: digital signature, certificate signing, CRL signing
- Source file format: DER X.509 (application/pkix-cert), converted to PEM for
  Debian's /usr/local/share/ca-certificates mechanism.
- SHA-256 of downloaded DER source: c4f804d093ba785debc69b5917f299fe6ea9e8aa2e6683e83f4dc9cd51c08e75

The normal live-build chroot hook runs update-ca-certificates after the
certificate package is installed. Chrome and Qt WebEngine retain ordinary TLS
certificate verification; the OS trust bundle is used for locally installed
root CAs by these Linux clients.

## Security and evidence limits

Installing a root CA makes certificates issued under that authority trusted
system-wide. The certificate was fetched from the official MEB domain with
normal TLS verification, its SHA-256 fingerprint was checked, and its CA
constraints and self-signature were inspected.

This does not prove that a school network's previously observed
MEB-CERT-DSL certificate chains to this FatihCA root. No school-network
certificate chain was available in this task. Do not install any additional
school-specific CA unless its provenance and fingerprint are verified with
the authorized MEB/school IT source. Physical school-wired-network testing
remains necessary.
