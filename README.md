# TrollRoute

Location simulation and route playback for TrollStore. Set a location, save favorites, search worldwide, import GPX files, or play walking, cycling and driving routes with adjustable speed, progress seeking and finish actions.

Requires iOS 15.0 or later on a version supported by [TrollStore](https://github.com/opa334/TrollStore). This is a TrollStore-only app.

## Install and build

Use the successful [GitHub Actions build](https://github.com/dm2mymcszt-commits/TrollRoute/actions/workflows/trollstore.yml) on `experiment/route-motion`. Download `TrollRoute-<version>-<commit>`, extract `TrollRoute.tipa`, and install through TrollStore's **+** button.

The new bundle ID installs alongside Andromeda. This rework is in progress: the first launch imports saved places and settings read-only. Keep Andromeda and its data until that import completes successfully and you have checked the values. The new icon also awaits approval.

Builds use macOS 15 and Xcode 16.4 through `ipabuild.sh`; the workflow runs model tests, live search checks and simulator previews. See [BUILD-TROLLSTORE.md](BUILD-TROLLSTORE.md) for verification and installation notes.

## Credits and license

Based on Andromeda by son3ra1n and Geranium by c22dev. GPL-3.0. See [LICENSE](LICENSE).

Data: Apple Maps, © OpenStreetMap contributors, national address and elevation services. See [data credits and licenses](THIRD-PARTY-NOTICES.md).

GitHub Releases are created only on the owner's explicit request, with the `.tipa` from a successful CI run and notes describing additions, changes and fixes. Ordinary development builds are Actions artifacts, not Releases.
