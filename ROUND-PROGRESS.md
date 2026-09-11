# Round progress

Baseline: `300daf3` on `experiment/route-motion`. Full user request is preserved in `ROUND-PLAN.md`.

CI is the only native build host. Each implementation commit is pushed as a candidate so CI can build it; an item is marked done only after the build and its tests pass. Work stays in order. No Train or Plane modes.

| Item | Status | Verified implementation commit |
|---|---|---|
| 1. Remove Apps | done | `757f3fc` - CI 34581730357 passed; menu screenshot reviewed |
| 2. Remove Auto-Stop Timer | done | `5819554` - CI 34583153529 passed; screenshot reviewed |
| 3. Safe map taps and confirmation | done | `cdfb75c` + `b848fed` - CI 34609171515 passed; dark/light screenshots reviewed |
| 4. Favorites in every place picker | in progress | `57b343f` (CI pending) |
| 5. Worldwide search, links, coordinates, plus codes, and sharing | not started | - |
| 6. Simulation times and fastest-route ranking | not started | - |
| 7. Per-mode speeds, mode routes, and swap | not started | - |
| 8. Main-map route controls, seeking, and live speed | not started | - |
| 9. Finish actions and notifications | not started | - |
| 10. Persistent automatic/custom altitude | not started | - |

## Items 1-3 verified

Item 3: CI 34608469914 and final follow-up CI 34609171515 passed every check. Reviewed default/conditional Settings and running-route confirmation in dark and light simulator screenshots. Real double-tap-to-zoom interaction still needs the user's phone. Chosen details: 600 ms maximum address wait, five decimal places, pending proposals cancel when another tool opens.

## Item 4 candidate pushed

Favorites now appear above Recent Places in the shared picker, read from BookMarkRetrieve(), filter by name, and convert saved WGS-84 coordinates into map coordinates. The direct Favorites action uses the same conversion. Added real bookmark-storage and coordinate round-trip tests, with Start/Destination/Search and filtered screenshots. Local diff and shell checks pass. Native checks are still required.

Choices to record: preserve Favorites order; match names ignoring case and accents; use five-decimal coordinates below the name; unnamed legacy entries display Favorite; invalid saved coordinates are omitted.

Exact next step: check item 4 CI 34610371414, fix failures, inspect all four picker screenshots, mark item 4 done, then implement item 5.
