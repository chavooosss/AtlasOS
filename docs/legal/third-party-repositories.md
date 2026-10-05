# Third-party repository policy and current configuration

Future public builds should use the Ubuntu archive/security repositories configured for the selected Ubuntu base. Any external APT repository needs a recorded provider, purpose, package set, signing-key source, terms, and redistribution review before it enters a release build.

| Repository | Purpose | Package | Future-build status | Distribution review |
|---|---|---|---|---|
| Ubuntu archive and security mirrors | Ubuntu base and archive packages | Selected package list and dependencies | Active | Package-specific terms/notices apply; record repository component for the exact build. |
| Google Linux package repository (`dl.google.com`) | Historical Chrome package | `google-chrome-stable` | Removed from active future-build setup | Not used for a future public candidate unless separately reviewed and explicitly approved. |

The active build should not install third-party repository keys for packages it no longer selects. This document records the cleanup decision; inspect build configuration when preparing a release candidate to verify no external repository has been reintroduced.
