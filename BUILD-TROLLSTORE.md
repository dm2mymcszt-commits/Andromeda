## Map-only update (2026-09-10)

The user confirmed that starting a route now automatically shows the Snapchat car Bitmoji on their device. This update preserves the working route motion metadata.

The app opens directly to the map. Home, Daemons, Cleaner, Supervise, and their Swift feature sources are removed from the build. A Settings button opens map appearance, satellite view, button labels, haptics, and address lookup preferences. All map controls share an indigo palette. Stop also stops the route timer so it cannot restart location injection.

Both map search and route endpoint search now use the same picker. Empty Apple autocomplete results automatically fall back to full search and geocoding. French postal addresses also use IGN's current Geoplateforme / BAN endpoint, with abbreviation normalization, postcode and confidence filtering, explicit approximate-match labels, cancellation, and stale-response protection. Only the typed address is sent to IGN; no current-location coordinates. This supplement can be disabled in Settings. The exact screenshot query `125 Cr Gambetta, 33400 Talence` returned `125 Cours Gambetta 33400 Talence` at 44.817059, -0.585746 in a live service check. Apple and Google have different place catalogs; this does not promise every Google place exists in Apple search.

Version is 2.5.2 (3). CI adds production-model address regression tests, a live exact-address search, and light/dark simulator screenshots of the map, Settings, and search alongside existing route and motion checks.

Reference: https://ignf.github.io/cartes.gouv.fr-documentation/fr/guides-utilisateur/utiliser-les-services-de-la-geoplateforme/geocodage/

# Windows to TrollStore: route motion experiment

Fork: https://github.com/dm2mymcszt-commits/Andromeda

Branch: `experiment/route-motion`. Starting upstream commit:
`bc1e1d3c0646cf03d99d3975c000c49d478bf2a8`.

The Windows folder is a local Git checkout. `origin` points to your GitHub fork;
`upstream` points to Son3ra1n/Andromeda. Creating a folder alone does not create a fork.

## Route preview and motion metadata update (2026-09-09)

