#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/map-move-qa
xcrun swiftc Geranium/LocSim/MapMoveConfirmation.swift Tests/MapMoveSafety/main.swift -o build/map-move-qa/check
build/map-move-qa/check
