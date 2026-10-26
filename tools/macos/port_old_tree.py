#!/usr/bin/env python3
"""Apply the Linux guest-toolchain shim (tools/guest_llvm.py) to a checkout of commit 61caf07.

build_legacy_standalone.sh uses this to rebuild the legacy standalone Silo directory that
prepare_camera_bridge.py pins. Only toolchain selection changes; every replacement must apply exactly once."""
import shutil
import sys
from pathlib import Path

tree = Path(sys.argv[1]).resolve()
shutil.copyfile(Path(__file__).resolve().parents[1] / 'guest_llvm.py', tree / 'tools/guest_llvm.py')


def edit(path, pairs):
    p = tree / path
    s = p.read_text()
    for old, new in pairs:
        if s.count(old) != 1:
            sys.exit(f'{path}: expected one match, found {s.count(old)}: {old[:60]!r}')
        s = s.replace(old, new)
    p.write_text(s)


imports = """import subprocess
import sys
from pathlib import Path

import toml
from elftools.elf.elffile import ELFFile
from elftools.elf.relocation import RelocationSection

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import guest_llvm
"""
edit('tools/baseline/prepare_render_bridge.py', [
    ("""import subprocess
from pathlib import Path

import toml
from elftools.elf.elffile import ELFFile
from elftools.elf.relocation import RelocationSection
""", imports),
    ("""def win(path):
    return subprocess.check_output(['wslpath', '-w', str(path)], text=True).strip()""", """def win(path):
    return guest_llvm.host_path(path)"""),
    ("""    compiler = root / 'deps/LLVM-19.1.3-Windows-X64/bin/clang.exe'
    linker = compiler.parent / 'ld.lld.exe'
    assert sha(compiler) == '6ac72dac3eb54eb7f807b0c4428c8a61cf73fe77d00be8aec8bc07ab94cdcf23'
    assert sha(linker) == '91da6d00511f43b86c8f9800888e6c66939a864e860bfda6594c1c186fd97a77'
""", """    compiler = guest_llvm.pinned(root, 'clang')
    linker = guest_llvm.linker(root, check=True)
"""),
    ("    run([linker, '-m', 'elf32btsmip', '-T', win(source/'render_bridge.ld'),",
     "    run([*linker, '-m', 'elf32btsmip', '-T', win(source/'render_bridge.ld'),"),
    ("subprocess.run(list(map(str,command)),cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)",
     "guest_llvm.run_guest(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)"),
])
edit('tools/baseline/prepare_silo_bridge.py', [
    ("""    compiler = root/'deps/LLVM-19.1.3-Windows-X64/bin/clang.exe'
    assert sha(compiler) == '6ac72dac3eb54eb7f807b0c4428c8a61cf73fe77d00be8aec8bc07ab94cdcf23'
""", """    compiler = accepted.guest_llvm.pinned(root, 'clang')
"""),
    ("""    linker=root/'deps/LLVM-19.1.3-Windows-X64/bin/ld.lld.exe'
    assert sha(linker)=='91da6d00511f43b86c8f9800888e6c66939a864e860bfda6594c1c186fd97a77'
    run([linker,""", """    linker=accepted.guest_llvm.linker(root,check=True)
    run([*linker,"""),
    ("subprocess.run(list(map(str,command)),cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)",
     "accepted.guest_llvm.run_guest(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)"),
])
edit('tools/baseline/prepare_boot_heap.py', [
    ("""import subprocess
import toml
from elftools.elf.elffile import ELFFile
from elftools.elf.relocation import RelocationSection
""", """import subprocess
import sys
import toml
from elftools.elf.elffile import ELFFile
from elftools.elf.relocation import RelocationSection

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import guest_llvm
"""),
    ("""        'deps/LLVM-19.1.3-Windows-X64/bin/clang.exe': '6ac72dac3eb54eb7f807b0c4428c8a61cf73fe77d00be8aec8bc07ab94cdcf23',
        'deps/LLVM-19.1.3-Windows-X64/bin/ld.lld.exe': '91da6d00511f43b86c8f9800888e6c66939a864e860bfda6594c1c186fd97a77',
""", """        **guest_llvm.PINS,
"""),
    ("""    return str(path) if os.name == 'nt' else subprocess.check_output(['wslpath', '-w', str(path)], text=True).strip()""",
     """    return guest_llvm.host_path(path)"""),
    ("""    compiler = root / 'deps/LLVM-19.1.3-Windows-X64/bin/clang.exe'
    linker = compiler.parent / 'ld.lld.exe'
""", """    compiler = guest_llvm.tool(root, 'clang')
    linker = guest_llvm.linker(root)
"""),
    ("""            path = Path(token) if os.name == 'nt' else Path(subprocess.check_output(['wslpath', '-u', token], text=True).strip())""",
     """            path = guest_llvm.from_host_path(token)"""),
    ("""    run([linker, '-m', 'elf32btsmip', '-T', win(source / 'boot_initialize.ld'),""",
     """    run([*linker, '-m', 'elf32btsmip', '-T', win(source / 'boot_initialize.ld'),"""),
    ("subprocess.run([str(a) for a in command], cwd=root, stdout=log, stderr=subprocess.STDOUT, check=True)",
     "guest_llvm.run_guest(command, cwd=root, stdout=log, stderr=subprocess.STDOUT)"),
    ("compiler, linker, raw_header", "compiler, guest_llvm.tool(root, 'lld'), raw_header"),
])
edit('tools/prepare_heap_patch.py', [
    ("""from codegen_provenance import generated_directory, sha
""", """from codegen_provenance import generated_directory, sha
import guest_llvm
"""),
    ("""def windows_path(path):
    path = Path(path).resolve()
    if os.name == 'nt':
        return str(path)
    return subprocess.check_output(['wslpath', '-w', str(path)], text=True).strip()
""", """def windows_path(path):
    return guest_llvm.host_path(Path(path).resolve())
"""),
    ("""    clang = app / 'deps/LLVM-19.1.3-Windows-X64/bin/clang.exe'
    linker = clang.with_name('ld.lld.exe')
    objcopy = clang.with_name('llvm-objcopy.exe')
""", """    clang = guest_llvm.tool(app, 'clang')
    linker = guest_llvm.linker(app)
    objcopy = guest_llvm.tool(app, 'objcopy')
"""),
    ("""            dependency = Path(token) if os.name == 'nt' else Path(subprocess.check_output(
                ['wslpath', '-u', token], text=True).strip())
            dependency = dependency.resolve()""", """            dependency = guest_llvm.from_host_path(token).resolve()"""),
    ("""    run([linker, '-m', 'elf32btsmip', '-T', windows_path(app / 'patches/game/heap.ld'),""",
     """    run([*linker, '-m', 'elf32btsmip', '-T', windows_path(app / 'patches/game/heap.ld'),"""),
    ("subprocess.run(command, cwd=app, stdout=output, stderr=subprocess.STDOUT, check=True)",
     "guest_llvm.run_guest(command, cwd=app, stdout=output, stderr=subprocess.STDOUT)"),
])
edit('tools/render_wrapper_contract.py', [
    ("""    'deps/LLVM-19.1.3-Windows-X64/bin/clang.exe',
    'deps/LLVM-19.1.3-Windows-X64/bin/ld.lld.exe',
    'deps/LLVM-19.1.3-Windows-X64/bin/llvm-objcopy.exe',
)""", """    'tools/guest_llvm.py',
    *(guest_llvm.TOOLS[name] for name in ('clang', 'lld', 'objcopy')),
)"""),
    ("""are normalized identities, not original instructions or a runtime registry.
\"\"\"
CALLEES""", """are normalized identities, not original instructions or a runtime registry.
\"\"\"
import guest_llvm

CALLEES"""),
])
edit('tools/codegen_provenance.py', [
    ("""import json
import re
""", """import json
import re

import guest_llvm
"""),
    ("""    'src/boot_hooks.h',
    'deps/LLVM-19.1.3-Windows-X64/bin/clang.exe',
    'deps/LLVM-19.1.3-Windows-X64/bin/ld.lld.exe')""", """    'src/boot_hooks.h', 'tools/guest_llvm.py',
    guest_llvm.TOOLS['clang'], guest_llvm.TOOLS['lld'])"""),
])
print('ported', tree)
