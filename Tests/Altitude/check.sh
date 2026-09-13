#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
QA_DIR="$PWD/build/altitude-qa"
mkdir -p "$QA_DIR"
python3 - "$QA_DIR/RouteLocationSample.swift" <<'PY'
from pathlib import Path
import sys
source = Path('Geranium/LocSim/LocSimManager.swift').read_text()
Path(sys.argv[1]).write_text(source.split('class LocSimManager {')[0])
assert 'altitudeController.receive(location)' in source
assert 'altitudeController.stop()' in source
for path in ['LocSimView.swift', 'RouteSimulator.swift', 'RouteSimView.swift', 'BookMark/BookMarkSlider.swift']:
    text = Path('Geranium/LocSim', path).read_text()
    assert 'altitude: 0' not in text and 'Double(altitude)' not in text, path
print('PASS: all location entry paths use the shared altitude injection layer')
PY
xcrun swiftc -parse-as-library Geranium/LocSim/Altitude.swift "$QA_DIR/RouteLocationSample.swift" Tests/Altitude/main.swift -o "$QA_DIR/altitude-tests"
"$QA_DIR/altitude-tests"
xcrun swiftc Geranium/LocSim/Altitude.swift Tests/Altitude/LiveElevation.swift -o "$QA_DIR/elevation-live"
"$QA_DIR/elevation-live"
