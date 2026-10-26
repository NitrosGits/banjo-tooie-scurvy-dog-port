#!/usr/bin/env python3
"""Pack what the macOS configure needs from the Linux code generation into one tar.gz on stdout.

The codegen receipt names every input it validates, including files under deps/. The Linux LLVM binaries are
left out (the macOS job fetches them with bootstrap --platform linux). The output is derived from the user's
ROM: never publish it unencrypted."""
import json
import sys
import tarfile
from pathlib import Path

root = Path(__file__).resolve().parents[2]
receipt = json.loads((root / 'generated/codegen-receipt.json').read_text())
paths = [p for p in receipt['inputs'] if p.startswith('deps/') and not p.startswith('deps/LLVM-')]
paths += ['generated', 'build/windows-dev', 'config/tooie.us.toml', 'config/selected.syms.toml',
          'config/overlay-ids.txt', 'config/symbol_renames.json']
with tarfile.open(fileobj=sys.stdout.buffer, mode='w|gz') as archive:
    for name in paths:
        archive.add(root / name, arcname=name)
print(f'packed {len(paths)} entries', file=sys.stderr)
