#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
QA_DIR="$PWD/build/address-search-qa"
mkdir -p "$QA_DIR"
xcrun swiftc TrollRoute/LocSim/PlaceModels.swift TrollRoute/LocSim/PlaceInput.swift TrollRoute/LocSim/AddressQuery.swift TrollRoute/LocSim/PlaceSearch.swift TrollRoute/LocSim/CoordTransform.swift \
  Tests/AddressSearch/main.swift -o "$QA_DIR/search-tests"
LIVE_ADDRESS_LOOKUP=1 "$QA_DIR/search-tests"
