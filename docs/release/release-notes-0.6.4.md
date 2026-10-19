# AtlasOS 0.6.4 — Development Preview Candidate

## Overview

AtlasOS 0.6.4 is the current Development Preview source candidate for an education-focused Ubuntu-based Live Linux environment. It continues the smartboard interface work, system UI polish, and UEFI boot improvements from the 0.6.3 development line. The project owner selected a pre-existing local Smartboard Demo image for manual USB testing: 3,273,457,664 bytes, SHA-256 `491c2a931a3f8ecfe75f0bd25bf6d1c10fac7670b978b491310ed90b1d677587`. Its source commit is not recorded, so it is not represented as a build of current `main`. See the [artifact record](../validation/selected-0.6.4-smartboard-demo.md). It has not been published as a download. A source-matched 0.6.4 test ISO is intended to be prepared separately; the selected pre-existing image remains the immediate manual test target, and its build commit is unknown.

## Highlights

- Carries forward smartboard scaling and layout fixes, system UI polish, notification empty-state refinement, clean-clone branding preparation, and Tabler Icons integration from the current source baseline.
- Adds one canonical external-browser launcher that prefers an already installed Google Chrome, with supported browser fallbacks.
- When no supported browser is installed, offers an explicit, user-triggered download and installation of Google Chrome from Google's official Linux package endpoint. Chrome is not bundled in the AtlasOS image. The installation adds Google's official package source for updates.
- Uses the AtlasOS website as the launch destination when the browser is requested without a URL or with `about:blank`.

## Validation

The 0.6.3 RC reached the Live desktop in one OVMF/QEMU run; the project owner separately reported one successful physical UEFI Live boot on a Casper Excalibur G870. Those results apply to that 0.6.3 artifact only. 0.6.4 still requires a fresh build and hardware testing.

## Supported boot path

UEFI is the primary supported boot path. Legacy BIOS is best-effort and is not release-gating; it is currently unsupported/unvalidated for new builds. Secure Boot is not validated.

## Known limitations

- Hardware coverage is limited; no broad interactive-board matrix is established.
- Installer, in-place upgrade, managed provisioning, and Secure Boot validation are not available.
- Browser installation requires network access and an administrator authorization prompt. Google terms are shown as review links; AtlasOS does not accept them for the user.
- No public 0.6.4 ISO is published. This candidate is for validation only.

## Installation / Live usage note

The 0.6.4 ISO is not yet a public release asset. Do not treat this source candidate as a production-ready or certified platform. A later physical test will be required before release claims are reconsidered.

## Integrity verification

The test ISO will be distributed directly for manual validation with a recorded SHA-256 digest. No Git tag, GitHub Release, or public binary download is created by this source change.

## Upgrade notes

No in-place operating-system upgrade path is defined. Use a fresh Live image for testing; preserve user data separately.

## Upstream foundation

AtlasOS builds on Ubuntu and upstream Linux/Qt components. Third-party software retains its own licenses and trademarks. See the [project license scope](../legal/project-license-scope.md) and [third-party distribution policy](../legal/package-distribution-policy.md).

## Reporting issues

Use the repository issue templates. Do not attach private diagnostics, personal data, credentials, or identifying device/network details to public reports.