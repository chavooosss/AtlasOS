# Engineering history to preserve

Do not publish raw prompt streams or multi-gigabyte experiment outputs as the project history. Curate selected engineering records in `docs/history/` after privacy and evidence review.

Candidate case studies:

- GRUB border glyph rendering and subsequent console reset.
- Black rectangle / Event A investigation, including hypotheses and physical A/B evidence.
- Early-i915 experiment and its bounded conclusion.
- Atlas Boot Manager UEFI frontend and graphics compatibility work.
- Phase 6B invisible backend and Phase 6C ISO integration.
- Physical validation path and known caveats.
- UI scaling and dock rendering defects.

Each record should state date/build, observed problem, hypothesis, change/experiment, exact evidence, outcome, remaining uncertainty and lesson. Distinguish physical user reports from QEMU or source inspection. No case study is claimed as completed by this planning list.