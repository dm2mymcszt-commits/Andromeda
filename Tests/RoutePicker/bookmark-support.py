"""Compile production bookmark persistence without unrelated UIKit import tools."""
from pathlib import Path
import sys

source = Path('Geranium/LocSim/BookMark/BookMarkHelper.swift').read_text()
persistence = source.split('func isThereAnyMika()')[0]
# Only the haptic side effect is unavailable in the isolated QA apps.
Path(sys.argv[1]).write_text(persistence + '\nfunc successVibrate() {}\n')
