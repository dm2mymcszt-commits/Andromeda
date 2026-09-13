# Round progress

Baseline: `300daf3` on `experiment/route-motion`. Full user request is preserved in `ROUND-PLAN.md`.

CI is the only native build host. Each implementation commit is pushed as a candidate so CI can build it; an item is marked done only after the build and its tests pass. Work stays in order. No Train or Plane modes.

| Item | Status | Verified implementation commit |
|---|---|---|
| 1. Remove Apps | done | `757f3fc` - CI 34581730357 passed; menu screenshot reviewed |
| 2. Remove Auto-Stop Timer | done | `5819554` - CI 34583153529 passed; screenshot reviewed |
| 3. Safe map taps and confirmation | done | `cdfb75c` + `b848fed` - CI 34609171515 passed; dark/light screenshots reviewed |
| 4. Favorites in every place picker | done | `57b343f` - CI 34610371414 passed; four picker screenshots reviewed |
| 5. Worldwide search, links, coordinates, plus codes, and sharing | done | `4bf3731` - CI 34684236479 passed every check; final search/share screenshots reviewed |
| 6. Simulation times and fastest-route ranking | done | `71cd400` - CI 34696753573 passed every check; route map/cards reviewed |
| 7. Per-mode speeds, mode routes, and swap | done | `191ecf8` - CI 34697693135 passed every check; dark/light mode controls reviewed |
| 8. Main-map route controls, seeking, and live speed | done | `b6a1244` - CI 34713045215 passed every check; expanded/collapsed playback reviewed |
| 9. Finish actions and notifications | done | `b4b2282` - CI 34714016327 passed every check; Settings and collapsed controls reviewed |
| 10. Persistent automatic/custom altitude | done | `e878442` - CI 34745274343 passed every check; altitude screens and package reviewed |

## Items 1-3 verified

Item 3: CI 34608469914 and final follow-up CI 34609171515 passed every check. Reviewed default/conditional Settings and running-route confirmation in dark and light simulator screenshots. Real double-tap-to-zoom interaction still needs the user's phone. Chosen details: 600 ms maximum address wait, five decimal places, pending proposals cancel when another tool opens.

## Item 4 verified

Favorites now appear above Recent Places in the shared picker, read from BookMarkRetrieve(), filter by name, and convert saved WGS-84 coordinates into map coordinates. The direct Favorites action uses the same conversion. Added real bookmark-storage and coordinate round-trip tests, with Start/Destination/Search and filtered screenshots. CI 34610371414 passed all checks. Start, Destination, Search, and accent-insensitive filtered Favorites screenshots were inspected.

Choices to record: preserve Favorites order; match names ignoring case and accents; use five-decimal coordinates below the name; unnamed legacy entries display Favorite; invalid saved coordinates are omitted.

## Item 5 verified

Candidate aa311f9 pushed: generic Apple/original/expanded + rate-limited cached Photon + national address providers; neutral Settings/About; decimal, DMS, full/short plus codes; Google/Apple links and HEAD-only redirects/consent handling; paste integration. Models moved to PlaceModels.swift, search to PlaceSearch.swift, parsers to PlaceInput.swift, normalization to AddressQuery.swift. Added upstream OLC vectors and first-result 50 m checks for all seven requested addresses.

The implementation history and verification below are retained for continuity.

aa311f9 builds and passes offline parser/motion tests, but CI 34650005610 failed the Tokyo address at 123.7 m; the other six met 50 m. Follow-up 9f69143 preserves percent-escaped plus codes in URL queries and prints detailed live matches to diagnose ranking.

9f69143 builds and passes parser tests; CI 34650615733 confirmed Apple has the correct Tokyo pin, but split chome/block/building fields were incorrectly scored below an aquarium in the same complex. Fix 15e507b compares those components, with wrong-district/block regressions. CI 34650964213 passed every step. Live first-result distances: Talence 0 m, Google HQ 42 m, Downing Street 20 m, Adlon 17 m, Sagrada Familia 39 m, MASP 8 m, Skytree 3 m.

Sharing candidate 4fbe7b9 pushed: extension renamed Andromeda, legacy storyboard removed, four actions, direct Favorites saving, atomic per-request app-group inbox, main-app review on activation, route endpoint draft preserving both points. Added production inbox/draft/Favorites tests and Share/Incoming simulator screens. Updated obsolete country-specific documentation.

