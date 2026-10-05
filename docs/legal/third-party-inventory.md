# AtlasOS source and distribution inventory

**Review date:** 2026-10-05. This is a source/build-configuration review, not a legal opinion or a completed exact-image SBOM.

## Current decisions

- The project owner selected MIT for AtlasOS-owned source. The root [license scope](project-license-scope.md) excludes third-party components and marks.
- `atlas-boot/Cargo.toml` retains `MIT OR Apache-2.0` as crate-level metadata. It does not license the rest of the repository.
- The future build package list and browser launcher no longer select or fetch Google Chrome. The protected historical physical 0.6.2 ISO still contains `google-chrome-stable` 154.0.8037.97-1 and is not a public binary candidate.
- No browser package is selected for the future image. Chromium is pending: on Ubuntu 26.04 Resolute, the `chromium-browser` package is transitional to a Snap; the current live-build configuration does not provision Snap or prove offline Live-session behavior. See [Ubuntu package metadata](https://packages.ubuntu.com/resolute/chromium-browser) and [the distribution policy](package-distribution-policy.md).
- Asset inventory statuses describe evidence and publication handling; they do not themselves grant rights. The owner has attested to the AI origin of Atlas branding/boot/UI art and directed project publication of visually reviewed assets marked `AI-GENERATED-CLEARED`. This records permission for AtlasOS project distribution, not exclusive copyright or verified provider terms. Startup audio, branded design-reference images, personal photos, and unrelated third-party images remain excluded.
- Ubuntu packages and Rust dependencies retain their own terms. The package tool points to installed package copyright files and does not invent SPDX mappings. A complete exact-image package inventory and source-obligation review must accompany the next candidate.

## Component classes

| Class | Examples | Handling |
|---|---|---|
| AtlasOS-owned source | Atlas Python/QML shell, hooks, build/test scripts, documentation, release tooling | Root MIT, except components with their own license/notice. Generated project art has a separate provenance record and project-distribution permission; provider terms and exclusivity are not asserted. |
| Component with separate license | `atlas-boot` | Preserve crate-level `MIT OR Apache-2.0` and font notice. |
| Ubuntu/Debian packages | XFCE, Qt/PySide6, LibreOffice, Evince, VLC, Xournal++, archive utilities and dependencies | Package-specific licenses. Preserve installed `/usr/share/doc/<package>/copyright` files; inventory exact versions and source-package references for each release. |
| Third-party asset | Ubuntu Sans, upstream icon themes, user/vendor art | Follow each original license or exclude when provenance/terms are missing. |
| Generated/release artifact | ISO, EFI images, generated artwork, test captures | Keep out of Git. Historical ISO bytes remain preserved. |

## Ubuntu archive components and external repositories

The build configuration enables `main`, `restricted`, `universe`, and `multiverse`. This alone does not prove which components are represented in an installed image. No separately sourced proprietary application is explicitly selected after Chrome removal. `linux-firmware` is explicitly selected and needs package/file-level copyright review. Other packages pulled from `restricted`/`multiverse` cannot be ruled in or out without the exact candidate package manifest joined to Ubuntu archive metadata; no component membership is inferred here. Ubuntu defines `restricted` for closed-source base packages and `multiverse` for packages that do not meet all open-source criteria; see [Ubuntu's component description](https://documentation.ubuntu.com/project/how-ubuntu-is-made/concepts/package-archive/).

The Google repository/key setup has been removed from active build configuration. Current future build sources are Ubuntu archive/security mirrors. Details and the rule for any future external source are in [third-party repository policy](third-party-repositories.md).

## Fonts, icons, marks, and media

- **Ubuntu Sans:** bundled font has the adjacent Ubuntu Font Licence 1.0 notice. Keep the notice wherever the font is redistributed; it is not under MIT.
- **Adwaita/Papirus:** selected as Ubuntu packages, not known copied source assets. Use their installed package notices. Audit any future standalone copies.
- **Atlas logo, boot art, wallpaper, dashboard imagery and startup sound:** origin/service terms are not fully documented. These remain excluded pending clearance or replacement.
- **MEB/EBA/OGM/MEBİ:** current labels/URLs are textual compatibility references, not official integration or endorsement. Logos require independent clearance.
- **Pardus image and environment photos/screenshots:** excluded absent image-specific rights/privacy review.
- **Ubuntu/Canonical:** “Ubuntu-based” is a factual base description; no Canonical endorsement is claimed. The exact physical ISO has not had a complete visual mark audit.

The machine-readable asset-level record is [asset-inventory.json](asset-inventory.json). The package-generation method is documented in [third-party notices](../release/third-party-notices.md).
