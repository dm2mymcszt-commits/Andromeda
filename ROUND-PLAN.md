# TrollRoute: rework round

## Part A. Read this first

### A1. Context
- Repository: `dm2mymcszt-commits/Andromeda` (renamed to `TrollRoute` in Phase 1). Working branch: `experiment/route-motion`. Last delivered build: commit `546ffb2`, version 2.6.0 (build 4).
- TrollRoute is a **TrollStore-only** iOS app. TrollStore runs on iOS 14.0–16.6.1, 16.7 RC and 17.0; no TrollStore device runs anything newer. The app's current minimum is iOS 15.0.
- The owner uses Windows, has no Mac, and relies on the GitHub Actions workflow to build the `.tipa`. CI (macOS 15, Xcode 16.4) and the owner's tests on a TrollStore device are the only checks.
- **Never name a specific phone model as the owner's device** in app text, docs, commit messages or release notes.
- I'm attaching screenshots of the current app and bugs, plus the approved icon reference. The written requirements win over screenshots. Don't infer new requirements from a screenshot; ask me.

### A2. Rules
1. This document is the source of truth. Items are labeled:
   - **[Required]**: confirmed by the owner. Implement exactly. Don't reinterpret, simplify, strengthen, weaken, add to or remove.
   - **[Decision]**: the owner's answer to a conflict question. Implement exactly.
   - **[Finding]**: a problem found in a code review; the owner asked for it to be fixed.
   - **[Suggestion]** / **Reviewer note**: an implementation idea or technical note from the reviewer. Follow it unless you find a better way that still meets the requirement; report what you did.
2. If requirements conflict, or something can't work technically on TrollStore/iOS as described, **stop that item and ask me** with the options. Never silently substitute different behavior or ship a fallback I didn't approve.
3. **Fix root causes.** Before fixing a bug, confirm its cause in code (and with a failing test where practical) and write it in the progress file. No masking timers, polling workarounds or arbitrary delays.
4. **Preserve existing behavior** I didn't ask to change (Part D). If a test encodes behavior a requirement changes, update the test; all other tests must keep passing.
5. **Rework, not random rewrite**: restructure or rewrite poorly built parts where this work touches them or where Phase 2 says so. Don't replace working code just to restyle it. Avoid unrelated changes and features not listed here (e.g. no train/plane modes, no extra Live Activity content, no other notification types).
6. **Don't break the Snapchat driving Bitmoji.** Route motion metadata (`RouteLocationSample`: speed, course, accuracies) must stay consistent. Any change to how or when locations are injected goes in its own commit and is flagged for the owner's phone test.
7. **GitHub actions that are destructive or outward-facing** (renaming the repository, changing the default branch, deleting tags) need my explicit "yes" in chat for the exact list. Prepare them, ask, and keep working on other phases while you wait.
8. **Never create or publish a GitHub Release** unless I explicitly ask. When I do ask, the release must contain the `.tipa` built by GitHub Actions and proper release notes (added / changed / fixed).
9. **Three systems stay separate** in code, UI and wording:
   - **Main Stop** (toolbar): stops location spoofing itself. Setting: "Confirm before stopping location spoofing".
   - **Route Stop** (route controls): stops the running route and asks what happens to the location.
   - **Route finish action**: what happens when a route naturally reaches its end. Default in Settings, chosen per route before starting, changeable while the route runs.

### A3. Work method (progress files and usage limits)
- Before coding: save this whole document in the repo as `ROUND-PLAN.md`, and create `ROUND-PROGRESS.md` listing every phase task and item ID (R1–R32, F1–F6).
- Work phase by phase, in order. **Commit and push after each item** (or smaller step) as soon as it builds and its tests pass; every commit must build. Each push runs CI and produces a `.tipa`.
- After each commit, update `ROUND-PROGRESS.md`: status, commit hash, confirmed root cause (for bugs), what's left, the exact next step, open questions for me, and anything waiting for my approval or phone test.
- **I often hit my usage limit.** When I tell you to continue: re-read `ROUND-PLAN.md` and `ROUND-PROGRESS.md`, check `git status` and `git log` to confirm what's really committed, then continue from the next unfinished step. Don't redo finished items and don't simplify the remaining ones.
- Items waiting for my approval or phone test don't block other work: record them and continue.
- Delete `ROUND-PLAN.md` and `ROUND-PROGRESS.md` in the final commit.

---

## Part B. Verified facts about the current code (checked at `546ffb2`)
These are starting points. Re-check them in Phase 0 before relying on them.

