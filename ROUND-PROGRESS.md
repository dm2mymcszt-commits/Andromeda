# Round progress

Baseline: `300daf3` on `experiment/route-motion`. Full user request is preserved in `ROUND-PLAN.md`.

CI is the only native build host. Each implementation commit is pushed as a candidate so CI can build it; an item is marked done only after the build and its tests pass. Work stays in order. No Train or Plane modes.

| Item | Status | Verified implementation commit |
|---|---|---|
| 1. Remove Apps | done | `757f3fc` ? CI 34581730357 passed; menu screenshot reviewed |
| 2. Remove Auto-Stop Timer | done | `5819554` - CI 34583153529 passed; screenshot reviewed |
| 3. Safe map taps and confirmation | in progress | not yet committed |
| 4. Favorites in every place picker | not started | ? |
| 5. Worldwide search, links, coordinates, plus codes, and sharing | not started | ? |
| 6. Simulation times and fastest-route ranking | not started | ? |
| 7. Per-mode speeds, mode routes, and swap | not started | ? |
| 8. Main-map route controls, seeking, and live speed | not started | ? |
| 9. Finish actions and notifications | not started | ? |
| 10. Persistent automatic/custom altitude | not started | ? |

## Item 3 in progress

Item 2 verified: CI run 34583153529 passed all checks. The menu screenshot shows no Timer or Apps. The internal route movement timer and motion sample code remain unchanged.

Done for item 3: reviewed the main map's gesture path and Apple's gesture failure-ordering documentation. Route/badge selection precedes coordinate selection and can remain independent.

Left: default-off setting and conditional confirmation setting; temporary pin and cancellable fast address lookup; confirmation warning during a route; double-tap suppression; toggle/confirmation and map regression tests; CI build and previews.

Exact next step: implement the map-move confirmation controller, Settings controls, main-map gating and temporary annotation, and single/double-tap failure ordering. Keep RouteSimulator unchanged.

Choices to record: allow up to 600 ms for a reverse-geocoded address before showing a coordinates-only confirmation; use five decimal places for displayed coordinates.
