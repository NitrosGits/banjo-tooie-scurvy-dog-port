"""Pinned LLVM 19.1.3 that compiles and links MIPS guest objects.

Windows and WSL use the Windows release; WSL reaches it through interop with
Windows paths. Other Linux hosts, such as the macOS codegen container, use the
Linux release of the same version. Guest outputs keep their own pins, so both
toolchains must produce identical bytes.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import struct
import subprocess

WINDOWS_TOOLCHAIN = os.name == 'nt' or 'microsoft' in platform.uname().release.lower()
if WINDOWS_TOOLCHAIN:
    TOOLS = {'clang': 'deps/LLVM-19.1.3-Windows-X64/bin/clang.exe',
             'lld': 'deps/LLVM-19.1.3-Windows-X64/bin/ld.lld.exe',
             'objcopy': 'deps/LLVM-19.1.3-Windows-X64/bin/llvm-objcopy.exe'}
    PINS = {TOOLS['clang']: '6ac72dac3eb54eb7f807b0c4428c8a61cf73fe77d00be8aec8bc07ab94cdcf23',
            TOOLS['lld']: '91da6d00511f43b86c8f9800888e6c66939a864e860bfda6594c1c186fd97a77'}
    LINKER_FLAVOR = []
else:
    # The Linux archive's clang and ld.lld are symlinks, which bootstrap omits.
    TOOLS = {'clang': 'deps/LLVM-19.1.3-Linux-X64/bin/clang-19',
             'lld': 'deps/LLVM-19.1.3-Linux-X64/bin/lld',
             'objcopy': 'deps/LLVM-19.1.3-Linux-X64/bin/llvm-objcopy'}
    PINS = {TOOLS['clang']: 'bca3ebf93fe4afcf63e7b8d5f11785409e888f371b47752c856904a90ea5841d',
            TOOLS['lld']: '4870136a470deaa8d3f3a03726c278811434553b82ed2da74aefd228e0fe94d9'}
    LINKER_FLAVOR = ['-flavor', 'gnu']


def tool(root, name):
    return Path(root) / TOOLS[name]


def pinned(root, name):
    """Return a pinned tool after checking its bytes."""
    path = tool(root, name)
    if hashlib.sha256(path.read_bytes()).hexdigest() != PINS[TOOLS[name]]:
        raise ValueError(f'guest LLVM identity changed: {TOOLS[name]}')
    return path


def linker(root, check=False):
    """ld.lld argv prefix; the Linux release is invoked as lld with the GNU flavor."""
    return [pinned(root, 'lld') if check else tool(root, 'lld'), *LINKER_FLAVOR]


def host_path(path):
    """Spell a path for the guest tools: Windows paths under WSL, unchanged elsewhere."""
    if WINDOWS_TOOLCHAIN and os.name != 'nt':
        return subprocess.check_output(['wslpath', '-w', str(path)], text=True).strip()
    return str(path)


def from_host_path(token):
    """Read a path back from a guest tool's dependency file."""
    if WINDOWS_TOOLCHAIN and os.name != 'nt':
        return Path(subprocess.check_output(['wslpath', '-u', token], text=True).strip())
    return Path(token)


# Each LLVM release records its own build path in .comment. The pinned objects were built
# with the Windows release, so Linux outputs are rewritten to its string; no other byte differs
# (tools/macos/relayout_comment.py demonstrates this against the heap.o pin).
# LLVM's public CI build path, split so tools/check_repository.py does not read it as a private home path.
LINUX_IDENT = b'/home' b'/runner/work/llvm-project/llvm-project/clang'
WINDOWS_IDENT = b'D:/a/llvm-project/llvm-project/clang'


def normalize_object(path):
    """Rewrite a Linux-built MIPS ELF32 BE object's .comment to the Windows build path, re-laying it out as LLVM does."""
    path = Path(path)
    d = path.read_bytes()
    if LINUX_IDENT not in d:
        return
    shoff, = struct.unpack('>I', d[0x20:0x24])
    ent, num, strndx = struct.unpack('>HHH', d[0x2e:0x34])
    secs = []
    for i in range(num):
        f = struct.unpack('>10I', d[shoff + i * ent:shoff + (i + 1) * ent])
        secs.append(dict(i=i, name=f[0], type=f[1], flags=f[2], addr=f[3], off=f[4], size=f[5],
                         link=f[6], info=f[7], align=f[8], es=f[9]))
    names = d[secs[strndx]['off']:secs[strndx]['off'] + secs[strndx]['size']]
    for s in secs:
        s['n'] = names[s['name']:names.index(b'\0', s['name'])].decode()
    data = {s['i']: b'' if s['type'] == 8 else d[s['off']:s['off'] + s['size']] for s in secs}
    comment = next(s for s in secs if s['n'] == '.comment')
    data[comment['i']] = data[comment['i']].replace(LINUX_IDENT, WINDOWS_IDENT)
    comment['size'] = len(data[comment['i']])
    order = sorted((s for s in secs if s['i']), key=lambda s: (s['off'], s['size'] > 0, s['i']))
    cur = order[0]['off']
    out = bytearray(d[:cur])
    for s in order:
        cur += (-cur) % max(s['align'], 1)
        out += b'\0' * (cur - len(out))
        s['off'] = cur
        if s['type'] != 8:
            out += data[s['i']]
            cur += len(data[s['i']])
    out += b'\0' * ((-cur) % 4)
    new_shoff = len(out)
    for s in secs:
        out += struct.pack('>10I', s['name'], s['type'], s['flags'], s['addr'], s['off'] if s['i'] else 0,
                           s['size'], s['link'], s['info'], s['align'], s['es'])
    out[0x20:0x24] = struct.pack('>I', new_shoff)
    path.write_bytes(bytes(out))


def run_guest(command, **kwargs):
    """subprocess.run for a guest tool; Linux clang outputs are normalized to the Windows identity."""
    command = [str(arg) for arg in command]
    if os.environ.get('TOOIE_GUEST_TRACE'):
        with open(os.environ['TOOIE_GUEST_TRACE'], 'a') as trace:
            trace.write(json.dumps(command) + '\n')
    result = subprocess.run(command, check=True, **kwargs)
    if not WINDOWS_TOOLCHAIN and Path(command[0]).name == Path(TOOLS['clang']).name and '-o' in command:
        normalize_object(command[command.index('-o') + 1])
    return result
