#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
QA_DIR="$PWD/build/injection-qa"
mkdir -p "$QA_DIR"
# Compile the real adapter with a recording replacement for the private system
# class. This tests its actual operation order without pretending to inject GPS
# on a hosted Mac. The phone test covers locationd and third-party consumers.
xcrun swiftc -parse-as-library TrollRoute/Storage/SharedPreferences.swift \
  TrollRoute/LocSim/RouteElevation.swift TrollRoute/LocSim/Altitude.swift TrollRoute/LocSim/LocationSession.swift \
  TrollRoute/LocSim/LocSimManager.swift Tests/Injection/main.swift -o "$QA_DIR/injection-tests"
"$QA_DIR/injection-tests"
