# Round progress

Baseline: `300daf3` on `experiment/route-motion`. Full user request is preserved in `ROUND-PLAN.md`.

CI is the only native build host. Each implementation commit is pushed as a candidate so CI can build it; an item is marked done only after the build and its tests pass. Work stays in order. No Train or Plane modes.

| Item | Status | Verified implementation commit |
|---|---|---|
| 1. Remove Apps | in progress | `757f3fc` (CI pending) |
| 2. Remove Auto-Stop Timer | not started | ? |
| 3. Safe map taps and confirmation | not started | ? |
| 4. Favorites in every place picker | not started | ? |
| 5. Worldwide search, links, coordinates, plus codes, and sharing | not started | ? |
| 6. Simulation times and fastest-route ranking | not started | ? |
| 7. Per-mode speeds, mode routes, and swap | not started | ? |
| 8. Main-map route controls, seeking, and live speed | not started | ? |
| 9. Finish actions and notifications | not started | ? |
| 10. Persistent automatic/custom altitude | not started | ? |

## Item 1 in progress

Done locally: removed the menu action, screen and storage model/key, main-map state/sheet, Xcode references, and README feature entry. Repository search has no feature references outside the preserved request.

Left: native build and existing regression/visual checks in CI.

Exact next step: wait for the Actions run for `757f3fc`, inspect the menu preview, then record its verified commit hash and begin item 2.
