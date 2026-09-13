#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
QA_DIR="$PWD/build/shared-place-qa"
mkdir -p "$QA_DIR"
xcrun swiftc TrollRoute/LocSim/PlaceModels.swift TrollRoute/LocSim/PlaceInput.swift \
  TrollRoute/LocSim/AddressQuery.swift TrollRoute/LocSim/PlaceSearch.swift \
  TrollRoute/LocSim/CoordTransform.swift TrollRoute/LocSim/SharedPlace.swift \
  Tests/SharedPlace/main.swift -o "$QA_DIR/share-tests"
"$QA_DIR/share-tests"
