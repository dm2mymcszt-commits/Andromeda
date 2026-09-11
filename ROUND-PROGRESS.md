# Round progress

Baseline: `300daf3` on `experiment/route-motion`. Full user request is preserved in `ROUND-PLAN.md`.

CI is the only native build host. Each implementation commit is pushed as a candidate so CI can build it; an item is marked done only after the build and its tests pass. Work stays in order. No Train or Plane modes.

| Item | Status | Verified implementation commit |
|---|---|---|
| 1. Remove Apps | not started | ? |
| 2. Remove Auto-Stop Timer | not started | ? |
| 3. Safe map taps and confirmation | not started | ? |
| 4. Favorites in every place picker | not started | ? |
| 5. Worldwide search, links, coordinates, plus codes, and sharing | not started | ? |
| 6. Simulation times and fastest-route ranking | not started | ? |
| 7. Per-mode speeds, mode routes, and swap | not started | ? |
| 8. Main-map route controls, seeking, and live speed | not started | ? |
| 9. Finish actions and notifications | not started | ? |
| 10. Persistent automatic/custom altitude | not started | ? |

## Next step

Start item 1: remove the Apps feature, its storage model, project entries, and all executable references. Build and test in CI before marking it done.
