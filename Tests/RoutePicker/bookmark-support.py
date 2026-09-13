"""Compile production bookmark persistence with an isolated haptic stub."""
from pathlib import Path
import sys

source = Path('TrollRoute/LocSim/BookMark/BookMarkHelper.swift').read_text()
persistence = source
# Only the haptic side effect is unavailable in the isolated QA apps.
Path(sys.argv[1]).write_text(persistence + '\nfunc successVibrate() {}\n')