Verified package: `build/Andromeda-route-preview.tipa`, compiled from source
`eef41cc7604fe67d1a59528c69107b6755ede8c9` in successful
[Actions run 34380607926](https://github.com/dm2mymcszt-commits/Andromeda/actions/runs/34380607926).
SHA-256: `29810e8dfc71285d1c51f5f176a8089c612d878eaa9b6b8cb6f43418e4d1074a`.
The ZIP, executable ARM64 app/helper/extension, and expected entitlements passed
inspection. New route-map and motion-factory symbols were verified in the executable.
The package reports version 2.5.2, build 1: the Xcode project version overrides the
source plist's build value. Use the package filename/commit/checksum to distinguish
this build from the older working packages, which are retained separately.

All workflow checks passed. The Core Location runtime baseline measured the older
initializer's `speedAccuracy = -1` and `courseAccuracy = -1`; the new factory tests
verified explicit moving accuracy values and stationary/invalid-input handling.
These measurements are from the macOS test runtime, not the user's iPhone.
The actual map/card views passed iPhone 12 simulator interaction and initial-layout
checks, and four dark/light screenshots in `build/route-map-preview/` were visually
inspected. The synthetic fixtures are clearly labeled. This validates presentation
and model behavior, not Snapchat's activity classifier or live route traffic accuracy.

This update addresses the reported route display and duration defects. The Snapchat
car/Actionmoji outcome is **not verified**: the earlier speed/course experiment did
not solve it on the user's phone. A Google Maps navigation car or speed display
does not establish which contextual signals Snapchat is using.

The route chooser now contains a map preview with numbered ETA badges and A/B
start/destination markers. Numbers and colors match the choices below it; selecting
a line, badge, or card highlights the same route. Alternatives stay visible beneath
the selected route. Recalculation replaces geometry even when the route count stays
the same. The map fits all alternatives, and preview taps never inject a location.
Closing and reopening route setup retains the calculated choices. Starting closes
the sheet to show movement on the main map.

Apple Maps calculates the road routes with the selected travel mode and current
departure time. Returned routes are ordered by their expected travel time before
labeling the fastest one. Apple and Google may return different paths/estimates;
this does not attempt to copy Google traffic data. Each choice shows its own
simulation duration at the selected constant speed, including at 1x. Changing speed
updates those durations and the sampled path without another directions request.
Changing endpoints/mode cancels and clears old results. Cycling retains the existing
walking-path routing behavior; the provider integration has not added bicycle routing.

Motion locations now include explicit speed/course accuracy values. Their zero
accuracy describes the deterministic simulation model, not a real sensor reading.
The former initializer's default accuracy values are printed by the runtime test.
Coordinates/altitude no longer receive random jitter, the destination is held exactly
with zero speed, and invalid/nonpositive speeds cannot enter the sampling loop.
Pause/resume preserves motion validity. The private system injection mechanism is
unchanged; no Core Motion activity or Snapchat state is altered.

References: [Apple speed accuracy](https://developer.apple.com/documentation/corelocation/cllocation/speedaccuracy),
[Apple course accuracy](https://developer.apple.com/documentation/corelocation/cllocation/courseaccuracy),
and [Snapchat Actionmoji support](https://help.snapchat.com/hc/en-us/articles/7012324804628-How-do-I-use-Bitmoji-on-the-Snap-Map-and-what-is-Actionmoji).
Snapchat documents contextual signals including movement and says manually selected
My Pose choices last four hours. It does not document a supported way for Andromeda
to force the driving appearance. Do not interpret successful compilation or GPS
metadata tests as proof that the Bitmoji switches to a car.

Verification is performed by the macOS Actions build, production Swift sampling and
motion-factory tests, and an isolated iPhone simulator app using the actual map and
route-card views with synthetic fixtures. These fixtures test map behavior and layout,
not the accuracy of live Bordeaux directions. On-device checks still needed: compare
three alternatives and their markers, select each route, change speed, recalculate
another destination with the same route count, start/pause/resume/finish, and observe
Snapchat during a sustained driving simulation. Avoid selecting a manual My Pose
while checking its automatic behavior.

## Route picker update

Device package: `build/Andromeda-route-picker.tipa`, compiled from commit
`6c5b46b8ad64e4a4613207977638420d9df8cb6b` in
[Actions run 34238726647](https://github.com/dm2mymcszt-commits/Andromeda/actions/runs/34238726647).
ZIP integrity, ARM64 executables, and the app/helper/extension entitlements were
verified after downloading. SHA-256:
`8aefbd1c723a2c76d1b7b315e0b2a24a7c3d55a92f24e0ebcb68bcb75793d18c`.
The original speed/course-only package remains at `build/Geranium.tipa` for rollback.
The full workflow passed, including recent-place storage tests and an iPhone 12
simulator capture of the production destination picker. The screenshot was visually
checked for readable controls and clipping and is saved at
`build/route-picker-preview/destination-picker.png`. Live search, permissions and
location simulation still require the on-device acceptance checks below.

The follow-up adds the requested route setup UI on top of the speed/course experiment.
Opening route setup requests **Current Location** as the start. Tap either endpoint
to search with live Apple Maps suggestions, pick a recently selected place, or use
**Choose on Map**. On that separate map, pan/zoom, tap a point, and press **Use as
Destination** (or **Use as Start Point**). Map browsing does not inject a location.
Current Location is a snapshot of the position reported by iOS, which can already
be simulated if spoofing is active. Permission failures provide retry and manual
selection; a delayed fix cannot overwrite a manually chosen start.

Recent places are saved only on this device, deduplicated, limited to 12 entries,
and individually removable. They begin accumulating with this update; Google Maps
history is not imported. A map-selected point is saved as "Map pin" with coordinates.
Search errors allow retry or another selection method. Current-location lookup
times out after 15 seconds if an authorized location request does not return a fix.

Additional files changed:

- `Geranium/LocSim/RouteLocationPicker.swift`: location lookup, cancellable address
  suggestions/search, local recent places, and the confirmation map.
- `Geranium/LocSim/RouteSimView.swift`: endpoint chooser cards, default current start,
  and invalidation of calculated routes when either endpoint changes. Inputs are
  disabled while route calculation is pending. GPX selection cancels current-start lookup.
- `Geranium.xcodeproj/project.pbxproj`: registers the new Swift source with the app target.
- `Tests/RoutePicker/main.swift`: checks recent-place retention, duplicate handling,
  persistence, removal, invalid coordinates and corrupt stored data.
- `Tests/RoutePicker/Preview.swift`: isolated simulator preview of the production
  picker using sample Paris destinations; it is never included in the TrollStore app.
- `Tests/RoutePicker/check.sh` and `.github/workflows/trollstore.yml`: run those checks
  and capture/upload an iPhone 12 picker screenshot after the device package build.

On-device acceptance checks: open route setup with location allowed, denied and
temporarily unavailable; select a different start while location lookup is pending;
type a partial destination and choose a suggestion; clear/change a query while search
is pending; cancel a picker and verify the endpoint stays unchanged; select and confirm
a map pin; reopen the app and reuse/remove a recent place; then calculate/start a
route and check the earlier speed/course behavior. Map selection should never teleport
the phone until you explicitly start simulation. Search and map tiles need connectivity;
stored coordinates remain available offline, while route calculation still needs MapKit.

## Changes

- `Geranium/LocSim/RouteSimulator.swift`: supplies CLLocation speed in metres per
  second (travel mode times multiplier), and initial bearing towards the next
  unjittered route point, in degrees clockwise from true north, normalized to
  [0, 360). Uses the existing WGS-84 conversion for both bearing endpoints.
  Duplicate points and the destination report zero speed and retain the previous
  bearing (zero before a direction exists). Pause/resume refreshes motion at the
  exact last injected coordinate. Route interpolation, one-second timer, jitter,
  altitude, progress, route choice, and stop/hold behavior remain in place.
- `ipabuild.sh`: disables Xcode's separate debug dylib so the existing ldid step
  signs the executable containing the app code; removes a signature only when
  present; quotes RootHelper paths. Still builds Debug, rebuilds RootHelper from
  its pinned submodule, applies existing entitlements, and writes `build/Geranium.tipa`.
- `.github/workflows/trollstore.yml`: builds on macOS 15 / Xcode 16.4, installs
  ldid and GNU Make, fetches pinned Theos and its patched iOS 14.5 SDK required by
  RootHelper's unchanged Makefile, invokes `ipabuild.sh`, checks the ZIP, and uploads
  the package and build log. No signing certificate or Apple developer account
  is needed. The app is built with Xcode's SDK; 14.5 is only the helper build SDK.
- `BUILD-TROLLSTORE.md`: these build, test, and rollback instructions.

## Trigger and download

1. Open the fork's **Actions** tab. If GitHub asks to enable workflows for the
   fork, enable them.
2. Push a code change to `experiment/route-motion` to trigger the build. For an
   existing run, choose **Re-run all jobs** to rebuild that exact commit.
3. Once the workflow exists on the repository's default branch, you can also
   select **Build TrollStore package > Run workflow**, choose the experiment
   branch, and run it manually. GitHub only exposes manual dispatch when the
   workflow is present on the default branch; this experiment leaves main intact.
4. Open the successful run and download **Andromeda-route-motion-<commit>** under
   **Artifacts** while signed into GitHub. Extract the downloaded ZIP to get
   `Geranium.tipa` (the internal build name is inherited; the app is Andromeda).
5. Transfer the `.tipa` to iPhone Files, or download/extract the artifact directly
   on the phone. In TrollStore, tap **+**, choose the `.tipa`, and install/update it.
   This preserves the upstream bundle identifier, so it updates the existing app.

From PowerShell in this folder, after a change has been committed:

```powershell
git push origin experiment/route-motion
gh run list --repo dm2mymcszt-commits/Andromeda --branch experiment/route-motion
gh run download RUN_ID --repo dm2mymcszt-commits/Andromeda --dir build/download
```

## Test on iPhone 12 / iOS 17.0

Build validation on 2026-09-08: [Actions run 34236216427](https://github.com/dm2mymcszt-commits/Andromeda/actions/runs/34236216427)
passed using source commit `e9db6db81ec44c170c8e226f8b9b504858654906`.
The downloaded archive passed ZIP integrity checks; the app, rebuilt RootHelper,
and bookmark extension are executable ARM64 binaries with XML entitlements
matching their respective source plists. No separate debug dylib is packaged.
The app reports minimum iOS 15.0. These checks do not replace device testing.
The local package is `build/Geranium.tipa`; its SHA-256 is
`87e665d3a3ade50c25999ca9230bc7e6d7dd32da853ee0f08a38e0038bd6d463`.

Save a copy of your working `.tipa` before installing this experiment. Test the
same short route before and after, with the same mode and multiplier:

1. Driving at 1x should inject 13.9 m/s (~50 km/h), walking 1.4 m/s,
   cycling 5.5 m/s; 2x should double these values.
2. Check turns and movement visually. With a Core Location diagnostic app, check
   that moving fixes have nonnegative speed and course in [0, 360).
3. Pause: position should hold and speed should be zero. Resume: selected speed
   should return and movement should continue at the next normal timer tick.
4. Let the route finish: destination should hold with speed zero. Stop explicitly
   to restore real location. Also check one background/foreground cycle.
5. Observe Snapchat separately. A correct CLLocation does not establish that
   Snapchat will show a driving Bitmoji; its activity classification and whether
   iOS propagates these private simulation fields require device testing.

Speed is the configured simulation speed, not a measurement of timer delays or
the exact displacement between jittered fixes. Course uses the next route segment;
at rest it retains a numeric bearing and does not imply actual movement.

## Rollback

Install your saved original `.tipa` through TrollStore to revert the device.
The source experiment is isolated on its own branch and upstream/main is unchanged.
Revert the route motion commit to undo the experiment while keeping CI, or switch
to `main` to inspect the original source. Do not delete the app to test a rollback.

## References

- [Apple CLLocation initializer](https://developer.apple.com/documentation/corelocation/cllocation/init(coordinate:altitude:horizontalaccuracy:verticalaccuracy:course:speed:timestamp:))
- [Theos macOS requirements](https://theos.dev/docs/installation-macos)
- [Theos patched SDKs](https://github.com/theos/sdks)
- [GitHub manual workflows](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
