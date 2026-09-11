# Round progress

Baseline: `300daf3` on `experiment/route-motion`. Full user request is preserved in `ROUND-PLAN.md`.

CI is the only native build host. Each implementation commit is pushed as a candidate so CI can build it; an item is marked done only after the build and its tests pass. Work stays in order. No Train or Plane modes.

| Item | Status | Verified implementation commit |
|---|---|---|
| 1. Remove Apps | done | `757f3fc` ? CI 34581730357 passed; menu screenshot reviewed |
| 2. Remove Auto-Stop Timer | done | `5819554` - CI 34583153529 passed; screenshot reviewed |
| 3. Safe map taps and confirmation | in progress | `cdfb75c` (CI pending) |
| 4. Favorites in every place picker | not started | ? |
| 5. Worldwide search, links, coordinates, plus codes, and sharing | not started | ? |
| 6. Simulation times and fastest-route ranking | not started | ? |
| 7. Per-mode speeds, mode routes, and swap | not started | ? |
| 8. Main-map route controls, seeking, and live speed | not started | ? |
| 9. Finish actions and notifications | not started | ? |
| 10. Persistent automatic/custom altitude | not started | ? |

## Item 3 in progress

Item 2 verified: CI run 34583153529 passed all checks. The menu screenshot shows no Timer or Apps. The internal route movement timer and motion sample code remain unchanged.

Done for item 3: default-off main map selection, conditional default-on confirmation toggle, proposed pin, coordinates and fast reverse-geocoded address, explicit route-stop warning, cancellation and stale-response protection, and double-tap failure ordering. Added production-controller scenario tests, map gesture/pin regression checks, and enabled/disabled Settings plus confirmation screenshots.

Left: native build, scenario tests, map/picker regression checks and visual inspection in CI. Real double-tap zoom interaction still needs the user's phone after final delivery.

Exact next step: check CI for `cdfb75c` and fix any native/test failures, then inspect screenshots before item 4.

Choices to record: allow up to 600 ms for a reverse-geocoded address before showing a coordinates-only confirmation; use five decimal places for displayed coordinates.
