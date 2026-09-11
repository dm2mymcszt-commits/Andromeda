#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
QA_DIR="$PWD/build/address-search-qa"
mkdir -p "$QA_DIR"
python3 - "$QA_DIR/Models.swift" <<'PY'
from pathlib import Path
import sys
source = Path('Geranium/LocSim/RouteLocationPicker.swift').read_text()
Path(sys.argv[1]).write_text(source.split('struct RouteLocationPicker: View {')[0])
PY
xcrun swiftc "$QA_DIR/Models.swift" Geranium/LocSim/CoordTransform.swift \
  Tests/AddressSearch/main.swift -o "$QA_DIR/search-tests"
LIVE_ADDRESS_LOOKUP=1 "$QA_DIR/search-tests"
