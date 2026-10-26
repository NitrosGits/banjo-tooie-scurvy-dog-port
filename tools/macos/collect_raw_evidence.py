#!/usr/bin/env python3
"""Collect the raw-archive qualification evidence on macOS (the Mach-O counterpart of docs/WINDOWS.md step 5).

Run at the checkout root after `cmake --build build/windows-dev --target BaselineRecompiledFuncs`, keeping that
build's log. Writes build/windows-dev/raw-qualification-input/evidence.json (never replaces one) and prints the
archive's SHA-256, which `verify_baseline_binding.py qualify --accepted-archive-sha` takes."""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'baseline'))
import macho_binding

sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, default=Path('build/windows-dev'))
    parser.add_argument('--expected-count', type=int, default=416)
    args = parser.parse_args()
    build = args.build.resolve()
    raw = (build / 'baseline/render-bridge-camera-candidate/composition-v2/raw').resolve()
    archive = build / 'libBaselineRecompiledFuncs.a'

    rows = [row for row in json.loads((build / 'compile_commands.json').read_text())
            if (Path(row['directory']) / row['file']).resolve().parent == raw]
    assert len(rows) == args.expected_count, f'{len(rows)} raw compile commands'
    members = macho_binding.archive_members(archive)
    assert set(members) == set(macho_binding.object_bijection(rows)), 'archive membership'

    ninja = re.search(r'^CMAKE_MAKE_PROGRAM:\w+=(.*)$', (build / 'CMakeCache.txt').read_text(), re.M)[1]
    outputs = {Path(row['directory'], row['output']).resolve() if 'output' in row else None for row in rows}
    files = {(Path(row['directory']) / row['file']).resolve() for row in rows} | {raw.parent / 'RAW_BINDING.json'}
    current, valid = False, 0
    for line in subprocess.check_output([ninja, '-C', str(build), '-t', 'deps'], text=True).splitlines():
        if line and not line[0].isspace():
            name = line.rsplit(': #deps', 1)[0]
            current = (build / name).resolve() in outputs
            if current:
                assert '(VALID)' in line, line
                valid += 1
        elif current and line.strip():
            path = Path(line.strip())
            files.add((path if path.is_absolute() else build / path).resolve())
    assert valid == args.expected_count, f'{valid} valid dependency records'

    record = {'commands': rows, 'files': [{'path': str(p), 'sha256': sha(p)} for p in sorted(files)]}
    target = build / 'raw-qualification-input/evidence.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    with open(target, 'x') as out:
        json.dump(record, out, indent=2)
    print(sha(archive))


if __name__ == '__main__':
    main()
