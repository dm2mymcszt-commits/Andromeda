#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
QA_DIR="$PWD/build/address-search-qa"
mkdir -p "$QA_DIR"
xcrun swiftc Geranium/LocSim/PlaceModels.swift Geranium/LocSim/PlaceInput.swift Geranium/LocSim/AddressQuery.swift Geranium/LocSim/PlaceSearch.swift Geranium/LocSim/CoordTransform.swift \
  Tests/AddressSearch/main.swift -o "$QA_DIR/search-tests"
LIVE_ADDRESS_LOOKUP=1 "$QA_DIR/search-tests"
