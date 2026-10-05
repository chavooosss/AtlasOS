# Package distribution policy

AtlasOS is an Ubuntu-based Live system assembled from separately licensed archive packages plus AtlasOS-owned code and assets. Enabling an Ubuntu archive component does not establish that any particular package from that component is included.

## Selection rules

1. Prefer packages from the configured Ubuntu archives. Avoid third-party repositories unless a required package has no suitable archive alternative and its terms and key provenance are reviewed.
2. Do not select proprietary applications without a documented redistribution basis. The historical 0.6.2 physical image included Google Chrome; Chrome is removed from future build configuration.
3. Preserve each package's upstream license and notices. Root MIT covers only AtlasOS-owned source.
4. Generate a package inventory from the exact candidate filesystem or `filesystem.manifest`. Treat license names as unknown unless an authoritative package record supports them.
5. Retain relevant `/usr/share/doc/<package>/copyright` files in the image. The inventory points to them; it does not concatenate or replace them.
6. For packages with source-availability or corresponding-source terms, record the binary version, source package/version, Ubuntu repository and component, and retrieval location. Make the required source available with the release or by the mechanism specified by the applicable terms.
7. Review package-set changes before each release, including packages from `restricted` or `multiverse`.

For a source-duty review, record the binary package's `Source:` value from the installed dpkg metadata (or use the binary package name when absent), binary version, configured Ubuntu suite/pocket, and archive component. In a matching environment with the corresponding `deb-src` entries enabled, query `apt-cache showsrc <source-package>` and retrieve the matching source with `apt-get source <source-package>=<source-version>`. Confirm the source version/repository actually corresponds to the installed binary; do not assume the binary and source version strings are identical. Record a package-specific source URL or written offer where that is the applicable mechanism.

## Inventory generation

Run `python tools/release/package_inventory.py --rootfs <filesystem-root> --output package-inventory.json --notices-output THIRD_PARTY_COMPONENTS.txt` against a built or extracted root filesystem. For a live-build package manifest, use `--manifest <filesystem.manifest>` instead. Manifest-only output cannot determine installed license metadata and labels those fields `UNKNOWN`.

The `dpkg` status database supplies package/version/architecture, source package when recorded, section, and homepage. The installed package copyright file is identified by path as the license metadata source. Archive component is not inferred from package names; it must be joined to repository metadata for the release. Do not fabricate SPDX identifiers from free-form copyright text.

## Scope and limits

This policy establishes a repeatable evidence trail, not a blanket clearance. The exact candidate package inventory, corresponding-source obligations, Atlas-specific assets, marks, and external legal requirements still require release review. No full release SBOM has been generated in this phase because the ISO build is expressly out of scope. Ubuntu describes `restricted` as closed-source base packages and `multiverse` as packages that do not meet all open-source criteria; archive component must be determined for actual installed packages, not inferred from enabled sources.