4fbe7b9 app/extension native build passed in CI 34683257730; subsequent tests/screens pending. Follow-up search commit ac8cdb3 adds wrong-street approximation, preserves plus codes in URL paths, and tests the production resolver against the official Skytree short link (HEAD-only redirect manually verified).

ac8cdb3 builds and passes live addresses, production short-link resolution, parser and sharing tests in CI 34683402836; simulator steps pending. Inspected Settings and Talence search screenshots from verified 15e507b: neutral data credits are correct, but duplicate building pins appeared. Follow-up 427f2bd merges identical numbered-address names within 100 m (retains highest-ranked pin), preserves separately named businesses, and adds regression/pasted-location screenshot coverage.

427f2bd builds; CI 34683820596 found the new regression fixture used the generic priority 20 instead of the national provider priority 0, so it expected the wrong retained pin. Fixture correction dd350ed uses the production priority; the check still requires one highest-ranked building pin.

Sharing CI 34683257730 and precision CI 34683402836 both passed every check. Inspected Share and Incoming screenshots: all four actions fit, incoming Go warns that it stops the route. Small visual follow-up 4bf3731 avoids repeating coordinates when the address field itself is coordinates.

Final CI 34684236479 for 4bf3731 passed every step. Final Incoming, Pasted, and Talence search screenshots were inspected: one coordinate row, one pasted pin, one numbered building result with separately named businesses preserved. Item 5 is done. Real share-sheet activation and installed-app interactions still require the phone.

Choices: debounce normal typing 650 ms; one Photon request per 1.25 seconds across pickers with a 128-query / 24-hour in-memory cache; five-decimal pasted coordinates; prefer a place pin over query coordinates, and use a camera center only as an approximate fallback after text lookup. Open Location Code adaptation has Apache-2.0 license and upstream test vectors. Data credits are a single About entry.

Sharing choices: use the documented app-group fallback instead of unsupported app launching; save favorites directly in the extension; editable shared place name; Cancel discards that queued action, swipe dismissal keeps it for next activation; shared route endpoints do not interrupt an active trip.

Package check: 4fbe7b9 app/helper/extension are ARM64 with expected signed entitlements. Share entry is Andromeda, principal controller exists, URL/text activation is configured, and the old storyboard is absent. Package is only an item-5 candidate, not final round delivery.

## Item 6 verified

Candidate 71cd400 pushed: shortest-distance ranking; simulated headline times on cards and both maps; published speed changes refresh all badges; real traffic is secondary; sub-minute formatting uses seconds. Updated the obsolete provider-ETA ranking test and synthetic 500 km/h map/card fixtures, including an ETA-only geometry-preservation check. Motion sample/injection logic remains unchanged.

Native build, motion, route-math, live search, shared-place, and route-map checks passed in CI 34696753573. Dark map and light cards inspected: 7.9 km at 500 km/h shows 57s; shortest 7.5 km shows 54s and Fastest. Workspace/picker regression steps also passed; final CI is success. Choices: round partial seconds up; retain real traffic as small secondary text; stable distance ranking.

## Item 7 verified

Prepared per-mode persisted km/h (5/20/50 defaults, 1-500 range), cached routes/selections and duration tabs, automatic swap including resolved Current Location, and independent errors when a mode is unavailable. Replaced the old Cycling-as-Walking request with actual worldwide OSRM bicycle directions. Added a provider-independent route representation, 1.1-second request reservations, required map credits/fix-map links, parser/live bicycle checks, saved-speed/cache/swap regressions, and mode-control screenshots. One direct bicycle API check returned a valid 2,876 m / 149-vertex route. Provider policy: https://routing.openstreetmap.de/about.html.

CI 34697693135 for 191ecf8 passed every check, including live cycling, saved-speed/cache/swap regressions, and all existing search/motion checks. Dark/light mode-control screenshots reviewed. Items 9-10 untouched.

Choices: keep successful modes if one cannot route; show No route with retry via Calculate; preserve each mode's alternative selection; use Typical travel for walking/cycling estimates and Real traffic for driving; speed slider with one-km/h +/- buttons; cycling failure is explicit, never substituted with walking.

## Item 8 verified

Candidate b6a1244 pushed: replaces pre-sampled point indexing with a WGS-84 distance track and elapsed-time journey. Added live trip-only speed, seek preview and release, pause/stop/end metadata, a collapsible main-map panel, and a scrollable side menu above the panel. Removed unused point counts, interpolation, stored ETA and last-sample fields. Updated movement tests and added expanded/collapsed playback screenshots with a layout non-overlap assertion.

