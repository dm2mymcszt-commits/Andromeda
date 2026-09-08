# Windows to TrollStore: route motion experiment

Fork: https://github.com/dm2mymcszt-commits/Andromeda

Branch: `experiment/route-motion`. Starting upstream commit:
`bc1e1d3c0646cf03d99d3975c000c49d478bf2a8`.

The Windows folder is a local Git checkout. `origin` points to your GitHub fork;
`upstream` points to Son3ra1n/Andromeda. Creating a folder alone does not create a fork.

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
