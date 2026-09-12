#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
QA_DIR="$PWD/build/shared-place-qa"
mkdir -p "$QA_DIR"
xcrun swiftc Geranium/LocSim/PlaceModels.swift Geranium/LocSim/PlaceInput.swift \
  Geranium/LocSim/AddressQuery.swift Geranium/LocSim/PlaceSearch.swift \
  Geranium/LocSim/CoordTransform.swift Geranium/LocSim/SharedPlace.swift \
  Tests/SharedPlace/main.swift -o "$QA_DIR/share-tests"
"$QA_DIR/share-tests"
