# AtlasOS

**An education-focused Ubuntu-based Live Linux environment for classroom interactive boards.**

AtlasOS explores a focused classroom workflow through a custom Qt/QML desktop, system controls, educational-resource shortcuts, diagnostics, and a Rust UEFI boot frontend.

**Project status:** AtlasOS 0.6.3 — **Development Preview / Release Candidate**. The clean RC passed one OVMF/QEMU Live desktop smoke test and one owner-reported UEFI Live test on a Casper Excalibur G870. This is limited evidence from one physical device.

## Türkçe kısa özet

AtlasOS, sınıf içi etkileşimli tahta kullanımını odağına alan Ubuntu tabanlı bir Live Linux ortamıdır. Özel Qt/QML masaüstü, sistem kontrolleri, eğitim kaynaklarına kısayollar, tanılama araçları ve Rust tabanlı UEFI açılış arayüzü içerir. 0.6.3 temiz sürüm adayı OVMF/QEMU'da ve Casper Excalibur G870 üzerinde kullanıcı bildirimiyle UEFI Live masaüstüne kadar doğrulanmıştır; fiziksel doğrulama tek cihazla sınırlıdır.

## Why AtlasOS

General-purpose desktop environments are not primarily organized around the classroom workflow of starting a lesson, reaching common teaching tools, and understanding device status. AtlasOS explores whether a dedicated Live Linux environment can make those tasks easier to discover while keeping system diagnostics available to technical staff.

The project is aimed first at classroom teachers and interactive-board environments. School technical staff are a secondary audience; developers and researchers interested in education-focused Linux systems may also find the implementation useful. Formal user research and broad device compatibility studies are not established by the current evidence.

## Design principles

- **Classroom first:** put common lesson actions and resources within reach.
- **Low friction:** make frequent controls easier to find.
- **Clear system state:** present network, audio, display, and device information in the Atlas interface.
- **Education identity:** shape the desktop around classroom work rather than generic workstation workflows.
- **Diagnostics when needed:** keep deeper system information available without making the teacher-facing home screen a diagnostic console.
- **Build on proven foundations:** integrate established Linux components where they fit instead of replacing them without cause.

These are design principles, not measured usability outcomes.

## Current capabilities

- **Atlas desktop:** Qt 6 / PySide6 QML shell, home dashboard, navigation, settings, lesson tools, and application shortcuts.
- **System integration:** audio controls through PipeWire/WirePlumber tooling, network status through NetworkManager, power actions, removable-media handling, and window tracking for dock behavior.
- **Education workflows:** local resource catalog and shortcuts, PDF/presentation/video launchers, whiteboard and screen-annotation tools. The resource interface does not establish an official education-service backend.
- **Diagnostics:** Developer Center and bounded system/boot information collectors, subject to the documented storage and privacy safeguards.
- **Boot:** Rust UEFI Atlas Boot Manager, integrated with a GRUB backend, Casper Live, and Plymouth.

See the [component status](docs/project/status.md) for implemented, partial, validated, and planned areas.

## Architecture at a glance

