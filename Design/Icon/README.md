# Approved icon source

`reference-approved.png` is the owner's original reference, copied unchanged. Three SVG layers recreate its pearl route and glossy dark background: `background.svg`, `route.svg`, and `shading.svg`. The separate outside frame is omitted as requested.

From this directory, run `npm ci --ignore-scripts`, `node render.cjs`, then `python3 compare.py` with Pillow installed. The renderer is pinned to resvg-js 2.6.2; there are no random values, remote assets or system-font dependencies in the icon. `output/icon.png` is an opaque, full-bleed 1024×1024 PNG. `output/comparison.png` shows the reference and render at 1024 pixels plus masked Home Screen previews on light/dark backgrounds. The preview mask approximates iOS continuous corners; it is never baked into the icon.

The owner approved the comparison from commit `1349f7f` on 2026-09-13. The app ships that exact opaque render as `TrollRoute.png`. The renderer does not overwrite the asset catalog; approved updates are copied explicitly.

The separated vector layers can be imported into Icon Composer in a future toolchain. No unverified `.icon` document is added, and CI remains on Xcode 16.4. TrollStore-era iOS uses the flat PNG, with depth baked into it.

The build-only renderer is [resvg-js](https://github.com/thx/resvg-js), MPL-2.0; it is not shipped in the app.
