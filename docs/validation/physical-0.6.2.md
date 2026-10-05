# AtlasOS 0.6.2 physical validation record

**Classification:** user-reported physical validation. The result was not independently reproduced during this documentation phase.

## Artifact

- Name: AtlasOS-0.6.2-live-amd64.iso
- Size: 3,471,966,208 bytes
- SHA-256: 670031830f191edaaeaa6cca32233bf56f416bc666cb2af69a0ce296caa1b5d8
- Release wording: **Development Preview / Physical Validation Build**

## Test context

A physical laptop was booted from a Live USB in UEFI mode. This record describes the reported successful normal path only; it does not claim qualification of a hardware model family.

## Reported successful path and result

UEFI firmware → Atlas Boot Manager → invisible GRUB backend → Linux kernel/initramfs → Casper Live → Plymouth → AtlasOS desktop.

The user reported reaching Plymouth and the Live desktop. The earlier partial black rectangle known as Event A was not observed during this successful run. The GRUB interface was not visible along this successful path.

## Not tested or not established

- This is a user-reported result, not an independent reproduction or laboratory qualification.
- The result applies to the recorded device, boot mode, and successful path only.
- It does not establish compatibility with all interactive boards, laptops, or UEFI firmware.
- GRUB may appear on backend failure paths; zero visible GRUB is not guaranteed for every outcome.
- Secure Boot is not validated.
- Historical Legacy BIOS behavior was exercised in QEMU/SeaBIOS only; physical Legacy BIOS is not tested. This historical evidence does not establish support for new builds; Legacy BIOS is best-effort and not release-gating.
- Resolution, touch, stylus, network, audio, and peripheral support must be validated separately for each target device.

QEMU/OVMF and QEMU/SeaBIOS results are virtual-platform evidence and do not substitute for physical testing. The integrated ISO has a separately documented embedded-manifest caveat in [release integrity](release-integrity.md). The ISO should remain outside normal Git history.
