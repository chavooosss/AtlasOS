# Third-party component notices

AtlasOS combines AtlasOS-owned source with separately licensed Ubuntu/Debian packages, Rust crates, fonts, icons, and other media. The root [MIT license](../../LICENSE) applies only to AtlasOS-owned source within the scope explained in [project license scope](../legal/project-license-scope.md).

## Package notices and inventory

For each release candidate, generate a versioned inventory from the exact built filesystem using [`tools/release/package_inventory.py`](../../tools/release/package_inventory.py). Include package name, version, architecture, source package when recorded, section, homepage, and the path to installed copyright metadata. `component` and normalized license identifiers are not guessed: join archive component data from the candidate's package repository metadata and review each package's `/usr/share/doc/<package>/copyright` record.

The installed package copyright/license files should remain in the image. A concise companion package list may point to those locations; do not replace or concatenate thousands of upstream license texts. Retain applicable full notices and source availability/offer information where upstream terms require them. Keep `Cargo.lock` and review the locked Rust dependency licenses/notices for the exact boot-manager build as a separate inventory.

The tool has not yet been run against a new cleaned Release Candidate filesystem. Therefore no exact-image SBOM, complete license map, or source-obligation bundle is claimed by this document.

## Fonts, icons, and applications

- Ubuntu Sans keeps `atlas-boot/fonts/source/LICENSE-Ubuntu.txt` beside the font; do not relabel it MIT.
- Adwaita and Papirus are installed from upstream packages. Preserve their package notices; do not copy individual icons into AtlasOS without provenance review.
- The future package list no longer selects Chrome and build setup no longer configures Google's repository/key. The preserved 0.6.2 physical ISO contains Chrome and is a historical validation artifact, not a public binary candidate.
- Chromium is not currently selected. Ubuntu Resolute's `chromium-browser` package is a transitional package to Snap; Snap provisioning, writable Live state, offline behavior, and first-run integration are not established for this build. The external browser action is generic and reports when no supported browser is installed. The Atlas in-app web view remains a distinct existing feature.
- Other Ubuntu archive applications remain under package-specific upstream terms. The future package inventory must identify exact versions and source packages.

See the [rights inventory](../legal/third-party-inventory.md), [asset inventory](../legal/asset-inventory.json), and [package distribution policy](../legal/package-distribution-policy.md).
