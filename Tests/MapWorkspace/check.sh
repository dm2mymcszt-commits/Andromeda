#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
QA_DIR="$PWD/build/map-workspace-qa"
mkdir -p "$QA_DIR"
python3 - "$QA_DIR/AppSettings.swift" <<'PY'
from pathlib import Path
import sys
source = Path('Geranium/GeraniumApp.swift').read_text()
models = source.split('class AppSettings: ObservableObject {')[1].split('var langaugee')[0]
Path(sys.argv[1]).write_text('import SwiftUI\nclass AppSettings: ObservableObject {' + models)
content = Path('Geranium/ContentView.swift').read_text()
assert 'TabView' not in content and 'LocSimView()' in content
project = Path('Geranium.xcodeproj/project.pbxproj').read_text()
for removed in ['HomeView.swift', 'DaemonView.swift', 'CleanerView.swift', 'SuperviseView.swift', 'ByeTimeView.swift']:
    assert removed not in project, f'{removed} remains in the build'
print('PASS: full-screen map entry and unused feature sources removed from the build')
PY
PREVIEW_APP="$QA_DIR/MapWorkspacePreview.app"
mkdir -p "$PREVIEW_APP"
python3 Tests/RoutePicker/bookmark-support.py "$QA_DIR/Bookmarks.swift"
xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios17.0-simulator \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  Geranium/LocSim/CustomMapView.swift Geranium/LocSim/FloatingQuickMenu.swift \
  Geranium/LocSim/RouteLocationPicker.swift Geranium/LocSim/PlaceModels.swift Geranium/LocSim/PlaceInput.swift Geranium/LocSim/AddressQuery.swift Geranium/LocSim/PlaceSearch.swift Geranium/SettingsView.swift \
  Geranium/LocSim/MapMoveConfirmation.swift \
  Geranium/LocSim/CoordTransform.swift "$QA_DIR/Bookmarks.swift" \
  "$QA_DIR/AppSettings.swift" Tests/MapWorkspace/Preview.swift \
  -o "$PREVIEW_APP/MapWorkspacePreview"
python3 - "$PREVIEW_APP/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'wb') as f:
    plistlib.dump(dict(CFBundleIdentifier='local.andromeda.workspacepreview',
        CFBundleExecutable='MapWorkspacePreview', CFBundleName='MapWorkspacePreview',
        CFBundleShortVersionString='2.5.2', CFBundleVersion='3',
        CFBundlePackageType='APPL', MinimumOSVersion='17.0', UIDeviceFamily=[1],
        UILaunchScreen={}, NSLocationWhenInUseUsageDescription='Preview the map.'), f)
PY
RUNTIME=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; print(next(r["identifier"] for r in json.load(sys.stdin)["runtimes"] if r["isAvailable"] and "iOS" in r["name"]))')
DEVICE=$(xcrun simctl create MapWorkspaceQA com.apple.CoreSimulator.SimDeviceType.iPhone-12 "$RUNTIME")
trap 'xcrun simctl shutdown "$DEVICE" || true; xcrun simctl delete "$DEVICE" || true' EXIT
xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl status_bar "$DEVICE" override --time '9:41' --batteryState charged --batteryLevel 100
xcrun simctl install "$DEVICE" "$PREVIEW_APP"
CONTAINER=$(xcrun simctl get_app_container "$DEVICE" local.andromeda.workspacepreview data)
for appearance in dark light; do
  xcrun simctl ui "$DEVICE" appearance "$appearance"
  for screen in map settings settings-enabled confirmation search; do
    xcrun simctl terminate "$DEVICE" local.andromeda.workspacepreview 2>/dev/null || true
    xcrun simctl launch "$DEVICE" local.andromeda.workspacepreview --screen "$screen" --appearance "$appearance"
    if test "$screen" = search; then sleep 20; else sleep 5; fi
    if test "$screen" = map; then
      python3 - "$CONTAINER/Documents/menu-width.txt" <<'PY'
from pathlib import Path
import sys
result = Path(sys.argv[1]).read_text()
assert result.startswith('PASS:'), result
print(result)
PY
    fi
    xcrun simctl io "$DEVICE" screenshot "$QA_DIR/$screen-$appearance.png"
  done
done
