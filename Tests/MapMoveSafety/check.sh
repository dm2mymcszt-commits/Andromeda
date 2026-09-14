#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/map-move-qa
xcrun swiftc TrollRoute/Storage/SharedPreferences.swift TrollRoute/LocSim/MapMoveConfirmation.swift TrollRoute/LocSim/MainStopConfirmation.swift TrollRoute/LocSim/LongPressRoute.swift TrollRoute/LocSim/CoordTransform.swift Tests/MapMoveSafety/main.swift -o build/map-move-qa/check
build/map-move-qa/check
