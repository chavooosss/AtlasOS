# AtlasOS test layers

This document describes available validation layers, not the result of a fresh test run. Each layer answers different questions; virtual success does not establish physical hardware behavior.

- **Python unit checks:** selected launch, diagnostics, request, and QML component tests under tests/. They require the relevant Python and Qt dependencies.
- **Rust checks:** formatting and unit tests for the Atlas Boot Manager in atlas-boot/. UEFI target compilation is a separate check.
- **Shell checks:** syntax validation for maintained shell scripts; ShellCheck can be used when installed. Some historical scripts have older build-specific assumptions.
- **UI/render checks:** Qt/Xvfb rendering and selected layout checks. These create generated output and are not physical display validation.
- **QEMU/OVMF:** virtual UEFI and Atlas Boot Manager/Live-image checks.
- **QEMU/SeaBIOS:** historical virtual Legacy BIOS checks only; Legacy BIOS is unsupported/unvalidated for new builds and is not release-gating.
- **Manual Live-session checks:** Developer Center and user workflows on a booted image.
- **Physical validation:** firmware, real displays, touch/stylus, audio/network, board compatibility, and other device-specific behavior. Record the device context, firmware mode, steps, result, artifact hash, and whether the result is user-reported or independently captured.

The 0.6.3 RC physical result is documented as user-reported for one Casper Excalibur G870. The historical 0.6.2 physical result remains in its separate record. Automated source quality gates run in GitHub Actions; they do not imply general hardware qualification. Full ISO builds and physical tests are not ordinary hosted-runner jobs. See the [0.6.3 physical record](../validation/physical-0.6.3-rc1.md) and [CI and quality gates](../development/ci.md).
