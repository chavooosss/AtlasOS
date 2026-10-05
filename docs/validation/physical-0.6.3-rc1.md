# AtlasOS 0.6.3 RC1 physical validation

**Record status:** user-reported physical smoke test  
**Record date:** 2026-10-05; exact test date was not separately recorded

## Artifact

- Name: `AtlasOS-0.6.3-rc1-live-amd64.iso`
- Size: 3,273,064,448 bytes
- SHA-256: `0a044347d556493ea62e3767f22e4cba796962988b9be9a4ee156ad7c96b4233`

## Device and result

- Device model: Casper Excalibur G870
- Boot mode: UEFI
- Usage: USB Live session
- Reported path: firmware → Atlas Boot Manager → Atlas boot backend → AtlasOS Live desktop
- Result: PASS; the desktop was reached and no blocking issue was reported during this smoke test.
- Evidence source: project-owner report. This result was not independently reproduced by the documentation audit.

This is one successful physical test on one device. It does not establish compatibility with other Casper models, interactive boards, display/touch hardware, or firmware configurations. Secure Boot and Legacy BIOS were not validated by this report.

No serial number, MAC address, or other private device identifier is recorded.
