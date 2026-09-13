# TrollRoute - TrollStore build

CI uses macOS 15 / Xcode 16.4 on `experiment/route-motion`. Download a successful run's **TrollRoute-<version>-<commit>** artifact, extract `TrollRoute.tipa`, and install with TrollStore's **+** button.

TrollRoute uses `com.dm2mymcszt.trollroute` and installs separately from Andromeda. Keep Andromeda until the migration reports a successful import. Both share actions can appear while both apps are installed. Migration implementation and the icon approval are still pending in this development checkpoint.

This round is in progress. The repository and application identity are being renamed; existing location and route behavior is preserved. Simulator/CI checks cannot verify TrollStore injection, background playback or Snapchat's driving Bitmoji on a physical device.

## Device checks

- Confirm TrollRoute installs separately and its share action has the correct name.
- After migration is delivered: check favorites, recents, per-mode speeds, finish action/place, altitude and map settings; verify Andromeda's original data is unchanged before deleting it.
- Recheck static moves, search, joystick, GPX, routes and Snapchat's driving Bitmoji.

## Release policy

Create a GitHub Release only when explicitly requested by the owner. Attach the `.tipa` produced by the successful GitHub Actions run, and write added / changed / fixed notes. No Release is created for this round unless separately requested.
