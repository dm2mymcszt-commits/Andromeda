#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
QA_DIR="$PWD/build/route-simulation-qa"
mkdir -p "$QA_DIR"
# Exercise the exact production geometry/ETA/ranking code on macOS.
python3 - "$QA_DIR/Models.swift" <<'PY'
from pathlib import Path
import sys
source = Path('Geranium/LocSim/RouteSimulator.swift').read_text()
models = source.split('class RouteSimulator: NSObject')[0]
Path(sys.argv[1]).write_text(models.replace('import UIKit', 'import Combine'))
PY
xcrun swiftc "$QA_DIR/Models.swift" Geranium/LocSim/CoordTransform.swift Tests/RouteSimulation/main.swift -o "$QA_DIR/model-tests"
"$QA_DIR/model-tests"
xcrun swiftc "$QA_DIR/Models.swift" Geranium/LocSim/CoordTransform.swift Tests/RouteSimulation/LiveCycling.swift -o "$QA_DIR/cycling-tests"
"$QA_DIR/cycling-tests"