**Identity and build**
- Bundle IDs: app `com.son3ra1n.andromeda`, share extension `com.son3ra1n.andromeda.bookmark`, test targets `com.son3ra1n.andromedaTests` / `UITests`. App group: `group.live.cclerc.geraniumBookmarks` (Favorites and the share inbox).
- The Xcode project, target, scheme, source folder and executable are still named `Geranium`. The extension target/folder/executable is `Bookmark Location in Geranium`. `ipabuild.sh` builds `Geranium.tipa`; CI uploads the artifact `Andromeda-route-motion-<sha>`.
- About 30 files mention "Andromeda" and about 30 mention "Geranium". These include `Localizable.xcstrings` strings for removed features, `icon.sketch`, `Assets/Screenshots/` and `Media/`.
- `Geranium/Info.plist`: display name Andromeda; all location usage strings read "Andromeda needs your location for simulation."; background modes `location` and `processing`; no URL scheme (`CFBundleURLTypes`).
- App icon: a single 1024×1024 PNG (`Assets.xcassets/AppIcon.appiconset/geranium.png`). CI's Xcode 16.4 can't build Icon Composer `.icon` files (those need Xcode 26+).
- The root helper appears dead. Its only call is `RootHelper.loadMCM()` in `GeraniumApp.swift`, which spawns `GeraniumRootHelper` with empty arguments. Every other `RootHelper` function belongs to removed features. Building it is the reason CI installs Theos and the iOS 14.5 SDK.
- The app's entitlements (`entitlements.plist`, `Geranium/Geranium.entitlements`) mix what location simulation needs (`com.apple.locationd.simulation`, no-sandbox, platform-application) with leftovers from removed features (MobileInstallation, uninstall deletion, WebClips, managed configuration, …). The share extension only has the app-group entitlement, so today it can't inject a location itself.
- `BUILD-TROLLSTORE.md` names a phone model in a heading; this must be removed.

**GitHub (checked 2026-09-13)**
- The repository is a public fork of `Son3ra1n/Andromeda`. Default branch: `main` (upstream commit `bc1e1d3`). Description: "The Ultimate iOS Utility for TrollStore — Advanced LocSim, Cleaner, and more."
- **No GitHub Releases exist on the fork.** There are 14 old tags: `1.0`, `1.0-RC1`, `1.0-RC2`, `1.0.1`, `1.0.2`, `1.0.3`, `1.0.4`, `1.1`, `1.1.1`, `1.1.2`, `1.1.3`, `v2.5.0`, `v2.5.1`, `v2.5.2`.

**Behavior and bugs**
- **Toolbar (R6):** in `LocSimView.swift`, `FloatingQuickMenu` sits inside a `ScrollView` whose frame only sets a width. The ScrollView fills the full screen height, so the empty strip below Stop is part of a scroll view. Dragging there scrolls/bounces the menu and blocks map gestures in that strip. Likely root cause; confirm it.
- **Main Stop (R5):** `QuickMenuAction.stop` → `LocSimView.stopSimulation()` → `routeSimulator.stopSimulation()` → `LocSimManager.stopLocSim()`, immediately, with no confirmation.
- **Route Stop (R15):** the Stop button in the Route in progress panel calls the same `LocSimView.stopSimulation()`. The Navigation sheet's status-card Stop and toolbar stop icon call `routeSimulator.stopSimulation()` directly. All of them restore the real location.
- **Finish action (R11–R13):** `RouteSimulator.startSimulation()` copies `RouteFinishSettings.shared` into `finishState` once, and nothing can change it for the active route.
- **Credits (R14):** `LocSimView`'s bottom `safeAreaInset` shows the OpenStreetMap credit line whenever the travel mode is cycling and routes exist, including during simulation, stacked under the playback panel.
- **Share handoff (R7–R9):** the extension writes a JSON request into the app group (`SharedPlaceInbox`) and shows "Ready. Open Andromeda to continue." The app only checks that inbox in `onAppear`, when `scenePhase` becomes active, and after sheets close (`offerSharedPlace`). The extension sends no signal. In the `scenePhase` handler, `offerSharedPlace()` re-reads `self.scenePhase` instead of using the new phase value, which is a suspect for the delay. Confirm the real cause.
- **Spoofed-location state is scattered:** `LocSimView` (`lat`, `long`, `joystickCoordinate`), `RouteSimulator.currentPosition`, `AltitudeController.activeLocation`, and the static `LocSimManager`. Nothing records the spoofed location that was active before a route started, and the share extension can't see any of it.
- **Injection cadence (F2):** route updates run every 0.25 s. Each sample calls `LocSimManager.inject`, which stops, clears and restarts the simulation and posts `AutomaticTimeZoneUpdateNeeded`. Dragging the live-speed slider also injects on every slider change.
- **Altitude (F1):** `AltitudeController` looks up elevation at most every 10 s and only reuses a result within 45 m. So while driving, most samples report unknown altitude (verticalAccuracy −1), and at 500 km/h almost all do. Walking is fine.
- **Seeking (F3):** while a finger is on the progress bar, `previewSeek` freezes the journey and injects speed 0.

---

## Part C. Phases
Each phase lists its items, then acceptance checks. Complete a phase's checks before starting the next one, except items waiting for my approval or phone test.

### Phase 0: Audit and plan (no behavior changes)
1. Confirm every Part B fact; correct any that are wrong in `ROUND-PROGRESS.md`.
2. Confirm the root causes for R6, R9, R14, F1, F2 and F3. Cite the code, and add a failing test where practical.
3. Inventory the old identity: every occurrence of "Andromeda", "Geranium", "son3ra1n" and "cclerc", classified as **rename** (identity), **keep** (credit, license, history, migration) or **technical** (with the plan for it).
4. Dead-code list: root helper, unused `Addon.swift` helpers, first-run leftovers, and stale translations/media for removed features, with proof that each is unused.
5. **Entitlement audit table**: each entitlement, what uses it, and a keep/remove recommendation. **Don't remove any entitlement until I approve the table.**
6. A short architecture note in `ROUND-PROGRESS.md` for the shared state in Phase 2: `LocationSession`, the route session, and the app ↔ extension command channel.

