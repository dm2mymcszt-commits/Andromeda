# Round progress

Baseline: `300daf3` on `experiment/route-motion`. Full user request is preserved in `ROUND-PLAN.md`.

CI is the only native build host. Each implementation commit is pushed as a candidate so CI can build it; an item is marked done only after the build and its tests pass. Work stays in order. No Train or Plane modes.

| Item | Status | Verified implementation commit |
|---|---|---|
| 1. Remove Apps | done | `757f3fc` ? CI 34581730357 passed; menu screenshot reviewed |
| 2. Remove Auto-Stop Timer | in progress | `5819554` (CI pending) |
| 3. Safe map taps and confirmation | not started | ? |
| 4. Favorites in every place picker | not started | ? |
| 5. Worldwide search, links, coordinates, plus codes, and sharing | not started | ? |
| 6. Simulation times and fastest-route ranking | not started | ? |
| 7. Per-mode speeds, mode routes, and swap | not started | ? |
| 8. Main-map route controls, seeking, and live speed | not started | ? |
| 9. Finish actions and notifications | not started | ? |
| 10. Persistent automatic/custom altitude | not started | ? |

## Item 2 in progress

Item 1 verified: all native build, motion, geometry, search, map, and picker checks passed in run 34581730357. Main-map screenshot confirms Apps is absent. No implementation references or storage keys remain.

Done for item 2: removed the auto-stop menu entry, action sheet, countdown UI, state and methods, preview parameter, and README feature entry. Stop still calls RouteSimulator.stopSimulation and disables the joystick. RouteSimulator and RouteLocationSample are unchanged.

Left: native build and regression checks in CI.

Exact next step: wait for CI for `5819554`, and inspect the menu without Timer before beginning item 3.
