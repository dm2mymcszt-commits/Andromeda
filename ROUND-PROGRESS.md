# TrollRoute round progress

## Resume here

- Source of truth: ROUND-PLAN.md (exact copy of the owner's attached document).
- Baseline: `546ffb2`, branch `experiment/route-motion`, repository `dm2mymcszt-commits/Andromeda`.
- Current phase: **Phase 0, in progress**. No application behavior changed.
- Next step: commit and push these two files, then finish the Part B verification and commit/push audit step 0.1. Record each subsequent audit step separately before moving on.
- User instruction: persist every audit step so usage-limit interruptions cannot lose findings.
- Latest verified existing CI: [34745274343](https://github.com/dm2mymcszt-commits/Andromeda/actions/runs/34745274343), success, application source `e878442`. Later baseline commits only changed Markdown.
- CI currently ignores Markdown-only pushes. Phase 0 must remain documentation only; manually dispatch the workflow for the completed audit to verify the exact documentation commit without changing application code.
- Commits: initial plan/progress commit pending; its hash will be recorded by the following audit commit (a commit cannot contain its own hash).

## Phase checklist

| Step | Status | Commit / next action |
|---|---|---|
| 0.1 Verify every Part B fact | In progress | Finish identity/build/GitHub/behavior verification |
| 0.2 Confirm six bug causes, citations and reproductions | Not started | R6, R9, R14, F1, F2, F3 |
| 0.3 Classify every old-identity occurrence | Not started | Rename / keep / technical |
| 0.4 Prove unused code and resources | Not started | Helper, Addon, first-run, translations, media |
| 0.5 Entitlement table and owner approval | Not started | Audit all signing inputs; remove nothing before approval |
| 0.6 Shared-state architecture note | Not started | LocationSession, route session, command channel |
| 0 acceptance | Not started | Publish audit/table/questions; green CI |
| 1 identity and migration | Not started | R1, read-only import, fixture checks |
| 1 icon | Not started | R4, reference/layers/comparison; keep existing icon until approval |
| 1 repository operations | Not started | R2, exact commands and explicit yes before execution |
| 1 generic credits | Not started | F6 |
| 1 acceptance | Not started | Build/package names, signing, migration tests, icon comparison |
| 2 cleanup | Not started | R3, only approved entitlement removals |
| 2 shared state | Not started | LocationSession and transitions |
| 2 injection | Not started | F2, isolated commit and phone check |
| 2 elevation profile | Not started | F1, batch/profile tests |
| 2 acceptance | Not started | Existing regression, state/altitude/coalescing tests, build timing |
| 3 map and toolbar | Not started | R5, R6, R18–R21, F5 |
| 3 acceptance | Not started | Stop/gestures/hit area/favorites tests, defaults |
| 4 route session and panel | Not started | R11–R17, F3 |
| 4 acceptance | Not started | Six finish actions, both Stop dialogs/outcomes, screenshots, motion |
| 5 share handoff | Not started | R7–R10, F4 |
| 5 acceptance | Not started | Exactly-once lifecycle, immediate recognition harness, phone checklist |
| 6 permissions and registration | Not started | R29–R32 |
| 6 acceptance | Not started | Status model tests, good/bad screenshots, authorization evidence |
| 7 notifications and Live Activity | Not started | R22–R28 |
| 7 acceptance | Not started | State/interaction/capability tests, system-surface screenshots, signed widget, iOS 15 |
| 8 README and BUILD documentation | Not started | TrollStore-only, migration, release policy, limitations, phone checks |
| 8 full regression and package | Not started | Part D and all phase acceptance checks |
| 8 final report and cleanup | Not started | Every ID, choices, approvals; remove temporary ROUND files last |

## Item ledger

All items below are **not started** as implementation work. Audit findings do not imply a fix or device verification.

| ID | Phase | Task |
|---|---|---|
| R1 | 1 | Complete identity rename and read-only migration |
| R2 | 1 | Repository rename/default branch/old tags; explicit approval |
| R3 | 2 / throughout | Maintainable foundation and proven-dead cleanup |
| R4 | 1 | Approved icon recreation and separate approval before shipping |
| R5 | 3 | Main Stop confirmation |
| R6 | 3 | Toolbar visible bounds equal gesture bounds |
| R7 | 5 | Four working share actions |
| R8 | 5 | Automatically open app for shared route endpoints |
| R9 | 5 | Immediate command recognition without polling |
| R10 | 5 | Accurate shared-place source label |
| R11 | 4 | Settings finish action is a default |
| R12 | 4 | Per-route finish choice before starting |
| R13 | 4 | Live per-route finish choice |
| R14 | 4 | No creation credits leaking below playback panel |
| R15 | 4 | Separate Route Stop dialog everywhere |
| R16 | 4 | Correct location outcomes with/without previous spoof |
| R17 | 4 | Route Stop default only preselects a choice |
| R18 | 3 | Long press creates route from real/spoofed active location |
| R19 | 3 | Long-press enable setting |
| R20 | 3 | Optional long-press confirmation |
| R21 | 3 | Optional long-press auto-start |
| R22 | 7 | Optional Live Activity |
| R23 | 7 | Exact activity content and consistent Stop choices |
| R24 | 7 | Route-finished and Time Sensitive toggles only |
| R25 | 7 | Correct Live Activity / Dynamic Island explanation |
| R26 | 7 | Runtime compatibility and disabled-state reasons |
| R27 | 7 | Optional external DynamicCowTS information |
| R28 | 7 | Honest hardware testing status |
| R29 | 6 | Informational TrollStore registration status |
| R30 | 6 | Evidence-based location authorization onboarding |
| R31 | 6 | Precise Location detection and guidance |
| R32 | 6 | Live permission status overview |
| F1 | 2 | Stable automatic altitude during movement |
| F2 | 2 | Injection cadence and time-zone notification coalescing |
| F3 | 4 | Moving scrub preview preserves speed |
| F4 | 5 | Share actions no longer wait for manual opening |
| F5 | 3 | Save search/map-picked points as favorites |
| F6 | 1 | Generic About data line with complete linked credits |

R15–R16 and R18–R21 are grouped in the source plan; this ledger divides their subrequirements for tracking only, without changing scope.

## Decisions and approval queue

- Entitlement removals: **not approved**, table pending.
- Repository rename/default branch/tag deletion: **not approved**, exact command list pending.
- New icon shipment: **not approved**, comparison pending; existing icon stays installed meanwhile.
- Live Activity destination on return legs: owner clarification required before implementing that field.
- No GitHub Release authorized; none created.
- Motion injection/cadence changes and TrollStore-only interactions require phone checks; no such changes made yet.

## Audit findings

Findings will be appended and committed after each Phase 0 step. Existing source inspection is not a substitute for the required simulator/phone checks.
