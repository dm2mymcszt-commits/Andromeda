# TrollRoute round progress

## Resume

- Plan: [ROUND-PLAN.md](ROUND-PLAN.md). Detailed evidence, root causes, inventory, exact approvals/commands, tag snapshot and migration inputs: [ROUND-AUDIT.md](ROUND-AUDIT.md).
- Branch: `experiment/route-motion`; origin: `dm2mymcszt-commits/Andromeda`. Application baseline `546ffb2`; no application code changed yet.
- Current checkpoint: Phase 0 audit done; final CI status needs checking. Next: check run **34759000421**, record outcome, then start Phase 1. Do not redo completed audits.
- Audit CI: [34759000421](https://github.com/dm2mymcszt-commits/Andromeda/actions/runs/34759000421), source `f2c2a4256ca6782cf904dad0dd607f109fdb6896`. Last observed: package, all model/live checks, route-map and workspace previews passed; picker running.
- Downloaded audit package: `build/trollroute-phase0/package/Geranium.tipa`; ZIP/ARM64/app+helper+share entitlements verified. SHA256 `f1941ea870dc0f71299993ee4493d72f022082f15de4d75f0490d82bade0abd9`.
- Current docs-only checkpoint before compaction: `17b784c`, pushed. Long audit moved intact to ROUND-AUDIT.md per latest owner instruction; commit/push this move first.
- Persist each finished step and its next action. Keep this file short; append detailed findings to audit. Delete **all three ROUND files** in the final commit.

## Decisions already approved

- **Entitlement removal table approved** on 2026-09-13 (exact section 0.5 at `c3ba6b9`, approval recorded `575d61d`). Apply in Phase 2, not before. Keep rows stay; future extension privileges need separate review.
- **Exact GitHub list approved**: rename to TrollRoute; description "Location simulation and route playback for TrollStore."; default `experiment/route-motion`; keep `main`; delete only the 14 tags listed with SHAs in audit; update origin. Commands prepared in audit, **not executed yet**. No need to ask again.
- **Live Activity destination = current leg endpoint**, including original start on return legs.
- Icon comparison/shipment approval still pending; retain old app icon until approved.
- No GitHub Release authorized or created. No private extension fallback or unreadable-data migration success authorized.
- Injection changes need separate commit and phone Bitmoji test. Physical TrollStore and Dynamic Island behavior must not be claimed from simulator tests.

## Status and commit ledger

| Phase / items | Status | Evidence / next work |
|---|---|---|
| 0.1 baseline facts | Done | `1f7dadf` |
| 0.2 root causes | Done | `cb74fc1`; coverage gap `f586be7` |
| 0.3 identity inventory | Done | `ad85d73`; 431 occurrences / 60 paths in audit |
| 0.4 unused-code proof | Done | `a788fe0` |
| 0.5 entitlement audit | Done, approved | `c3ba6b9`, approval `575d61d` |
| 0.6 architecture | Done | `f2c2a42`; migration detail `bcab51e` |
| 0 acceptance | In progress | Audit posted; final CI conclusion pending |
| 1 R1 identity + import | Not started | Rename project/targets/IDs/UI/docs/UA; read-only migration fixtures |
| 1 R2 repository | Approved, not executed | Preflight tags/releases; run exact commands; record each operation |
| 1 R4 icon | Not started | Save reference; deterministic vector layers/render; comparison in chat+CI; wait for approval |
| 1 F6 data credits | Not started | Generic About line, complete linked notices |
| 1 acceptance | Not started | New .tipa IDs/signing; migration tests; icon comparison; no Release |
| 2 R3 foundation | Not started | Approved cleanup, shared LocationSession, previous spoof snapshot; preserve checkSandbox |
| 2 F2 injection | Not started | Separate commit; adapter cadence/coalescing/timezone tests and phone check |
| 2 F1 altitude | Not started | Batched route profile, interpolation, continuity; custom unchanged |
| 2 acceptance | Not started | Session/profile/adapter tests and existing regression; build timing |
| 3 R5, R6 | Not started | Main Stop confirmation; visible toolbar hit bounds |
| 3 R18, R19, R20, R21 | Not started | Long press routing, enable/confirm/auto-start defaults and gesture tests |
| 3 F5 + acceptance | Not started | Save favorite from result/map pin; tests and settings defaults |
| 4 R11, R12, R13 | Not started | Default/per-trip/live finish action, including return legs |
| 4 R15, R16, R17 | Not started | All Route Stop entry points; both choice sets/outcomes/default preselection |
| 4 R14, F3 + acceptance | Not started | Credits inside active panel; moving scrub preview; engine tests + screenshots |
| 5 R7, R8, R9, R10, F4 | Not started | Direct share Go/Favorite; auto-open endpoints; immediate exactly-once channel/source labels |
| 5 acceptance | Not started | Lifecycle harness, source/outcome tests; phone flows |
| 6 R29, R30, R31, R32 | Not started | Registration/access/accuracy status, evidence-based onboarding |
| 6 acceptance | Not started | Status model tests, good/bad screenshots, documented permission decision |
| 7 R22, R23, R24 | Not started | Optional Live Activity, exact content/Stop, two notification toggles |
| 7 R25, R26, R27, R28 | Not started | Accurate explanations, runtime capability, external DynamicCow note, honest testing |
| 7 acceptance | Not started | Intent/state/compatibility tests, native system screenshots, signed widget, iOS 15 launch |
| 8 documentation | Not started | README rewrite; short BUILD guide, migration/release policy/phone checklist |
| 8 regression + delivery | Not started | All Part D + phase checks; version 3.0.0 suggested, increasing build; final per-ID report |
| 8 cleanup | Not started | Delete ROUND-PLAN.md, ROUND-PROGRESS.md, ROUND-AUDIT.md last; no Release |

## Carry-forward constraints

- Three distinct systems: main Stop ends spoofing; Route Stop always asks location outcome; finish action applies at natural arrival.
- Existing preview tests omit the production toolbar ScrollView; existing route tests omit RouteSimulator itself. Add real composition/engine coverage in affected phases.
- Old favorites/finish destination are WGS-84; recents are map coordinates. Preserve formats and old data. Removing no-container later must not hide newly imported preferences.
- Root helper still runs a useless startup side effect; welcome/checkSandbox/Favorites are live and must remain. Localized Info strings also contain old identity. Icon file named PNG actually contains JPEG.
- Source confirms missing share delivery events, not a fixed one-minute timer or a proven scenePhase race. Do not replace with polling.
