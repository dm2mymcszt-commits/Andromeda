# Round progress

Baseline: `300daf3` on `experiment/route-motion`. Full user request is preserved in `ROUND-PLAN.md`.

CI is the only native build host. Each implementation commit is pushed as a candidate so CI can build it; an item is marked done only after the build and its tests pass. Work stays in order. No Train or Plane modes.

| Item | Status | Verified implementation commit |
|---|---|---|
| 1. Remove Apps | done | `757f3fc` - CI 34581730357 passed; menu screenshot reviewed |
| 2. Remove Auto-Stop Timer | done | `5819554` - CI 34583153529 passed; screenshot reviewed |
| 3. Safe map taps and confirmation | done | `cdfb75c` + `b848fed` - CI 34609171515 passed; dark/light screenshots reviewed |
| 4. Favorites in every place picker | done | `57b343f` - CI 34610371414 passed; four picker screenshots reviewed |
| 5. Worldwide search, links, coordinates, plus codes, and sharing | in progress | `15e507b` search verified; `4fbe7b9` sharing candidate |
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

aa311f9 builds and passes offline parser/motion tests, but CI 34650005610 failed the Tokyo address at 123.7 m; the other six met 50 m. Follow-up 9f69143 preserves percent-escaped plus codes in URL queries and prints detailed live matches to diagnose ranking.

9f69143 builds and passes parser tests; CI 34650615733 confirmed Apple has the correct Tokyo pin, but split chome/block/building fields were incorrectly scored below an aquarium in the same complex. Fix 15e507b compares those components, with wrong-district/block regressions. CI 34650964213 passed every step. Live first-result distances: Talence 0 m, Google HQ 42 m, Downing Street 20 m, Adlon 17 m, Sagrada Familia 39 m, MASP 8 m, Skytree 3 m.

Sharing candidate 4fbe7b9 pushed: extension renamed Andromeda, legacy storyboard removed, four actions, direct Favorites saving, atomic per-request app-group inbox, main-app review on activation, route endpoint draft preserving both points. Added production inbox/draft/Favorites tests and Share/Incoming simulator screens. Updated obsolete country-specific documentation.

4fbe7b9 app/extension native build passed in CI 34683257730; subsequent tests/screens pending. Follow-up search commit ac8cdb3 adds wrong-street approximation, preserves plus codes in URL paths, and tests the production resolver against the official Skytree short link (HEAD-only redirect manually verified).

Exact next step: inspect CI for the latest search/share state, fix test failures and inspect Share/Incoming screenshots before marking item 5 complete. Items 6-10 remain untouched.

Choices: debounce normal typing 650 ms; one Photon request per 1.25 seconds across pickers with a 128-query / 24-hour in-memory cache; five-decimal pasted coordinates; prefer a place pin over query coordinates, and use a camera center only as an approximate fallback after text lookup. Open Location Code adaptation has Apache-2.0 license and upstream test vectors. Data credits are a single About entry.

Sharing choices: use the documented app-group fallback instead of unsupported app launching; save favorites directly in the extension; editable shared place name; Cancel discards that queued action, swipe dismissal keeps it for next activation; shared route endpoints do not interrupt an active trip.
