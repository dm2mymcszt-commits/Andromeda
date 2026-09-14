#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/map-move-qa
xcrun swiftc TrollRoute/Storage/SharedPreferences.swift TrollRoute/LocSim/MapMoveConfirmation.swift TrollRoute/LocSim/MainStopConfirmation.swift TrollRoute/LocSim/LongPressRoute.swift TrollRoute/LocSim/CoordTransform.swift Tests/MapMoveSafety/main.swift -o build/map-move-qa/check
build/map-move-qa/check
python3 - <<'PY'
from pathlib import Path
import re
expected = dict(confirmBeforeStoppingSpoofing='true', longPressToCreateRoute='true',
                confirmLongPressRoute='false', autoStartLongPressRoute='false')
for filename in ['TrollRoute/SettingsView.swift', 'TrollRoute/LocSim/LocSimView.swift']:
    source = Path(filename).read_text()
    for key, value in expected.items():
        assert re.search(r'@AppStorage\("' + key + r'"[^\n]+ = ' + value + r'\b', source), (filename, key)
print('PASS: Phase 3 shared Settings and production map defaults agree with the plan')
PY
