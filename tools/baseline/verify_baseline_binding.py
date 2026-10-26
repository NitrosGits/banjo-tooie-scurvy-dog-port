"""Fail-closed selected raw archive/native content gate; qualification is manual."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess

import elf_binding
import macho_binding


def need(ok, why):
    if not ok:
        raise ValueError(why)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def archive_members(path, elf=False):
    data = Path(path).read_bytes()
    need(data[:8] == b'!<arch>\n', 'Invalid COFF archive signature')
    pos, names, members = 8, b'', {}
    while pos < len(data):
        header = data[pos:pos + 60]
        need(len(header) == 60 and header[58:60] == b'`\n', 'Invalid archive header')
        name, size = header[:16].decode().strip(), int(header[48:58])
        if elf: need(header[48:58].strip().isdigit(), 'Invalid GNU archive member size')
        body = data[pos + 60:pos + 60 + size]
        need(len(body) == size, 'Truncated archive member')
        if name == '//':
            names = body
        elif name not in ('/', '/SYM64/'):
            if name.startswith('/') and name[1:].isdigit():
                start = int(name[1:])
                end = names.find(b'/\n' if elf else b'\x00', start)
                if end < 0 and not elf:
                    end = names.find(b'/\n', start)
                need(0 <= start <= end, 'Invalid archive long name')
                name = names[start:end].decode()
            else:
                name = name.rstrip('/')
            name = name.replace('\\', '/')
            if elf:
                need('/' not in name and name not in ('.', '..'), 'GNU archive member must be a basename')
                elf_binding.elf_type(body, (elf_binding.ET_REL,))
            need(name not in members, 'Duplicate archive member')
            members[name] = (size, hashlib.sha256(body).hexdigest())
        if elf and size % 2: need(data[pos + 60 + size:pos + 61 + size] == b'\n', 'Invalid GNU archive padding')
        pos += 60 + size + size % 2
    need(pos == len(data), 'Archive trailing span mismatch')
    return members


def commands(args):
    rows = json.loads((args.build / 'compile_commands.json').read_text())
    if args.format in ('elf', 'macho'):  # clang and GCC rows share the GNU-style -o command shape
        rows = [elf_binding.compile_command(x, args.build) for x in rows
                if (Path(x['directory']) / x['file']).resolve().parent == args.raw]
        need(len(rows) == args.expected_count > 0, 'Selected raw command count mismatch')
        need(len({x['output'] for x in rows}) == len(rows), 'Duplicate selected GNU object output')
        return sorted(rows, key=lambda x: x['output'])
    rows = [x for x in rows if Path(x['file']).resolve().parent == args.raw]
    need(len(rows) == args.expected_count > 0, 'Selected raw command count mismatch')
    for row in rows:
        obj = (args.build / row['output']).resolve()
        need(obj.is_relative_to(args.build), 'Selected object outside build root')
    return sorted(rows, key=lambda x: x['output'])


def check_archive(args, snapshot):
    # Windows and ELF qualifications never substitute for each other.
    need(snapshot.get('format', 'pe') == args.format, 'Qualification format differs from the selected binary format')
    if args.format == 'elf':
        return check_elf_archive(args, snapshot)
    if args.format == 'macho':
        return check_macho_archive(args, snapshot)
    need(snapshot['raw_root'] == str(args.raw), 'Qualification raw root mismatch')
    need(commands(args) == snapshot['commands'], 'Qualified compile command mismatch')
    for row in snapshot['files']:
        need(sha(row['path']) == row['sha256'], 'Qualified source/dependency changed: ' + row['path'])
    expected = {x['name']: (x['bytes'], x['sha256']) for x in snapshot['objects']}
    need(archive_members(args.archive) == expected, 'Archive member identity/size/hash mismatch')
    for name, (size, digest) in expected.items():
        obj = args.build / name
        need(obj.stat().st_size == size and sha(obj) == digest, 'Qualified object changed: ' + name)


def elf_objects(args, selected):
    members = archive_members(args.archive, elf=True)
    outputs = elf_binding.object_bijection(selected)
    need(set(members) == set(outputs), 'GNU archive basenames differ from selected raw objects')
    return members, outputs


def check_elf_archive(args, snapshot):
    need(snapshot['raw_root'] == str(args.raw), 'Qualification raw root mismatch')
    selected = commands(args)
    need(selected == snapshot['commands'], 'Qualified compile command mismatch')
    for row in snapshot['files']:
        need(sha(row['path']) == row['sha256'], 'Qualified source/dependency changed: ' + row['path'])
    need(elf_binding.objdump_identity(args.tools) == snapshot['authority']['objdump'], 'Qualified GNU objdump identity changed')
    members, outputs = elf_objects(args, selected)
    need(members == {x['member']: (x['bytes'], x['sha256']) for x in snapshot['objects']}, 'Archive member identity/size/hash mismatch')
    need({x['member']: x['name'] for x in snapshot['objects']} == outputs, 'Archive member/object bijection mismatch')
    for row in snapshot['objects']:
        obj = args.build / row['name']
        need(obj.stat().st_size == row['bytes'] and sha(obj) == row['sha256'], 'Qualified object changed: ' + row['name'])


def macho_objects(args, selected):
    members = macho_binding.archive_members(args.archive)
    outputs = macho_binding.object_bijection(selected)
    need(set(members) == set(outputs), 'BSD archive basenames differ from selected raw objects')
    return members, outputs


def check_macho_archive(args, snapshot):
    need(snapshot['raw_root'] == str(args.raw), 'Qualification raw root mismatch')
    selected = commands(args)
    need(selected == snapshot['commands'], 'Qualified compile command mismatch')
    for row in snapshot['files']:
        need(sha(row['path']) == row['sha256'], 'Qualified source/dependency changed: ' + row['path'])
    need(macho_binding.objdump_identity(args.tools) == snapshot['authority']['objdump'], 'Qualified LLVM objdump identity changed')
    members, outputs = macho_objects(args, selected)
    need(members == {x['member']: (x['bytes'], x['sha256']) for x in snapshot['objects']}, 'Archive member identity/size/hash mismatch')
    need({x['member']: x['name'] for x in snapshot['objects']} == outputs, 'Archive member/object bijection mismatch')
    for row in snapshot['objects']:
        obj = args.build / row['name']
        need(obj.stat().st_size == row['bytes'] and sha(obj) == row['sha256'], 'Qualified object changed: ' + row['name'])


def accepted_inputs(args, object_suffix):
    need(args.evidence and args.compile_log and args.accepted_archive_sha, 'Manual evidence arguments required')
    need(not args.snapshot.exists() or args.replace, 'Qualification exists; explicit --replace required')
    evidence = json.loads(args.evidence.read_text())
    selected = commands(args)
    if args.format in ('elf', 'macho'):
        evidence['commands'] = [elf_binding.compile_command(x, args.build) for x in evidence['commands']]
    need(sorted(evidence['commands'], key=lambda x: x['output']) == selected, 'Accepted commands differ')
    declared = {str(Path(x['path']).resolve()): x for x in evidence['files']}
    need(len(declared) == len(evidence['files']), 'Duplicate evidence input')
    sources = {str(Path(x['file']).resolve()) for x in selected}
    declared_raw = {x for x in declared if Path(x).parent == args.raw and Path(x).name.startswith('funcs_') and Path(x).suffix == '.c'}
    need(sources == declared_raw, 'Evidence omits/adds selected raw source')
    binding_path = args.raw.parent / 'RAW_BINDING.json'
    need(str(binding_path) in declared, 'Evidence omits canonical RAW_BINDING')
    for row in declared.values():
        need(sha(row['path']) == row['sha256'], 'Accepted input changed: ' + row['path'])
    binding = json.loads(binding_path.read_text())
    for name, digest in binding['outputs'].items():
        child = (args.raw / name).resolve()
        need(child.parent == args.raw and sha(child) == digest, 'Canonical raw output mismatch')
        declared[str(child)] = dict(path=str(child), sha256=digest)
    evidence['files'] = list(declared.values())
    built = re.findall(r'Building C object .*[/\\](funcs_\d+\.c)' + object_suffix, args.compile_log.read_text())
    need(Counter(built) == Counter(Path(x['file']).name for x in selected), 'Missing/duplicate successful compile evidence')
    need(sha(args.archive) == args.accepted_archive_sha, 'Archive differs from independently accepted bytes')
    return evidence, selected


def qualify(args):
    if args.format == 'elf':
        return qualify_elf(args)
    if args.format == 'macho':
        return qualify_macho(args)
    evidence, selected = accepted_inputs(args, r'\.obj')
    members = archive_members(args.archive)
    expected = {x['output'].replace('\\', '/') for x in selected}
    need(len(members) == len(selected) and set(members) == expected, 'Accepted archive membership differs')
    hooks, relocation_units = [], []
    for row in selected:
        source = Path(row['file']).read_text()
        unit_hooks = Counter(re.findall(r'\b(baseline_\w+)\s*\(', source))
        if not unit_hooks:
            continue
        reloc = subprocess.check_output([str(args.tools / 'llvm-objdump.exe'), '-r', str(args.build / row['output'])], text=True)
        actual_hooks = Counter(re.findall(r'\b(baseline_\w+)\s*$', reloc, re.M))
        need(set(actual_hooks) == set(unit_hooks), 'Source/relocation hook-name mismatch')
        relocation_units.append(dict(source=Path(row['file']).name, source_counts=dict(unit_hooks), compiled_counts=dict(actual_hooks)))
        for match in re.finditer(r'RECOMP_FUNC void (\w+)\(', source):
            end = source.find('RECOMP_FUNC void ', match.end())
            body = source[match.start():end if end >= 0 else len(source)]
            targets = sorted(set(re.findall(r'\b(baseline_\w+)\s*\(', body)))
            if targets:
                hooks.append(dict(caller=match[1], owner='BaselineRecompiledFuncs:' + Path(row['file']).name + '.obj', targets=targets))
    previous = sha(args.snapshot) if args.snapshot.exists() else None
    snapshot = dict(raw_root=str(args.raw), commands=selected, files=evidence['files'], hooks=hooks, relocation_units=relocation_units,
                    objects=[dict(name=n, bytes=v[0], sha256=v[1]) for n, v in sorted(members.items())],
                    authority=dict(accepted_archive_sha256=args.accepted_archive_sha, compile_evidence_sha256=sha(args.compile_log),
                                   source_evidence_sha256=sha(args.evidence), previous_snapshot_sha256=previous))
    check_archive(args, snapshot)
    args.snapshot.parent.mkdir(parents=True, exist_ok=True)
    args.snapshot.write_text(json.dumps(snapshot, indent=2) + '\n')


def qualify_elf(args):
    evidence, selected = accepted_inputs(args, r'\.o\b')
    objdump = elf_binding.objdump_identity(args.tools)
    members, outputs = elf_objects(args, selected)
    hooks, relocation_units = [], []
    for row in selected:
        source = Path(row['file']).read_text()
        unit_hooks = Counter(re.findall(r'\b(baseline_\w+)\s*\(', source))
        if not unit_hooks:
            continue
        actual_hooks, forms = elf_binding.hook_relocations(objdump['path'], args.build / row['output'])
        need(set(actual_hooks) == set(unit_hooks), 'Source/relocation hook-name mismatch')
        member = row['output'].replace('\\', '/').rsplit('/', 1)[-1]
        relocation_units.append(dict(source=Path(row['file']).name, source_counts=dict(unit_hooks),
                                     compiled_counts=dict(actual_hooks), relocation_forms=dict(forms)))
        for match in re.finditer(r'RECOMP_FUNC void (\w+)\(', source):
            end = source.find('RECOMP_FUNC void ', match.end())
            body = source[match.start():end if end >= 0 else len(source)]
            targets = sorted(set(re.findall(r'\b(baseline_\w+)\s*\(', body)))
            if targets:
                hooks.append(dict(caller=match[1], owner=args.archive.name + '(' + member + ')', member=member, targets=targets))
    previous = sha(args.snapshot) if args.snapshot.exists() else None
    snapshot = dict(format='elf', raw_root=str(args.raw), commands=selected, files=evidence['files'], hooks=hooks,
                    relocation_units=relocation_units,
                    objects=[dict(name=outputs[m], member=m, bytes=v[0], sha256=v[1]) for m, v in sorted(members.items())],
                    authority=dict(accepted_archive_sha256=args.accepted_archive_sha, compile_evidence_sha256=sha(args.compile_log),
                                   source_evidence_sha256=sha(args.evidence), previous_snapshot_sha256=previous, objdump=objdump))
    check_archive(args, snapshot)
    args.snapshot.parent.mkdir(parents=True, exist_ok=True)
    args.snapshot.write_text(json.dumps(snapshot, indent=2) + '\n')


def qualify_macho(args):
    evidence, selected = accepted_inputs(args, r'\.o\b')
    objdump = macho_binding.objdump_identity(args.tools)
    members, outputs = macho_objects(args, selected)
    hooks, relocation_units = [], []
    for row in selected:
        source = Path(row['file']).read_text()
        unit_hooks = Counter(re.findall(r'\b(baseline_\w+)\s*\(', source))
        if not unit_hooks:
            continue
        actual_hooks, forms = macho_binding.hook_relocations(objdump['path'], args.build / row['output'])
        need(set(actual_hooks) == set(unit_hooks), 'Source/relocation hook-name mismatch')
        member = row['output'].replace('\\', '/').rsplit('/', 1)[-1]
        relocation_units.append(dict(source=Path(row['file']).name, source_counts=dict(unit_hooks),
                                     compiled_counts=dict(actual_hooks), relocation_forms=dict(forms)))
        for match in re.finditer(r'RECOMP_FUNC void (\w+)\(', source):
            end = source.find('RECOMP_FUNC void ', match.end())
            body = source[match.start():end if end >= 0 else len(source)]
            targets = sorted(set(re.findall(r'\b(baseline_\w+)\s*\(', body)))
            if targets:
                hooks.append(dict(caller=match[1], owner=args.archive.name + '(' + member + ')', member=member, targets=targets))
    previous = sha(args.snapshot) if args.snapshot.exists() else None
    snapshot = dict(format='macho', raw_root=str(args.raw), commands=selected, files=evidence['files'], hooks=hooks,
                    relocation_units=relocation_units,
                    objects=[dict(name=outputs[m], member=m, bytes=v[0], sha256=v[1]) for m, v in sorted(members.items())],
                    authority=dict(accepted_archive_sha256=args.accepted_archive_sha, compile_evidence_sha256=sha(args.compile_log),
                                   source_evidence_sha256=sha(args.evidence), previous_snapshot_sha256=previous, objdump=objdump))
    check_archive(args, snapshot)
    args.snapshot.parent.mkdir(parents=True, exist_ok=True)
    args.snapshot.write_text(json.dumps(snapshot, indent=2) + '\n')


def check_native(args, snapshot):
    text, pe = args.map.read_text(), args.exe.read_bytes()
    nt = struct.unpack_from('<I', pe, 0x3c)[0]
    need(pe[:2] == b'MZ' and pe[nt:nt + 4] == b'PE\0\0', 'Invalid PE signature')
    stamp = re.search(r'Timestamp is ([0-9A-Fa-f]+)', text)
    need(stamp and int(stamp[1], 16) == struct.unpack_from('<I', pe, nt + 8)[0], 'Map/PE timestamp mismatch')
    required = {x['caller'] for x in snapshot['hooks']} | {n for x in snapshot['hooks'] for n in x['targets']}
    symbols = {}
    for name, address, owner in re.findall(r'^\s*[0-9A-Fa-f]{4}:[0-9A-Fa-f]+\s+(\S+)\s+([0-9A-Fa-f]{16})\s+(\S+)\s*$', text, re.M):
        if name in required:
            need(name not in symbols, 'Duplicate required map symbol: ' + name)
            symbols[name] = (int(address, 16), owner)
    need(set(symbols) == required, 'Required map symbol missing')
    addresses = sorted({int(a, 16) for a in re.findall(r'^\s*[0-9A-Fa-f]{4}:[0-9A-Fa-f]+\s+\S+\s+([0-9A-Fa-f]{16})\s+\S+\s*$', text, re.M)})
    for row in snapshot['hooks']:
        start, owner = symbols[row['caller']]
        need(owner == row['owner'], 'Wrong native raw caller owner')
        end = next(a for a in addresses if a > start)
        asm = subprocess.check_output([str(args.tools / 'llvm-objdump.exe'), '-d', '--start-address=' + str(start),
                                       '--stop-address=' + str(end), str(args.exe)], text=True)
        for target in row['targets']:
            need(re.search(r'\b(?:callq?|jmpq?)\s+0x' + format(symbols[target][0], 'x') + r'\b', asm, re.I), 'Missing native raw hook call: ' + target)
    return dict(exe_sha256=sha(args.exe), map_sha256=sha(args.map), archive_sha256=sha(args.archive), snapshot_sha256=sha(args.snapshot))


def check_native_elf(args, snapshot):
    tool = snapshot['authority']['objdump']['path']  # identity re-verified by check_archive
    elf = elf_binding.Elf(args.exe)
    gmap = elf_binding.GnuMap(args.map, args.build)
    gmap.bind(elf, args.exe)
    archive = args.archive.resolve()
    linked = []
    for row in snapshot['hooks']:
        caller, owner, _ = elf_binding.bound_symbol(elf, gmap, row['caller'], elf_binding.STT_FUNC, True)
        need(owner == (archive, row['member']) and row['owner'] == archive.name + '(' + row['member'] + ')',
             'Wrong native raw caller owner')
        branches = elf_binding.direct_branches(tool, args.exe, row['caller'], caller['value'], caller['size'])
        targets = {}
        for target in row['targets']:
            hook, hook_owner, _ = elf_binding.bound_symbol(elf, gmap, target, elf_binding.STT_FUNC, True)
            need(hook_owner[0] != archive, 'Raw hook target resolved inside the raw archive: ' + target)
            need(('call', hook['value'], target) in branches or ('jmp', hook['value'], target) in branches,
                 'Missing native raw hook call: ' + target)
            targets[target] = dict(address=hook['value'], owner=elf_binding.owner_text(hook_owner, args.build))
        linked.append(dict(caller=row['caller'], address=caller['value'], owner=row['owner'], targets=targets))
    return dict(format='elf', exe_sha256=sha(args.exe), map_sha256=sha(args.map), archive_sha256=sha(args.archive),
                snapshot_sha256=sha(args.snapshot), objdump_sha256=snapshot['authority']['objdump']['sha256'], hooks=linked)


def check_native_macho(args, snapshot):
    tool = snapshot['authority']['objdump']['path']  # identity re-verified by check_archive
    macho = macho_binding.Macho(args.exe)
    lmap = macho_binding.Ld64Map(args.map, args.build)
    lmap.bind(macho, args.exe)
    archive = args.archive.resolve()
    linked = []
    for row in snapshot['hooks']:
        caller, owner, _ = macho_binding.bound_symbol(macho, lmap, row['caller'], True, allow_weak=True)
        need(owner == (archive, row['member']) and row['owner'] == archive.name + '(' + row['member'] + ')',
             'Wrong native raw caller owner')
        branches = macho_binding.direct_branches(tool, args.exe, row['caller'], caller['value'], caller['size'])
        targets = {}
        for target in row['targets']:
            hook, hook_owner, _ = macho_binding.bound_symbol(macho, lmap, target, True)
            need(hook_owner[0] != archive, 'Raw hook target resolved inside the raw archive: ' + target)
            # A branch island or stub would show another target address: refused, never followed.
            need(('call', hook['value'], target) in branches or ('jmp', hook['value'], target) in branches,
                 'Missing native raw hook call: ' + target)
            targets[target] = dict(address=hook['value'], owner=macho_binding.owner_text(hook_owner, args.build))
        linked.append(dict(caller=row['caller'], address=caller['value'], owner=row['owner'], targets=targets))
    return dict(format='macho', exe_sha256=sha(args.exe), map_sha256=sha(args.map), archive_sha256=sha(args.archive),
                snapshot_sha256=sha(args.snapshot), objdump_sha256=snapshot['authority']['objdump']['sha256'], hooks=linked)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('qualify', 'archive', 'native', 'prelaunch'))
    for name in ('build', 'raw', 'archive', 'tools', 'snapshot'):
        parser.add_argument('--' + name, type=Path, required=True)
    for name in ('exe', 'map', 'receipt', 'evidence', 'compile-log'):
        parser.add_argument('--' + name, type=Path)
    parser.add_argument('--expected-count', type=int, required=True)
    parser.add_argument('--accepted-archive-sha')
    parser.add_argument('--replace', action='store_true')
    parser.add_argument('--format', choices=('pe', 'elf', 'macho'), default='pe')
    args = parser.parse_args()
    args.build, args.raw = args.build.resolve(), args.raw.resolve()
    if args.mode == 'qualify':
        qualify(args)
    else:
        snapshot = json.loads(args.snapshot.read_text())
        check_archive(args, snapshot)
        if args.mode in ('native', 'prelaunch'):
            need(args.exe and args.map and args.receipt, 'Native paths required')
            receipt = {'elf': check_native_elf, 'macho': check_native_macho}.get(args.format, check_native)(args, snapshot)
            if args.mode == 'native':
                args.receipt.write_text(json.dumps(receipt, indent=2) + '\n')
            else:
                need(receipt == json.loads(args.receipt.read_text()), 'Native/archive/qualification receipt mismatch')
    print(json.dumps(dict(status='PASS', mode=args.mode)))


if __name__ == '__main__':
    main()
