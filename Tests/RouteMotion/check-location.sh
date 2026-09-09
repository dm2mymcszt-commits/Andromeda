#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
QA_DIR="$PWD/build/route-motion-qa"
mkdir -p "$QA_DIR"
# Compile the production factory; CLSimulationManager itself is a private iOS API.
python3 - "$QA_DIR/RouteLocationSample.swift" <<'PY'
from pathlib import Path
import sys
source = Path('Geranium/LocSim/LocSimManager.swift').read_text()
Path(sys.argv[1]).write_text(source.split('class LocSimManager {')[0])
PY
xcrun swiftc "$QA_DIR/RouteLocationSample.swift" Tests/RouteMotion/LocationSampleTests.swift \
  -o "$QA_DIR/location-sample-tests"
"$QA_DIR/location-sample-tests"