**Acceptance:** docs only; CI still green. The audit results, the entitlement table and any open questions are in `ROUND-PROGRESS.md` and posted to me.

### Phase 1: TrollRoute identity (R1), data migration, icon (R4), repository (R2)

**R1 [Required] Rename Andromeda to TrollRoute completely.** This is not just a display-name change. Change the identity wherever it is genuinely part of the old identity:
- user-facing labels (for example "Andromeda Navigation" → "TrollRoute Navigation", the share extension title, the name on notifications, and alerts such as "Andromeda wasn't installed with TrollStore");
- README, documentation and installation/build references;
- CI artifact names;
- project/target/scheme/folder/file names.

Inspect context: don't blindly replace strings that are technical identifiers or attribution.
- Reviewer note: keep the credit line "Based on Andromeda by son3ra1n and Geranium by c22dev. GPL-3.0." and the license notices. That's attribution, not identity.
- **[Decision] New technical identity.** Use new bundle IDs and a new app group, so TrollStore installs TrollRoute as a separate app. [Suggestion] IDs:
  - app: `com.dm2mymcszt.trollroute`
  - share extension: `com.dm2mymcszt.trollroute.share`
  - Live Activity widget: `com.dm2mymcszt.trollroute.liveactivity`
  - app group: `group.com.dm2mymcszt.trollroute`
  - URL scheme: `trollroute`

  Rename the Xcode project, targets, scheme and executable to TrollRoute. Update `ipabuild.sh` (output `TrollRoute.tipa`), CI (artifact `TrollRoute-<version>-<sha>`) and the test scripts.
