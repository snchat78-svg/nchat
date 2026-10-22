# Project Phase State — nchat

This is the canonical cross-chat handoff for this repository. Read it before making changes, verify the current branch/head and latest applicable CI, and select only the next incomplete phase.

## Repository
- Repository: [snchat78-svg/nchat](https://github.com/snchat78-svg/nchat)
- Active branch: `main`
- Current head after continuity documentation: `2c1f6bd7b3213d32f34b24cc331f054cd0c15db0`
- Phase policy: [PHASE_CONTINUITY_STANDARD.md](PHASE_CONTINUITY_STANDARD.md)

## Phase status
- **Canonical phase register:** newly initialized; historical completed phases have not yet been audited into a formal phase ledger. This does not mean no earlier work exists.
- **Last observed workflow success on the application-code head:** [run 30822392713](https://github.com/snchat78-svg/nchat/actions/runs/30822392713), code head `696c458cbbbeeefecb517792074f0091b0d6ff1a`. The run is associated with reCAPTCHA diagnostic workflow changes; treat it as diagnostic-workflow evidence, not proof of full application behavior or production authentication.
- Earlier Gradle/diagnostic workflow failures exist in Actions history. Do not claim broad release acceptance from a green diagnostic workflow alone.
- Current continuity-doc commit is newer than the last observed application-code run; check the newest applicable run before any implementation phase.

## Next phase — PLANNED
- **NCHAT-0 — Baseline inventory and acceptance audit**
- Inventory the Flutter app, Firebase Auth/reCAPTCHA integration, Android/iOS configuration, existing tests, diagnostic scripts/workflows and latest CI failure history.
- Establish a numbered phase ledger with specific acceptance gates before choosing the next feature.
- Reuse existing screens, auth/diagnostic implementations and workflows; do not rebuild them simply because older chat context is missing.

## Cross-chat rules
- Start every new phase by reading this state file and the continuity standard, then verify current main head and latest CI.
- Update this file and the roadmap/checkpoint when a phase starts or changes status.
- Mark a phase completed only after tests and required CI pass for the exact implementation/test SHA.
- When CI fails, continue fixing that same phase; do not skip the failure or restart completed work without a documented reason.
- Record exact SHA, CI URL/result, test evidence, limitations and next phase. Device, signing, production Firebase and real reCAPTCHA validation must be reported separately from CI.

## Change log
- 2026-10-22: Phase state and reusable continuity policy added. Existing code completion status was not inferred; NCHAT-0 baseline audit is planned.
