# Round progress

Baseline: `300daf3` on `experiment/route-motion`. Full user request is preserved in `ROUND-PLAN.md`.

CI is the only native build host. Each implementation commit is pushed as a candidate so CI can build it; an item is marked done only after the build and its tests pass. Work stays in order. No Train or Plane modes.

| Item | Status | Verified implementation commit |
|---|---|---|
| 1. Remove Apps | done | `757f3fc` - CI 34581730357 passed; menu screenshot reviewed |
| 2. Remove Auto-Stop Timer | done | `5819554` - CI 34583153529 passed; screenshot reviewed |
| 3. Safe map taps and confirmation | done | `cdfb75c` + `b848fed` - CI 34609171515 passed; dark/light screenshots reviewed |
| 4. Favorites in every place picker | done | `57b343f` - CI 34610371414 passed; four picker screenshots reviewed |
| 5. Worldwide search, links, coordinates, plus codes, and sharing | in progress | `aa311f9` (candidate) |
| 6. Simulation times and fastest-route ranking | not started | - |
| 7. Per-mode speeds, mode routes, and swap | not started | - |
| 8. Main-map route controls, seeking, and live speed | not started | - |
| 9. Finish actions and notifications | not started | - |
| 10. Persistent automatic/custom altitude | not started | - |

## Items 1-3 verified

Item 3: CI 34608469914 and final follow-up CI 34609171515 passed every check. Reviewed default/conditional Settings and running-route confirmation in dark and light simulator screenshots. Real double-tap-to-zoom interaction still needs the user's phone. Chosen details: 600 ms maximum address wait, five decimal places, pending proposals cancel when another tool opens.

## Item 4 verified

Favorites now appear above Recent Places in the shared picker, read from BookMarkRetrieve(), filter by name, and convert saved WGS-84 coordinates into map coordinates. The direct Favorites action uses the same conversion. Added real bookmark-storage and coordinate round-trip tests, with Start/Destination/Search and filtered screenshots. CI 34610371414 passed all checks. Start, Destination, Search, and accent-insensitive filtered Favorites screenshots were inspected.

Choices to record: preserve Favorites order; match names ignoring case and accents; use five-decimal coordinates below the name; unnamed legacy entries display Favorite; invalid saved coordinates are omitted.

## Item 5 in progress

Candidate aa311f9 pushed: generic Apple/original/expanded + rate-limited cached Photon + national address providers; neutral Settings/About; decimal, DMS, full/short plus codes; Google/Apple links and HEAD-only redirects/consent handling; paste integration. Models moved to PlaceModels.swift, search to PlaceSearch.swift, parsers to PlaceInput.swift, normalization to AddressQuery.swift. Added upstream OLC vectors and first-result 50 m checks for all seven requested addresses.

Left: native CI and parser/live checks (fix any failures), share extension's four actions and main-app handoff, final search/share UI verification and documentation cleanup. No item 6 work yet.

Exact next step: inspect CI for aa311f9, resolve native/parser/live failures, then complete share extension and main-app incoming-place handling. If free providers cannot meet a required address, report that limit rather than weakening the check.

Choices: debounce normal typing 650 ms; one Photon request per 1.25 seconds across pickers with a 128-query / 24-hour in-memory cache; five-decimal pasted coordinates; prefer a place pin over query coordinates, and use a camera center only as an approximate fallback after text lookup. Open Location Code adaptation has Apache-2.0 license and upstream test vectors. Data credits are a single About entry.