CI 34713045215 passed every check, including native build, motion/seek/live-speed models, live addresses, sharing, playback screenshot/non-overlap, workspace, and picker regressions. Expanded dark and collapsed light playback screenshots inspected. Exact next: commit and push the reviewed item 9 candidate, then verify its native CI. Item 10 untouched.

Choices: advance every 250 ms using monotonic elapsed time; distance/bearing measured in WGS-84; freeze and inject zero speed while scrubbing; releasing preserves prior pause state; cancelled gestures resume without moving; elapsed means actual moving time (excluding pause/scrub), seeking does not fabricate elapsed time; live +/- controls change one km/h without saving mode defaults; VoiceOver adjusts progress by five percent.

## Item 9 verified

Added RouteFinish.swift with six persisted actions, a WGS-84 saved destination, repeat/reverse leg state, and foreground/background local notifications. Settings uses the existing place picker; first route start requests notification permission before movement begins. Engine snapshots finish settings at trip start, uses the same finish path for natural arrival and seeking, preserves timer/background/location updates across repeated legs, reverses the same geometry, and carries delayed elapsed time across legs. Added policy, notification-count, reverse seek/speed, and persistence regressions.

CI 34714016327 for b4b2282 passed every check. Settings and collapsed playback screenshots reviewed. Foreground/background notification delivery and locked-phone continuity require the user's phone. Item 10 can now be committed for CI.

Choices: changing finish settings affects the next trip, stated in Settings; canceling a required Go-to-place picker keeps the previous option; reject starting an invalid Go-to-place configuration; loop/repeat notifications only on first arrival; elapsed resets for each leg; delayed repeat legs are counted without replaying every missed update; map shows the active leg with correctly oriented endpoints while running.

## Item 10 verified

Added saved Automatic/Custom altitude, a numeric sheet with sign control and comma/dot validation, and central application before every location injection. Removed the old unsaved altitude alert and route-only altitude argument. All entry paths, including finish jumps, now share it. Automatic uses free worldwide Open-Meteo/Copernicus terrain; missing altitude uses negative vertical accuracy. Async updates retain the latest location and motion; Stop/custom changes invalidate pending responses. Added persistence, stale-response, Stop, parsing, and motion tests, live elevation CI, and automatic/custom/negative simulator captures. A direct live Talence lookup returned 22 m. Version prepared as 2.6.0 (4).

Candidate e878442 committed and pushed after item 9 passed. CI 34745274343 is running. Exact next: verify native CI and inspect altitude screenshots. Then inspect the final package, shorten BUILD-TROLLSTORE.md, and delete both round files in the final commit.

Native build, motion, altitude persistence/races/live terrain, all seven addresses, sharing, and route-map checks passed. Expanded playback reviewed. Candidate package inspected: version 2.6.0 (4), ARM64 app/helper/extension with expected entitlements, Andromeda share action, location background mode, new altitude/finish/playback symbols and no removed feature classes. SHA-256: 14b26e84a91c2c923e83cd3b76fada74ea19524c1c844b45e52a1a08b0188334. Still awaiting altitude workspace captures and final picker checks; do not call item 10 done yet.

Choices: 90 m terrain dataset; cache 2,048 samples within 45 m; one single-coordinate lookup per 10 seconds, 60-second failure backoff, persisted request reservation; missing elevation stays unknown while waiting or offline. Custom changes require Apply to avoid injecting half-typed numbers, Automatic applies immediately. Negative sign button supplements the decimal keyboard; sheet expands if needed. Existing iOS deployment compatibility retained. Altitude refreshes preserve speed/course/accuracy and refresh the timestamp for an active stationary location.

Final CI 34745274343 passed every check, including workspace and shared picker regressions. Automatic light, custom 250 m dark, and negative -12.5 m dark captures inspected: values, sign control, Apply and Reset all fit in the compact sheet. Final package copied to build/Andromeda-2.6.0.tipa with the inspected checksum above. All ten items are implemented; phone acceptance remains for real injection/gestures, notifications, locked operation, sharing activation, and Snapchat.

Exact next: replace BUILD-TROLLSTORE.md with the prepared short build/checklist notes, delete ROUND-PLAN.md and ROUND-PROGRESS.md in the last commit, push, and confirm a clean checkout. No implementation work remains.
