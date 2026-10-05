# Decision 0002: Source and distribution rights after G6.2

**Date:** 2026-10-05  
**Status:** Source license applied; publication remains conditional  
**Owner decision:** MIT for AtlasOS-owned source only

## Decisions

1. The root `LICENSE` contains the standard MIT text with the project-owner name already used in project documentation: `Veli Ercan`. It covers AtlasOS-owned source only, subject to file/component-specific notices.
2. `atlas-boot` keeps `MIT OR Apache-2.0`; this remains crate-scoped. Ubuntu/Debian packages, Rust dependencies, Ubuntu Sans, icon themes, marks, and assets keep their own terms.
3. Google Chrome and its APT repository/signing-key setup are removed from active future-build configuration. The protected physical 0.6.2 ISO still contains `google-chrome-stable` 154.0.8037.97-1 and is historical evidence, not a public binary candidate.
4. Chromium remains pending. The configured Ubuntu Resolute archive package `chromium-browser` transitions to Snap. This live-build phase has not added `snapd`, an offline seed, writable Live state, or validated browser startup. No replacement browser is selected for the future image.
5. Superseding G6.2.1 review: the owner attests that Atlas-specific logo, UI, boot, and Plymouth art under review was AI-generated for AtlasOS and directs its project distribution. Those visual assets are included in the source proposal with a separate `AI-GENERATED-CLEARED` status; this is not an exclusive-copyright claim. Provider/model/output terms remain unverified for the visual assets.
6. The whole UI concept image and Boot Manager reference screenshot remain excluded because they display third-party education-service names/branding references. The Boot Manager now uses a separately stored, exact scenic crop instead; its pixel bytes were confirmed equal to the existing generated landscape payload. The current visual source baseline can therefore be built without the full branded reference screenshot.
7. Startup audio remains excluded. UI text indicates ElevenLabs, but exact provider use, plan, model, attribution and source/sample inputs are not recorded. Current official ElevenLabs information makes some rights conditional on plan and attribution; see the provider matrix. A future build may proceed with this optional sound absent, but public binary readiness still requires package/legal review and physical validation. No full ISO has been built in G6.2.1.

## Current status

| Deliverable | Status | Evidence / remaining action |
|---|---|---|
| AtlasOS-owned source license | Applied | Root `LICENSE` and [scope policy](../../legal/project-license-scope.md). |
| Third-party package strategy | Documented/tool added | Use package metadata and `/usr/share/doc/<package>/copyright`; generate against the exact next candidate. |
| Chrome removal | Applied to future config | Package list, Google repository/key setup, system hook, UI text, and launcher were reviewed; tests guard reintroduction. Historical ISO unchanged. |
| Atlas visual asset provenance | Owner-attested project distribution permission; provider terms unverified | Reviewed logo, boot, desktop and Plymouth assets are included; do not assert exclusivity. Reference screenshots and home concept with third-party service names remain excluded. |
| Startup audio | Excluded / unresolved | ElevenLabs indicated by UI text; exact generation plan, attribution, prompt/input and samples unknown. |
| Historical 0.6.2 binary | Not distributable | Chrome plus unclear Atlas-specific image/audio rights; embedded checksum issue remains separately documented. |
| G4.1 ISO | Internal only | Historical engineering candidate; not physically tested as a file and not established as matching the cleaned source/configuration. |

## Recommendation

Source publication remains **CONDITIONAL**: the owner has selected MIT and has recorded project distribution permission for reviewed AI visual assets, but visual-provider terms are not verified and the startup WAV remains excluded. The visual source baseline is complete for the included product artwork; the UI reference screenshots are not required by the Boot Manager generator anymore. An internal clean Release Candidate build is **READY TO PREPARE** without the optional startup sound, but no binary is ready for public distribution until exact-candidate package review, source obligations, rights review and physical validation are complete.

The historical physical 0.6.2 ISO is **NOT A PUBLIC BINARY CANDIDATE**. Do not change its bytes or relabel it. Recommend version `0.6.3` for a materially different cleaned binary; do not change `VERSION` or create a tag in this phase.

See [package policy](../../legal/package-distribution-policy.md), [asset inventory](../../legal/asset-inventory.json), and [third-party notices](../third-party-notices.md).
