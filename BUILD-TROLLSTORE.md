# Andromeda 2.6.0 (4) — TrollStore

This round removes Apps and the auto-stop feature; makes map taps opt-in with optional confirmation; adds Favorites to every picker; and supports worldwide search, Google/Apple Maps sharing, coordinates, DMS, and plus codes. Route times use your speed, modes retain separate speeds and cached routes, and swap recalculates the reverse trip. Main-map controls support seeking, live speed, pause, and Stop. Settings offers six finish actions with arrival notifications. Saved Automatic/Custom altitude applies to every location action.

Search combines free sources; it cannot promise Google's complete business catalog. Shared Google place pins provide the direct handoff. The Andromeda share action saves Favorites immediately; for other actions, open Andromeda to review the queued place.

Automatic altitude uses worldwide terrain estimates. Unknown elevation remains invalid to Core Location while unavailable or waiting for a lookup. Custom altitude accepts negative numbers and decimal commas; press Apply to save it. [Data sources and limits](THIRD-PARTY-NOTICES.md).

Build: macOS 15 / Xcode 16.4 in the fork's Actions workflow, branch `experiment/route-motion`. Download the successful run's **Andromeda-route-motion-<commit>** artifact, extract its `.tipa`, then install it using TrollStore's **+** button. The bundle identifier is unchanged, so it updates your existing app.

Package source: `e87844226faa6739b67d7f749fcedab0d51b1c8c`, [Actions run 34745274343](https://github.com/dm2mymcszt-commits/Andromeda/actions/runs/34745274343). SHA-256: `14b26e84a91c2c923e83cd3b76fada74ea19524c1c844b45e52a1a08b0188334`. ZIP integrity, executable ARM64 components, version, and app/helper/extension entitlements were inspected.

## Check on iPhone 12 / iOS 17.0

- [ ] Apps and auto-stop controls are absent. Stop restores real GPS and prevents further movement.
- [ ] Default map taps do nothing. Enable tap/confirmation, test Cancel and Move, then disable confirmation. Double-tap zoom never moves location; route lines/badges still select routes.
- [ ] Select a Favorite in Search, Start, Destination, and the after-route picker.
- [ ] Paste the Talence address and the other six addresses in the [search test](Tests/AddressSearch/main.swift); try decimal/DMS coordinates, full/short plus codes, and real Google share links. Exercise all four share actions.
- [ ] At 500 km/h, about 7.9 km shows 57 seconds; shortest is Fastest. Change modes without Calculate, restart to check saved speeds, and swap endpoints.
- [ ] Seek forward/backward while moving and paused; change 50 → 120 → 50 km/h; collapse/expand controls. Seek to 100% to finish.
- [ ] Test all six finish actions, including while locked and in another app. Reverse follows the same path. Repeat modes continue until Stop. Return-once notifies twice; repeating modes notify only at first arrival. Verify foreground banners too.
- [ ] Save 250 m, restart, and test tap/search/Favorites/joystick/route/finish jump. Apply `12,5`, a negative value, and Reset to Automatic. Change altitude during movement, then Stop while a lookup is pending.
- [ ] Confirm Snapchat still displays the driving Bitmoji during a driving route, including live speed changes and reverse legs.

CI verifies builds, motion and route models, search/parser accuracy, sharing/storage, altitude races, and simulator layouts. Actual TrollStore injection, touch gestures, notifications, locked-phone continuity, and Snapchat require these phone checks. Keep your working `.tipa` for rollback; reinstall it through TrollStore if needed.