\`\`\`mermaid
flowchart TD
    UEFI --> ABM[Atlas Boot Manager]
    ABM -->|successful normal UEFI path| GRUB[GRUB backend]
    GRUB --> KERNEL[Linux kernel and initramfs]
    KERNEL --> CASPER[Casper Live]
    CASPER --> PLYMOUTH[Plymouth]
    PLYMOUTH --> LIGHTDM[LightDM]
    LIGHTDM --> SESSION[XFCE session with Atlas UI]
    SESSION --> QML[Qt 6 / PySide6 QML shell]
\`\`\`

GRUB remains the boot backend. In the documented successful normal UEFI path its interface is not shown; some backend error paths can expose GRUB diagnostics or a command line. The desktop uses LightDM and XFCE/XFWM4 around the Atlas QML shell, which integrates selected system services rather than replacing them.

Read the [architecture overview](docs/architecture/overview.md) and [canonical source map](docs/architecture/source-map.md).

## Atlas Boot Manager

Atlas Boot Manager is a Rust UEFI application with a graphical interface rendered through UEFI Graphics Output Protocol (GOP), using Atlas artwork and embedded bitmap glyph assets. It supports keyboard navigation and a countdown, then loads and starts the boot backend from the same device. QEMU/OVMF evidence and one user-reported physical UEFI validation are documented. The successful physical path reached the Live desktop with Plymouth; Secure Boot and physical Legacy BIOS are not validated.

Details: [Atlas Boot Manager source and checks](atlas-boot/README.md) · [current physical validation record](docs/validation/physical-0.6.3-rc1.md).

## Validation

| Area | Current evidence |
|---|---|
| UEFI boot and Atlas Live desktop | QEMU/OVMF evidence; physical PASS is user-reported for one device and the recorded successful path |
| Legacy BIOS | Best-effort only; currently unsupported/unvalidated for new builds and not release-gating |
| Secure Boot | Not validated |
| Hardware compatibility | Limited evidence; no universal interactive-board compatibility claim |
| Physical result | One user-reported UEFI Live boot on a Casper Excalibur G870; not independently reproduced by this documentation work |

See [test layers](docs/testing/README.md), [project status](docs/project/status.md), and the [current physical validation record](docs/validation/physical-0.6.3-rc1.md).

## Current limitations

- No installer, first-boot provisioning, classroom profile setup, or centralized school administration is implemented.
- Official MEB, EBA, OGM, or MEBİ service integration is not established; the current resource interface provides local catalog entries and shortcuts.
- Secure Boot and broad interactive-board compatibility are not validated. Legacy BIOS is best-effort, unsupported/unvalidated for new builds, and not release-gating.
- Display presentation modes do not establish control of hardware resolution or DPI across devices.
- A clean, reproducible end-to-end build is still being developed. The build process has dependencies and an unsupported legacy host patch setting; review [build limitations](docs/build/README.md) before building.
- GRUB may become visible on some backend failure paths.
- The 0.6.2 integrated ISO has a documented embedded-manifest caveat; see [release integrity](docs/validation/release-integrity.md).

## Technology and project boundaries

**Foundation components:** Ubuntu Live, Linux, Casper, GRUB, Plymouth, LightDM, XFCE/XFWM4, Qt 6, PySide6, Python, NetworkManager, PipeWire/WirePlumber, and removable-media tools.

**Atlas-specific work:** the Atlas Qt/QML shell and classroom workflows, Atlas session integration, resource interface, diagnostics UX/integration, branding and packaging integration, and the Rust UEFI Atlas Boot Manager.

The Atlas-specific layer builds on upstream projects; it does not claim ownership of their components. A preliminary third-party code and asset inventory is available in [the legal review document](docs/legal/third-party-inventory.md).

## Build and test

The current ISO build uses WSL/Linux tooling and network package sources. A clean-clone reproducible build is not yet claimed, and one legacy host patch remains opt-in. Read [build requirements and safety limitations](docs/build/README.md) before attempting a build.

Available validation layers include automated Python, Rust, shell, documentation, and policy checks, optional UEFI compilation, UI/render checks, QEMU/OVMF, manual Live-session checks, and physical testing. These layers prove different things; virtual tests do not establish physical hardware behavior. Legacy BIOS is not release-gating. See [testing documentation](docs/testing/README.md) and [CI gates](docs/development/ci.md).

## Repository map

- **config/** — Live package lists, hooks, system configuration, and packaged Atlas UI/runtime sources.
- **atlas-boot/** — Rust UEFI Atlas Boot Manager and asset tooling.
- **iso/** — source-build, ISO integration, and verification scripts.
- **tests/** — unit, smoke, UI, and boot-test tooling.
- **assets/** — Atlas branding source and generators; distribution status is recorded in the asset inventory.
- **docs/** — architecture, build, validation, legal, and project records.

Generated artifacts and ISO files are intentionally excluded from normal Git history. The current candidate is **AtlasOS 0.6.3 — Development Preview / Release Candidate**. AtlasOS-owned source is licensed under MIT as scoped in [LICENSE](LICENSE) and the [license scope](docs/legal/project-license-scope.md). No public ISO download exists: the preserved physical 0.6.2 image is historical, contains Chrome and artwork/audio not cleared for that historical image, and will not be published. The clean 0.6.3 RC excludes Chrome, the Google package repository, and the startup WAV; its reviewed Atlas visual inputs have project-owner distribution permission recorded separately from source licensing. The RC passed an OVMF/QEMU Live desktop smoke test and a user-reported physical UEFI Live test on one device. Source publication and binary release are evaluated separately; the binary remains on hold pending exact-image package notices and source-obligation review. See the [release preparation](docs/release/README.md), [physical 0.6.3 test record](docs/validation/physical-0.6.3-rc1.md), and [AI asset provenance policy](docs/legal/ai-generated-assets.md).

## Roadmap

The roadmap is directional and has no promised dates. Near-term work is documentation/publication readiness, UI refinement, and build reproducibility. Later milestones may explore an installer, first-boot onboarding, and classroom provisioning. Longer-term research may cover offline educational content, school management, official service integration where permitted and technically supported, and broader hardware validation.

Details: [ROADMAP.md](ROADMAP.md).

## Documentation

Start with the [documentation index](docs/README.md), then see:

- [Architecture](docs/architecture/overview.md)
- [Build guide](docs/build/README.md)
- [Testing layers](docs/testing/README.md)
- [Project status](docs/project/status.md)
- [0.6.3 RC physical validation](docs/validation/physical-0.6.3-rc1.md)
- [Historical 0.6.2 physical validation](docs/validation/physical-0.6.2.md)
- [Release integrity](docs/validation/release-integrity.md)
- [Release preparation](docs/release/README.md)
- [0.6.3 RC release manifest](docs/release/release-manifest-0.6.3-rc1.json)
- [Historical 0.6.2 release notes](docs/release/release-notes-0.6.2.md)
- [0.6.2 release manifest](docs/release/release-manifest-0.6.2.json)
- [Release checklist](docs/release/checklist.md)
- [Third-party inventory](docs/legal/third-party-inventory.md)
- [Changelog](CHANGELOG.md)

## License and contribution status

The root MIT license applies to AtlasOS-owned source only. The Atlas Boot Manager crate retains its own `MIT OR Apache-2.0` declaration; upstream packages and assets keep separate terms. See [license scope](docs/legal/project-license-scope.md) and [third-party inventory](docs/legal/third-party-inventory.md). Reviewed Atlas visual assets have separate owner-recorded project-distribution permission; the startup WAV, branded reference screenshots, and personal/device photos are excluded.

The repository has not yet been published and external contributions are not open. The proposed contribution workflow is documented in [CONTRIBUTING.md](CONTRIBUTING.md). AtlasOS development predates its public Git baseline; earlier work is represented through selected validation and history records rather than reconstructed or backdated commits.
