# TrollRoute round progress

## Resume here

- Source of truth: ROUND-PLAN.md (exact copy of the owner's attached document).
- Baseline: `546ffb2`, branch `experiment/route-motion`, repository `dm2mymcszt-commits/Andromeda`.
- Current phase: **Phase 0, in progress**. No application behavior changed.
- Next step: audit step 0.2, record the six bug causes and baseline reproduction cases, then commit and push.
- User instruction: persist every audit step so usage-limit interruptions cannot lose findings.
- Latest verified existing CI: [34745274343](https://github.com/dm2mymcszt-commits/Andromeda/actions/runs/34745274343), success, application source `e878442`. Later baseline commits only changed Markdown.
- CI currently ignores Markdown-only pushes. Phase 0 must remain documentation only; manually dispatch the workflow for the completed audit to verify the exact documentation commit without changing application code.
- Commits: `30cbf19` saved plan and checklist, pushed. Each following audit commit records the preceding hash (a commit cannot contain its own hash).

## Phase checklist

| Step | Status | Commit / next action |
|---|---|---|
| 0.1 Verify every Part B fact | Done | This audit commit; source baseline `546ffb2` |
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

### 0.1 Part B verification

Verified against tracked source at `546ffb2` and GitHub on 2026-09-13. No behavior changes.

| Claim | Result and evidence |
|---|---|
| Application and extension IDs / test IDs | Confirmed in `Geranium/Info.plist:13` and `Geranium.xcodeproj/project.pbxproj:644,672,833,873,893,913,931,949`. |
| Old app group for favorites/inbox | Confirmed in both app entitlements, both extension entitlements, `SharedPlace.swift:53`, and `BookMarkHelper.swift`. |
| Project, target, scheme, folders and executable names | Confirmed in project file, shared scheme, Info.plist and `ipabuild.sh`. Extension display name is **Andromeda**, even though its executable/target still says Bookmark Location in Geranium. |
| Build output / artifact | Confirmed: `Geranium.tipa`, `Andromeda-route-motion-<sha>`. Xcode 16.4 and macOS 15 are pinned in workflow. |
| Rough identity counts | Replace rough counts with the exhaustive tracked-tree inventory in step 0.3; binary artwork and path names must be counted separately from text. |
| Display name, location purpose strings, background modes, URL scheme | Confirmed: Andromeda; three identical vague purpose strings; location + processing; no URL scheme. |
| Icon | **Correction:** `geranium.png` is actually JPEG-encoded (JFIF magic), 1024×1024, verified using Pillow. The filename/asset setup claims PNG. The replacement must be a real opaque PNG. Apple's [Icon Composer integration](https://developer.apple.com/videos/play/wwdc2025/361/) belongs to the newer toolchain, not the pinned Xcode 16.4 build. |
| Root helper | **Correction:** not literally unexecuted. `GeraniumApp.swift:19` calls `RootHelperMan.swift:50` with three empty strings. `RootHelper/main.m:99` creates `/var/mobile/testrebuild` and loads MCM **inside the child process**, then matches no action. This does not initialize MCM in the app. No useful current feature calls another helper command. Its removal eliminates the startup side effect too. |
| Theos / SDK | Confirmed only needed by RootHelper; workflow setup and `ipabuild.sh` make/copy the helper. A tracked prebuilt helper is also copied by an Xcode build phase, then overwritten by packaging. |
| Entitlements | Confirmed identical app signing files, identical group-only extension signing files. Helper has a third, broader entitlement set; include that in 0.5. Absence of simulation entitlement agrees with the extension having no injection code, but private service authorization still needs device verification. |
| Build document heading | Confirmed prohibited owner-device heading exists; remove in Phase 1 without repeating the model here. |
| GitHub fork / description / default branch | Confirmed public fork of Son3ra1n/Andromeda, current description matches Part B, default main at `bc1e1d3`. Origin still points to the owner's Andromeda fork. |
| Releases / tags | Confirmed zero releases and exactly the 14 named tags. Read-only queries only; no repository setting or tag changed. |
| Toolbar / credits | Confirmed source branches at `LocSimView.swift:81–94,111–130`; deeper reproduction in 0.2. |
| Main Stop / Route Stop | Confirmed `LocSimView.swift:122,267–276`, `RouteSimView.swift:184,389` all reach `RouteSimulator.swift:605–615`, which calls full `stopLocSim`. |
| Finish action snapshot | Confirmed `RouteSimulator.swift:511–521` reads shared settings at start; finishState is private and no active-action setter exists. |
| Share queue / delay | Confirmed enqueue/manual-open state and only lifecycle/dismissal checks. **Qualification:** re-reading scenePhase is suspicious, not a proven cause of the reported minute-long delay. Missing notification/URL delivery is definite; no built-in one-minute delay exists. |
| Scattered spoof state | Confirmed local lat/long/joystick state, route position, private altitude activeLocation and static injector. No pre-route spoof snapshot or shared active session. |
| F2 cadence | Confirmed 0.25-second route ticks; every delivered sample restarts injection and posts timezone. Speed changes also call updateLocation directly. |
| F1 altitude | Confirmed 10-second spacing and 45-m cache. **Qualification:** walking is not guaranteed fine: first lookup, latency/offline failures and leaving the cache radius still produce unknown altitude. |
| F3 scrubbing | Confirmed preview sets seeking state, resets tick baseline and delivers motion as paused; advanceRoute rejects seeking. |

Current package contains one share extension with display name Andromeda. Source alone cannot identify which installed app or cached registration owns the additional Geranium share action in the screenshot. Do not delete another app or assert its origin without device evidence.

Open verification limits: no local iOS runtime; gesture recognition and lifecycle timing require the planned simulator harness. Root-helper removal and new private APIs require phone checks. CI ignores Markdown-only pushes, so existing green source remains unchanged; manual exact-head CI will close Phase 0 acceptance.
