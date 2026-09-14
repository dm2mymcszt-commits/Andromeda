# TrollRoute round progress

## Resume

- Plan: [ROUND-PLAN.md](ROUND-PLAN.md). Detailed evidence, root causes, inventory, exact approvals/commands, tag snapshot and migration inputs: [ROUND-AUDIT.md](ROUND-AUDIT.md).
- Branch: `experiment/route-motion`; origin: `dm2mymcszt-commits/TrollRoute`. Application baseline `546ffb2`; Phase 1 identity and migration pushed.
- Current checkpoint: Phase 2. Owner `0cd7066` full CI 34815322711 SUCCESS. F2 `c5cbc37` full CI 34816390584 SUCCESS. F1 `b34cb4f` build 10 pushed; CI 34847031351 running. Next: validate F1, resolve any CI failure, finish Phase 2 acceptance before Phase 3.
- Audit CI: [34759000421](https://github.com/dm2mymcszt-commits/Andromeda/actions/runs/34759000421), source `f2c2a4256ca6782cf904dad0dd607f109fdb6896`: completed SUCCESS; package, model/live checks and all preview checks passed.
- Downloaded audit package: `build/trollroute-phase0/package/Geranium.tipa`; ZIP/ARM64/app+helper+share entitlements verified. SHA256 `f1941ea870dc0f71299993ee4493d72f022082f15de4d75f0490d82bade0abd9`.
- Compact resume/audit split: `e7e20a2`, pushed; long audit preserved intact in ROUND-AUDIT.md.
- Persist each finished step and its next action. Keep this file short; append detailed findings to audit. Delete **all three ROUND files** in the final commit.

## Decisions already approved

- **Entitlement removal table approved** on 2026-09-13 (exact section 0.5 at `c3ba6b9`, approval recorded `575d61d`). Apply in Phase 2, not before. Keep rows stay; future extension privileges need separate review.
- **Exact GitHub list approved**: rename to TrollRoute; description "Location simulation and route playback for TrollStore."; default `experiment/route-motion`; keep `main`; delete only the 14 tags listed with SHAs in audit; update origin. Executed and verified: new identity/default/description, all 14 tags removed, main preserved.
- **Live Activity destination = current leg endpoint**, including original start on return legs.
- Icon comparison at `1349f7f` explicitly approved on 2026-09-13; ship that exact render, without the rim.
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
| 0 acceptance | Done | Audit posted; CI 34759000421 SUCCESS; source unchanged by subsequent documentation commits |
| 1 R1 identity + import | Done; phone import check | `db74fc5`, `9d16061`, `75eba4a`: full CI 34778446157 SUCCESS; signed package verified; read-only fixtures pass |
| 1 R2 repository | Done, `674ee30` | Approved operations executed; verified zero tags/releases; main still bc1e1d3; origin updated |
| 1 R4 icon | Approved and committed | `e6d9569`: exact approved render installed; old icon sources removed. `2b53a12` compares identical pixels across OS; CI 34779276915 icon and app package passed |
| 1 F6 data credits | Done | `db74fc5`: generic About line links exact notices; full CI 34777564932 SUCCESS |
| 1 acceptance | Done | Full CI 34778446157 SUCCESS, downloaded package signing verified. Approved icon built in CI 34779276915; exact pixel check passed. No Release |
| 2 R3 foundation | In progress | Cleanup `d40830b` CI SUCCESS (46s build/package, no Theos). Owner `0cd7066` full CI SUCCESS, including transitions/persistence and all previews |
| 2 F2 injection | Done; phone test required | `c5cbc37` build 9 pushed. Root cause: restart/timezone per sample, unbounded slider inputs. 4 Hz coalescing + immediate jump/pause/arrival + geometry UI. Full CI 34816390584 SUCCESS, including adapter/cancellation tests and all previews |
| 2 F1 altitude | In progress | Root cause: 10 s lookup + 45 m cache. `b34cb4f` build 10 pushed: batched profile/interpolation, last-known hold, custom preserved, weighted persistent API budget. CI 34847031351 running |
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
- Root helper/dead utilities removed at d40830b. Welcome/checkSandbox/Favorites remain live. New approved icon is opaque PNG; identity localizations updated.
- Source confirms missing share delivery events, not a fixed one-minute timer or a proven scenePhase race. Do not replace with polling.