- **[Decision] One-time import from the old app.** On first launch, import from Andromeda (the `com.son3ra1n.andromeda` defaults and the `group.live.cclerc.geraniumBookmarks` group):
  - Favorites, recent places and the after-route place;
  - the route-finish default and per-mode speeds;
  - the altitude profile and map settings.

  Rules for the import:
  - Read only. Never modify or delete the old app's data.
  - Run once, then show a one-time summary of what was imported and say that Andromeda can now be deleted.
  - Find a reliable TrollStore-compatible way to read the old data (for example, temporarily adding the old app group to TrollRoute's entitlements for reading).
  - Test with fixtures, and flag it for my phone test.
- Until I delete Andromeda, both apps' share actions will appear. My Google Maps share sheet also shows an entry "Bookmark Location in Geranium" next to "Andromeda". Check whether any Andromeda/TrollRoute package produces it. If it comes from a different installed app, leave it alone and tell me.
- Network user agents (Photon, OSM routing, Open-Meteo, IGN): `TrollRoute/<version> (https://github.com/dm2mymcszt-commits/TrollRoute)`. The Settings "Source code" link points to the new repository URL.
- **F6 [Finding]** About's "Data sources" line names IGN. Replace the provider list with a generic line such as "Data: Apple Maps, © OpenStreetMap contributors, national address and elevation services", linking to `THIRD-PARTY-NOTICES.md`, which keeps the exact required credits.
- Remove the phone-model heading from `BUILD-TROLLSTORE.md`.

**R4 [Required] New app icon.** The attached reference image is the approved design; save it as `Design/Icon/reference-approved.png`. Don't redesign or reinterpret it:
- dark glossy background;
- one single thick white/pearl route line, large as in the reference, with rounded ends and a soft S-like bend, running from the upper-left area toward the lower-right;
- pronounced glass/metal depth;
- no endpoint circles, no plane, no trails, no extra symbols.

The overall premium, minimal feeling was inspired by the Flighty icon, with a route instead of a plane.
- **[Decision] Full-bleed, no rim.** The dark glossy background fills the whole square and iOS provides the rounded corners. The separate glass rim/frame drawn around the tile in the preview is left out. The route line, gloss and depth stay as in the reference.
- Reviewer note, technical reality: TrollStore devices run iOS 17.0 or older, which display a flat icon image (no Liquid Glass or layered rendering), and CI's Xcode 16.4 can't build Icon Composer files. So:
  - Recreate the artwork cleanly as **separated vector layers** (background, route line, shading/highlights) in `Design/Icon/`, with a script that renders them deterministically.
  - Ship a 1024×1024 PNG rendered from those layers: no transparency, no pre-rounded corners, depth baked in as in the reference.
  - Keep the layers suitable for a future Icon Composer `.icon` document. Don't upgrade CI to Xcode 26 just for the icon. If you can add a `.icon` source without affecting the build, tell me.
- Once the new icon ships, remove the old icon files (`geranium.png`, `icon.sketch`).
- **Approval checkpoint:** post a comparison image in chat and as a CI artifact. It should show the reference next to your render at 1024 px, plus your render with the iOS icon mask at Home Screen size on a light and a dark wallpaper. Mark "icon awaiting approval" in progress and keep working on other phases. Only ship the new icon in the app after I approve.

**R2 [Required] Repository, branches and releases**
- Rename the GitHub repository from `Andromeda` to `TrollRoute`.
- Update the GitHub About/description. [Suggestion] "Location simulation and route playback for TrollStore."
- Make `experiment/route-motion` the default branch. Don't delete or rename `main`.
- Remove the old release history:
  - Releases: none exist on the fork; if any exist when you check, list them.
  - Tags: delete the 14 old tags listed in Part B.
- **Prepare the exact command list, ask me, and execute only after my "yes".** Afterwards, update the local `origin` URL and all links.
- Release policy: document how a release is made. It happens only when I ask; the asset is the `.tipa` built by GitHub Actions; the notes explain what was added, changed and fixed. **Don't create a release.**

**Phase 1 acceptance**
- The app name, share action title, notifications, Settings and Navigation title all say TrollRoute. Any remaining Andromeda/Geranium matches are listed with reasons (credit, license, migration).
- CI builds `TrollRoute.tipa` with the new bundle IDs; the extensions are signed; entitlements are unchanged except the old group if it's used read-only for migration.
- Migration unit tests with fixtures pass (favorites, recents, settings, speeds, altitude, after-route place). The import runs once, and the old data stays untouched.
- The icon comparison is posted; the old icon stays in the app until I approve.
- GitHub operations were prepared and confirmed by me before running. No release was created.

### Phase 2: Foundation cleanup and shared state (R3, F1, F2)

**R3 [Required] A coherent, maintainable codebase.** The original Andromeda was 100% AI vibe-coded; TrollRoute must not be Andromeda with a new name and more features stacked on top. Preserve the functionality that should remain, and refactor, restructure or rewrite poor parts where needed. This is not permission to replace working code arbitrarily or to change behavior I didn't ask to change. R3 applies throughout this round; this phase lays the foundation.
- Remove code proven dead in Phase 0: the root helper (binary, `RootHelperMan.swift`, TSUtil if unused, the submodule, the Theos/SDK steps in CI and the copy/sign steps in `ipabuild.sh`), unused helpers, and stale strings/media from removed features. Keep the TrollStore installation check (`checkSandbox`) with TrollRoute wording.
- Entitlements: apply only the removals I approved in Phase 0.
- **[Suggestion] One source of truth for location state.** This shared root cause affects R5, R7, R15–R18, R23, F1 and F2. Create a `LocationSession` owner that knows:
  - whether spoofing is active, and of what kind (static, joystick, route);
  - the current spoofed coordinate and altitude;
  - when a route starts, the spoofed location that was active before it, if any.

  Persist the minimum needed in the app group, so the share extension and Live Activity intents read and update the same state. Replace the scattered copies listed in Part B.
- **F2 [Finding] Injection cadence.**
  - Separate on-screen animation from location injection.
  - Don't restart the simulation and post the time-zone notification for every sample; post the time-zone update when spoofing starts or jumps to a new place.
  - Coalesce slider-driven changes, and choose an injection rate that keeps movement smooth for other apps.
  - ⚠️ This path affects the Snapchat driving Bitmoji. Put it in its own commit, measure before and after in tests, flag it for my phone test, and be ready to revert.
- **F1 [Finding] Automatic altitude during routes.** Altitude must not flip between known and unknown while moving. [Suggestion] When a route is prepared, look up an elevation profile along it in batched requests (respecting Open-Meteo's limits), interpolate along the distance travelled, and hold the last known value while a lookup is pending. Custom altitude behavior stays unchanged.

**Phase 2 acceptance**
- All existing CI tests pass, and the Part D behaviors are unchanged (list what you verified and how).
- New unit tests cover:
  - session transitions: static → route → stop, previous location recorded, joystick, share;
  - altitude staying known along a route with a mocked profile;
  - injection coalescing: no time-zone post per sample.
- If the root helper was removed, CI no longer installs Theos/SDKs; note the new build time.

### Phase 3: Map and toolbar (R5, R6, R18–R21, F5)

**R5 [Required] Confirmation before restoring the real location (main Stop).**
- Add the Settings option "Confirm before stopping location spoofing", default **ON**.
- ON: pressing the main toolbar Stop asks for confirmation before spoofing stops and the real location is restored. The user can cancel or confirm. OFF: the current immediate behavior.
- This concerns only the main Stop button. The Route Stop (R15–R17) is separate.
- [Suggestion] If a route is running, the confirmation says that the route stops too (the main Stop already stops the route today).

**R6 [Required] Invisible draggable area below Stop.**
- The drag/scroll area must match the visible toolbar bounds.
- Dragging in the empty region below Stop must not move the toolbar; it must interact with the map normally.
- Investigate whether the gesture is attached to a larger parent/container or is another hit-box/layout problem (Part B suspects the unbounded `ScrollView`). Keep the menu usable when it doesn't fit the screen (e.g. with button labels on a small screen).

**R18–R21 [Required] Long press to create route.**
- Settings defaults: "Long press to create route" **ON**; "Confirm before creating route from long press" **OFF**; "Automatically start route after long press" **OFF**.
- Long-pressing a point on the map uses my current active location as the start and the pressed point as the destination. The current location can be my real location or an already spoofed one, and it must work in both cases. TrollRoute calculates the route and shows the existing route preview / TrollRoute Navigation interface.
- Confirmation OFF: the route preview is created immediately, with no "Create route to here?". ON: first show a small confirmation such as "Create route to here?", and create the preview only if confirmed.
- Auto-start OFF: long press creates or previews only and never starts moving; I can inspect, configure and start it myself. ON: the route starts automatically once it has been created.
- [Suggestion] When spoofing is active, use `LocationSession`'s current spoofed coordinate as the start; otherwise request the real location, handling denied or reduced accuracy with a clear message (see Phase 6). Use the last selected travel mode. Auto-start uses the selected (first, fastest) route and the Settings default finish action.
- [Suggestion] While a route is already running, keep today's rule (no new route calculation during a simulation) and show a short message instead.
- The long press must not trigger tap-to-set-location, route selection or map zoom. Route lines, badges and annotations keep their current tap behavior.

**F5 [Finding] Save favorites from anywhere.** Today a favorite can only be saved from the current position or through the share sheet. Add "Save as favorite" for search results and map-picked points in the place picker. [Suggestion] A swipe action or star button, with an editable name, using the same storage as Favorites.

**Phase 3 acceptance**
- Tests for:
  - the main Stop confirmation, ON and OFF; Cancel keeps spoofing;
  - the toolbar hit area: a simulator UI test where dragging below Stop pans the map and doesn't move the menu;
  - long press with a real and with a spoofed start;
  - long-press confirmation ON/OFF and auto-start ON/OFF;
  - no conflict with tap-to-set or double-tap zoom;
  - saving a favorite from a search result and from a map pin.
- Settings defaults match Part E.

### Phase 4: Route session: finish action, Route Stop, progress panel (R11–R17, R14, F3)

**R11 [Required] "When a route finishes" becomes a default.** Rename the Settings option to **"Default action when a route finishes"**: the default completion action for new routes, not the only place it's chosen.
- Keep all six existing actions: Stay at destination, Go to a place, Stop location simulation, Restart the route (loop), Drive back to start, Back and forth (repeat).
- Keep the existing default (Stay at destination), and update the footer, which currently says "Applies to the next route".

**R12 [Required] Choose before starting each route.** In the TrollRoute Navigation sheet, before the route starts, add **"When this route finishes"**.
- It is preselected with the Settings default every time a new route is prepared.
- I can leave the default or choose a different action for this route only. Changing it must not change the Settings default.
- Example: the default is Stay at destination; for one route I pick Drive back to start. That route drives back, and the next route is preselected with Stay at destination again.
- [Suggestion] For this route, "Go to a place" uses the place saved in Settings, with "Change place for this route" (search, recents, favorites, map) that doesn't change Settings. If no place is saved, choosing it opens the picker.

**R13 [Required] Change the completion action while the route is active.** The Route in progress panel lets me change what happens when this route finishes.
- If I change it mid-route, the new selection must actually apply when the active route finishes.
- It changes only this route's behavior and never silently modifies the Settings default.
- Replace the one-time snapshot in `RouteSimulator.startSimulation()` with a per-route setting owned by the active route session.
- [Suggestion] Define and document the rule for repeating and return legs: a change applies when the current leg ends. For example, switching from Back and forth to Stay at destination during a return leg stays where that leg ends. Notifications follow the action in force at arrival.

**R15–R17 [Required] Route Stop asks what should happen to the location.**
- Stopping a route and stopping location spoofing are different actions. The Route Stop must not automatically restore the real location.
- It applies to every control that stops the running route:
  - the Stop button next to Pause in the Route in progress panel;
  - the Navigation sheet's status-card and toolbar Stop;
  - the Live Activity Stop (Phase 7).

  The main toolbar Stop keeps its R5 behavior.
- The dialog asks something equivalent to **"Stop route — what should happen to your location?"** It appears **every time**; a Settings default only decides which choice is preselected, and never skips the dialog. [Suggestion] Include Cancel, which keeps the route running.
- **When a spoofed location existed before the route started**, the choices are:
  1. **Return to previous spoofed location**. Example: I'm spoofed at X, I start a route, I press Stop; the route stops and my spoofed location returns to X. It must never expose my real location.
  2. **Stay at current location**: stop moving and keep spoofing at the exact simulated position reached when Stop was pressed.
  3. **Return to route start**: stop and spoof this route's defined start point. This can differ from the previous spoofed location.
  4. **Restore real location**: stop the route and stop spoofing completely.
- **[Decision] When the route started from my real location** (no previous spoofed location), the choices are:
  1. **Stay at current location**
  2. **Return to route start**
  3. **Go to a specific location**: choose on map, recents, favorites or search, then spoof there.
  4. **Restore real location**
  - [Suggestion] Preselect the Settings default if it is one of these choices; otherwise preselect "Stay at current location", which never exposes the real location. "Go to a specific location" only appears in this case.
- **R17:** add the Settings option **"Default action when stopping a route"**, default **Return to previous spoofed location**, with the four normal choices as options. It only decides the preselected choice, and it's separate from R5's setting.
- The "previous spoofed location" is whatever spoofed location was active when the route started: set by search, map tap, a favorite, the joystick, a share action, or a previous route's finish action. Store its altitude too.
- [Suggestion] Choosing "Restore real location" in this dialog doesn't trigger R5's extra confirmation, since it's already an explicit choice.

**R14 [Required] Credits leaking under the active-route panel.** UI that belongs to route creation (e.g. "OpenStreetMap contributors · Routing · Fix the map") must not stay visible underneath or behind the Route in progress panel once a route starts. Fix the root cause (Part B).
- [Suggestion] OpenStreetMap's attribution guidance still expects a credit while OSM-based cycling route data is on screen. If the active route came from OSM routing, put a small credit inside the panel instead of underneath it.

**F3 [Finding] Speed drops to 0 while dragging the progress bar,** which may briefly make Snapchat think I stopped. [Suggestion] Keep the route moving normally while my finger is down, with only the preview marker following my finger, then jump on release. Seeking is otherwise unchanged.

**Phase 4 acceptance**
- Route-session unit tests cover:
  - the per-route action defaulting from Settings;
  - a per-route change never touching Settings;
  - a mid-route change applying at arrival, for each of the six actions including during return legs;
  - the Stop choice sets for both cases, and the preselection rules;
  - each stop outcome leaving the correct `LocationSession` state: previous location restored exactly, current point kept, route start, real location restored, specific location.
- Simulator screenshots show:
  - "When this route finishes" in the Navigation sheet, and the control in the panel;
  - the Stop dialog in both cases;
  - no credits under the panel.
- Motion metadata tests pass, and seeking keeps speed metadata while dragging.

### Phase 5: Google Maps share handoff (R7–R10, F4)
F4 [Finding] (share actions waiting for the app to be opened) duplicates R7–R9 and is covered here.

**R7 [Required] The four share actions**
- **Go there now:** doesn't need to redirect to or open TrollRoute. After it succeeds, the share extension shows a clear success message. The move must really have happened when that message appears.
- **Use as route start:**
  1. accept the shared Google Maps location;
  2. automatically open TrollRoute;
  3. return to the map;
  4. already have that location applied as the route start.

  The user must not have to open TrollRoute manually afterward.
- **Use as route destination:** the same steps, with the location applied as the route destination.
- **Save as favorite:** no app redirection. Save from the share extension and show a clear success confirmation. Keep name editing.
- **[Decision]** For start and destination, TrollRoute opens with the **TrollRoute Navigation sheet** over the map and the shared place already filled in. No second confirmation screen.

**R8 [Required]** Remove the "Ready. Open Andromeda to continue." state for start and destination. Those two actions open TrollRoute automatically.

**R9 [Required] Immediate recognition.** Today the app can take up to about a minute to notice a shared action. It must be recognized essentially immediately. Investigate and fix the communication/state-sharing mechanism between the extension and the app (Part B). No faster-polling workaround.
- [Suggestion] Use one channel for all extension → app commands:
  - the extension opens TrollRoute with a URL that identifies the queued request (`trollroute://shared/<request-id>`);
  - it also posts a Darwin notification, so an already running app reacts at once;
  - the app group keeps the request durable until it has been handled once.

  Reuse this channel for Live Activity commands where it fits.

**R10 [Required] Source label.** When the place was shared from Google Maps, say **"From Google Maps"**, never generic "Maps" or "Apple Maps". All remaining Andromeda naming in this flow becomes TrollRoute.
- [Suggestion] Detect the source from the shared link (Google Maps link vs `maps.apple.com` vs plain text) and label it accordingly ("From Google Maps", "From Apple Maps", "Shared place"). Show the label on the extension screen and as the start/destination card subtitle after handoff.

**Reviewer notes (verify on device)**
- **Opening the app:** action extensions can't open their host app through public APIs (`extensionContext.open` doesn't work for action extensions). On TrollStore a private mechanism is possible, e.g. LSApplicationWorkspace or a responder-chain URL open. Pick one that works on iOS 15–17.0, with any entitlement the extension needs. If opening TrollRoute automatically is impossible on a supported version, stop and tell me; don't silently fall back to "open TrollRoute yourself".
- **Go there now without opening the app:** the extension must perform or trigger the move itself. For example, give the extension the location-simulation entitlement and have it update `LocationSession`.
  - If a route is running in TrollRoute, the app must stop it first (via the Darwin notification), so its next tick can't overwrite the move.
  - Keep the existing warning that moving stops a running route.
  - Apply the saved altitude setting.
- Remove the in-app review sheet only if nothing else still needs it.

**Phase 5 acceptance**
- Unit tests for URL routing; the request lifecycle (queued, handled exactly once, not replayed on relaunch); source labels; the Go-there session update; saving a favorite.
- A test harness that posts a request while the app is active, in the background, and not running: recognized within 1 s when active, and on launch otherwise.
- On-device checklist entries for: auto-open for start and destination, Go there now while idle and while a route runs, and saving a favorite.

### Phase 6: TrollStore registration, location permission, precise location (R29–R32)

**R29 [Required] TrollStore registration.** TrollRoute is TrollStore-only. The current Location permissions button sends the user to iOS Settings without accounting for TrollStore registration. Detect and handle registration as far as technically possible, and don't assume the normal App Store flow.
- **[Decision] Registration status is informational.** Show "TrollStore registration: System" or "User". Tapping explains that switching to User registration in TrollStore is only needed if TrollRoute's page doesn't appear in iOS Settings, and how to switch (TrollStore → Apps → TrollRoute → Switch to "User" Registration). Don't mark System as an error.
- [Suggestion] Detect registration through `LSApplicationProxy`'s application type, as TrollStore does. Offer "Open TrollStore" if TrollStore's URL scheme can be opened; otherwise show instructions only.

**R30 [Required] Location permission onboarding.** After install the app currently has While Using the App.
- Properly evaluate which authorization level TrollRoute's full functionality actually needs. Don't claim that Apple universally recommends Always.
- If ongoing/background route functionality requires Always, implement the proper request flow and clearly explain why it's needed. Don't leave the user to discover missing permissions.
- Reviewer note: location injection itself doesn't use the app's own authorization. The app's location access is used for Current Location (route start, long press) and to keep running in the background during routes. Background updates started in the foreground may work with While Using; starting updates from the background (e.g. a Live Activity Resume while the app is suspended) may need Always. Decide with evidence (tests plus my phone check) and document the result.
- Rewrite the location usage strings (currently "Andromeda needs your location for simulation.") to explain what TrollRoute uses location for.

**R31 [Required] Precise Location / full accuracy.**
- Detect full vs reduced accuracy (`accuracyAuthorization`).
- Clearly recommend or request precise location when needed (e.g. temporary full accuracy with a purpose string).
- Tell me when only approximate accuracy is available, and guide me.
- Never try to change an iOS privacy setting the app isn't allowed to change.

**R32 [Required] Status overview instead of the blind Settings redirect.** Replace the "Location permissions" button with a compact live status overview in the existing Settings style, for example:
- TrollStore registration: System / User
- Location access: <actual level>, ✓ when sufficient
- Precise Location: On / Off

Each row reflects the actual current state and refreshes when I return to the app. A row that isn't configured correctly is clearly marked; tapping it explains what to change and guides me to the right place (iOS location permissions, Precise Location, or TrollStore for registration).

**Phase 6 acceptance**
- Unit tests for the status model across every authorization and accuracy value. The registration row never shows an error for System.
- Simulator screenshots of the overview in good and bad states.
- The authorization decision and its evidence are documented in the progress file.

### Phase 7: Notifications, Live Activity and Dynamic Island (R22–R28)

**R24 [Required + Decision] Configurable route notifications.** Add these Settings toggles and nothing else:
- **"Route finished" notifications.** [Suggestion] Default ON (today's behavior). Keep today's content and rules (repeating modes notify only on the first arrival).
- **"Time Sensitive".** Lets route notifications show during Focus / Do Not Disturb. [Suggestion] Default OFF (today they aren't time-sensitive). It needs the time-sensitive notifications entitlement. Verify on device, and explain in Settings if iOS or Focus settings still block it.

**R22 [Required] Live Activity.** When a simulated route is active, TrollRoute can show a proper iOS Live Activity, which also appears in the Dynamic Island on devices that have a native one.
- It uses the existing route simulation, not a separate navigation engine.
- Settings toggle, default **OFF**; the user must enable it explicitly.

**R23 [Required] Live Activity content.** Show exactly:
- route progress %
- remaining time
- remaining distance
- current route speed
- destination
- a Pause / Resume control
- a Stop control

Values and states update dynamically as the route progresses. Don't add other content; propose ideas separately as suggestions. If "destination" is ambiguous during return legs, ask me.
- The Stop action stays consistent with the Route Stop (R15–R17).
- **[Decision] Stop choices inside the Live Activity.**
  - On iOS 17.0, tapping Stop switches the Live Activity to show the same stop choices as the in-app dialog (plus Cancel) with the same preselection, and choosing one performs it. "Go to a specific location" (real-location case) opens TrollRoute's place picker.
  - On iOS 16.1–16.x, where Live Activity buttons can't run actions in place, tapping Stop opens TrollRoute and shows the normal Stop dialog. Pause/Resume likewise open TrollRoute and act.
- If the choices can't fit legibly in the expanded Dynamic Island, tell me and propose the closest option before shipping a compromise.
- [Suggestion] Implementation outline:
  - a widget extension target (WidgetKit + ActivityKit) for iOS 16.1+, with `NSSupportsLiveActivities`;
  - iOS 17 `LiveActivityIntent` buttons running in the app process through the same command channel as Phase 5;
  - timer-based text and progress views that advance on their own between updates;
  - updates on state changes (speed, pause, seek, leg, finish-action change) and at a modest rate otherwise;
  - sign the new extension in `ipabuild.sh`.

**R25 [Required] Explain Live Activity vs Dynamic Island correctly.**
- Live Activity is the underlying feature.
- On devices with a native Dynamic Island, the Live Activity can additionally appear and be interacted with there.
- On supported devices without one, it works through the native surfaces such as the Lock Screen.

Never describe it as "Dynamic Island falling back into Live Activity".

**R26 [Required] Compatibility.**
- The Dynamic Island was introduced on iPhone 14 Pro / 14 Pro Max and exists on later compatible models, including non-Pro models from the iPhone 15 generation where applicable.
- Don't hardcode a model list (not only "14 Pro / 14 Pro Max / 15 Pro / 15 Pro Max"). Prefer runtime/device capability detection, so newer models keep working.
- Live Activities themselves need a supported iOS/device environment; never claim universal support.
- If the feature can't work on the current OS or device, handle it gracefully in Settings: disable the toggle and show the reason (e.g. iOS older than 16.1, or Live Activities turned off in iOS Settings).
- Reviewer note: there's no public API for Dynamic Island detection, and not every newer model has one (e.g. iPhone 16e has a notch). On TrollStore, a MobileGestalt-based capability check is an option. Check what DynamicCowTS changes, so detection behaves sensibly with it.

**R27 [Required] DynamicCowTS note.** For TrollStore users without a native Dynamic Island who want to add or spoof one externally, include an optional informational note mentioning the separate TrollStore app **DynamicCowTS / DynamicCow**, official repository https://github.com/matteozappia/DynamicCowTS.
- Don't bundle or implement DynamicCow; it's only an external recommendation.
- Compatibility depends on DynamicCowTS's own supported iOS versions, so don't imply it works everywhere.

**R28 [Required] Honest testing status.** Document honestly that the Live Activity can be tested where supported, but native Dynamic Island presentation and interaction haven't been tested on a physical TrollStore device with a native Dynamic Island. Don't claim hardware testing until it has happened. Don't mention my phone model in the app, docs or release notes.

**Phase 7 acceptance**
- Unit tests cover:
  - the activity content state and its updates (pause/resume, speed, seek, leg, finish-action change);
  - the stop-choices state and each outcome;
  - toggles disabled in unsupported environments;
  - the notification toggles and interruption level.
- CI artifacts include simulator screenshots of the Lock Screen and Dynamic Island presentations (compact, minimal, expanded, and the stop-choices state).
- The package contains the signed widget extension, and the app still launches on iOS 15, where ActivityKit is unavailable.

### Phase 8: Docs, full regression, delivery
- **README:** rewrite it for TrollRoute. Cover what it does, that it's TrollStore-only, installation, supported iOS versions, features, credits and license, and data sources. Don't show removed features or phone models.
- **`BUILD-TROLLSTORE.md`:** keep it short. Cover:
  - build, install via TrollStore, and migration from Andromeda;
  - the release policy;
  - this round's on-device checklist, grouped by phase;
  - honest limitations (e.g. no Dynamic Island hardware testing; items only testable on a device).
- Run the Part D regression and every phase's acceptance checks. CI must be green with a `.tipa` built.
- Version [Suggestion]: 3.0.0 for the new identity; the build number keeps increasing.
- **No GitHub Release.**
- Delete `ROUND-PLAN.md` and `ROUND-PROGRESS.md` in the last commit.

---

## Part D. Existing behavior to preserve (regression checklist)
- **Map:** tap-to-set-location off by default, with the "Ask before moving" confirmation; double-tap zoom never moves the location; route lines and badges select routes; the map appearance, style, button labels and haptics settings; joystick; GPX import.
- **Search:** worldwide search, including:
  - the live seven-address test;
  - Google and Apple Maps links, short links and consent redirects;
  - decimal and DMS coordinates, full and short plus codes;
  - "Approximate" labels.

  Also Favorites in every picker, recent places, and Choose on Map.
- **Routes:** walking, cycling and driving with cached mode tabs; saved per-mode km/h speeds; simulated times everywhere, with the shortest route marked Fastest; swapping start and destination; current-location start.
- **Playback:** the main-map panel; seeking forward and backward while moving or paused; live speed from 1 to 500 km/h; pause/resume; collapsing the panel; seeking to 100% finishes the route.
- **Finish actions:** all six; reverse legs follow the same path; repeating modes continue until stopped; current notification rules; continuing in the background and with the phone locked.
- **Altitude:** Automatic and Custom; decimal commas and negative values; Reset; saved and applied to every location action.
- **Motion metadata:** speed, course and accuracies consistent; the destination held at zero speed; the Snapchat driving Bitmoji (owner phone check).
- **Launch:** the TrollStore installation check at launch.
- **Tests:** every existing CI test passes, updated only where a requirement changed the behavior.

## Part E. Settings defaults introduced this round

| Setting | Default |
|---|---|
| Confirm before stopping location spoofing | ON |
| Long press to create route | ON |
| Confirm before creating route from long press | OFF |
| Automatically start route after long press | OFF |
| Default action when a route finishes | Stay at destination (unchanged) |
| Default action when stopping a route | Return to previous spoofed location |
| Live Activity | OFF |
| Route finished notifications | ON ([Suggestion], today's behavior) |
| Time Sensitive notifications | OFF ([Suggestion], today's behavior) |

The Route Stop dialog still appears every time.

## Part F. Final report
- A table: item ID (R1–R32, F1–F6) → done / partial / not done / waiting for approval / needs phone test → confirmed root cause (for bugs) → how you verified it → choices you made, including every [Suggestion] you followed or replaced. **Put partial, not done and waiting items at the top.**
- Then:
  - the on-device checklist;
  - the entitlements that changed;
  - the GitHub operations performed, with my confirmation;
  - confirmation that no GitHub Release was created.


## Owner workflow amendment (2026-09-13)

Keep ROUND-PROGRESS.md short (status, decisions, exact next step). Move long audit evidence into ROUND-AUDIT.md and read relevant sections as needed. Commit and push each audit step. Delete ROUND-AUDIT.md together with ROUND-PLAN.md and ROUND-PROGRESS.md in the final commit.
