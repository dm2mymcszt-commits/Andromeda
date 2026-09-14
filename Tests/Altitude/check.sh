#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
QA_DIR="$PWD/build/altitude-qa"
mkdir -p "$QA_DIR"
python3 - "$QA_DIR/RouteLocationSample.swift" <<'PY'
from pathlib import Path
import sys
source = Path('TrollRoute/LocSim/LocSimManager.swift').read_text()
Path(sys.argv[1]).write_text(source.split('class LocSimManager {')[0])
session = Path('TrollRoute/LocSim/LocationSession.swift').read_text()
assert 'altitudeController.receive(routeDistance:' in session
assert 'altitudeController.stop()' in session
for path in ['LocSimView.swift', 'RouteSimulator.swift', 'RouteSimView.swift']:
    text = Path('TrollRoute/LocSim', path).read_text()
    assert 'altitude: 0' not in text and 'Double(altitude)' not in text, path
print('PASS: all location entry paths use the shared altitude injection layer')
PY
xcrun swiftc TrollRoute/Storage/SharedPreferences.swift -parse-as-library TrollRoute/LocSim/RouteElevation.swift TrollRoute/LocSim/Altitude.swift "$QA_DIR/RouteLocationSample.swift" Tests/Altitude/main.swift -o "$QA_DIR/altitude-tests"
"$QA_DIR/altitude-tests"
xcrun swiftc -parse-as-library TrollRoute/Storage/SharedPreferences.swift \
  TrollRoute/LocSim/RouteElevation.swift TrollRoute/LocSim/Altitude.swift \
  "$QA_DIR/RouteLocationSample.swift" Tests/Altitude/RouteProfile.swift -o "$QA_DIR/route-elevation-tests"
"$QA_DIR/route-elevation-tests"
xcrun swiftc TrollRoute/Storage/SharedPreferences.swift TrollRoute/LocSim/RouteElevation.swift TrollRoute/LocSim/Altitude.swift Tests/Altitude/LiveElevation.swift -o "$QA_DIR/elevation-live"
"$QA_DIR/elevation-live"
