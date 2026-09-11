#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
QA_DIR="$PWD/build/route-picker-qa"
mkdir -p "$QA_DIR"
python3 Tests/RoutePicker/bookmark-support.py "$QA_DIR/Bookmarks.swift"
xcrun swiftc Geranium/LocSim/PlaceModels.swift Geranium/LocSim/PlaceInput.swift Geranium/LocSim/AddressQuery.swift Geranium/LocSim/PlaceSearch.swift "$QA_DIR/Bookmarks.swift" Geranium/LocSim/CoordTransform.swift \
  Tests/RoutePicker/main.swift -o "$QA_DIR/model-tests"
"$QA_DIR/model-tests"

# Render the actual SwiftUI picker in an isolated iPhone simulator app.
PREVIEW_APP="$QA_DIR/RoutePickerPreview.app"
mkdir -p "$PREVIEW_APP"
xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios17.0-simulator \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  Geranium/LocSim/RouteLocationPicker.swift Geranium/LocSim/PlaceModels.swift Geranium/LocSim/PlaceInput.swift Geranium/LocSim/AddressQuery.swift Geranium/LocSim/PlaceSearch.swift Geranium/LocSim/CoordTransform.swift \
  "$QA_DIR/Bookmarks.swift" Tests/RoutePicker/Preview.swift \
  -o "$PREVIEW_APP/RoutePickerPreview"
python3 - "$PREVIEW_APP/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'wb') as f:
    plistlib.dump(dict(CFBundleIdentifier='local.andromeda.routepickerpreview',
        CFBundleExecutable='RoutePickerPreview', CFBundleName='RoutePickerPreview',
        CFBundlePackageType='APPL', MinimumOSVersion='17.0', UIDeviceFamily=[1],
        UILaunchScreen={}, NSLocationWhenInUseUsageDescription='Preview the map.'), f)
PY
RUNTIME=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; print(next(r["identifier"] for r in json.load(sys.stdin)["runtimes"] if r["isAvailable"] and "iOS" in r["name"]))')
DEVICE=$(xcrun simctl create RoutePickerQA com.apple.CoreSimulator.SimDeviceType.iPhone-12 "$RUNTIME")
trap 'xcrun simctl shutdown "$DEVICE" || true; xcrun simctl delete "$DEVICE" || true' EXIT
xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl status_bar "$DEVICE" override --time '9:41' --batteryState charged --batteryLevel 100
xcrun simctl install "$DEVICE" "$PREVIEW_APP"
for screen in Destination Start Search Filtered; do
  xcrun simctl terminate "$DEVICE" local.andromeda.routepickerpreview 2>/dev/null || true
  xcrun simctl launch "$DEVICE" local.andromeda.routepickerpreview --screen "$screen"
  sleep 5
  xcrun simctl io "$DEVICE" screenshot "$QA_DIR/$screen-picker.png"
done
