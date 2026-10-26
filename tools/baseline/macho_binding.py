"""macOS arm64 Mach-O primitives shared by the existing baseline binding gates.

Mirrors elf_binding.py. Only BSD ar archives of arm64 MH_OBJECT files, ld64 maps written with -map
and LLVM objdump are accepted; every unrecognised shape is refused rather than interpreted."""
from collections import Counter
import hashlib
import os
from pathlib import Path
import re
import struct
import subprocess

MH_MAGIC_64 = 0xfeedfacf
CPU_TYPE_ARM64 = 0x0100000c
MH_OBJECT, MH_EXECUTE = 1, 2
LC_SEGMENT_64, LC_SYMTAB = 0x19, 0x2
VM_PROT_WRITE = 2
S_ZEROFILL = 1
S_ATTR_PURE_INSTRUCTIONS, S_ATTR_SOME_INSTRUCTIONS = 0x80000000, 0x00000400
N_STAB, N_TYPE, N_EXT, N_SECT = 0xe0, 0x0e, 0x01, 0x0e
N_WEAK_DEF = 0x0080
SYMBOL_TABLES = ('__.SYMDEF', '__.SYMDEF SORTED', '__.SYMDEF_64', '__.SYMDEF_64 SORTED')
FORMAT = 'mach-o arm64'


def need(ok, why):
    if not ok:
        raise ValueError(why)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def macho_type(data, allowed):
    need(len(data) >= 32 and struct.unpack_from('<I', data, 0)[0] == MH_MAGIC_64, 'Mach-O 64-bit little-endian signature')
    cputype, _, kind = struct.unpack_from('<iiI', data, 4)
    need(cputype == CPU_TYPE_ARM64, 'arm64 Mach-O required')
    need(kind in allowed, 'Unexpected Mach-O type %d' % kind)
    return kind


def archive_members(path):
    """BSD ar (Apple libtool/ar): '#1/N' names carry their text at the start of the member; symbol tables are skipped."""
    data = Path(path).read_bytes()
    need(data[:8] == b'!<arch>\n', 'Invalid archive signature')
    pos, members = 8, {}
    while pos < len(data):
        header = data[pos:pos + 60]
        need(len(header) == 60 and header[58:60] == b'`\n', 'Invalid archive header')
        need(header[48:58].strip().isdigit(), 'Invalid BSD archive member size')
        name, size = header[:16].decode().strip(), int(header[48:58])
        body = data[pos + 60:pos + 60 + size]
        need(len(body) == size, 'Truncated archive member')
        if name.startswith('#1/'):
            need(name[3:].isdigit() and 0 < int(name[3:]) <= size, 'Invalid BSD archive long name')
            length = int(name[3:])
            name, body = body[:length].rstrip(b'\0').decode(), body[length:]
        if name not in SYMBOL_TABLES:
            need('/' not in name and name not in ('', '.', '..'), 'BSD archive member must be a basename')
            macho_type(body, (MH_OBJECT,))
            need(name not in members, 'Duplicate archive member')
            members[name] = (len(body), hashlib.sha256(body).hexdigest())
        if size % 2:
            need(data[pos + 60 + size:pos + 61 + size] == b'\n', 'Invalid BSD archive padding')
        pos += 60 + size + size % 2
    need(pos == len(data), 'Archive trailing span mismatch')
    return members


class Macho:
    """Selected executable: load commands, sections and the nlist symbol table, all bounds-checked."""

    def __init__(self, path):
        self.data = Path(path).read_bytes()
        macho_type(self.data, (MH_EXECUTE,))
        try:
            ncmds, sizeofcmds = struct.unpack_from('<II', self.data, 16)
            self.take(32, sizeofcmds)
            self.segments, self.sections, self.symbols = [], [], {}
            offset, symtab = 32, None
            for _ in range(ncmds):
                cmd, size = struct.unpack_from('<II', self.take(offset, 8), 0)
                need(size >= 8 and offset + size <= 32 + sizeofcmds, 'Mach-O load command bounds')
                if cmd == LC_SEGMENT_64:
                    name, vmaddr, vmsize, fileoff, filesize, maxprot, initprot, nsects, _ = struct.unpack_from(
                        '<16sQQQQiiII', self.take(offset + 8, 64), 0)
                    need(size == 72 + 80 * nsects, 'Mach-O segment command size')
                    segment = dict(name=name.rstrip(b'\0').decode(), vmaddr=vmaddr, vmsize=vmsize, fileoff=fileoff,
                                   filesize=filesize, initprot=initprot)
                    self.take(fileoff, filesize)
                    need(filesize <= vmsize, 'Mach-O segment file size exceeds memory span')
                    self.segments.append(segment)
                    for i in range(nsects):
                        sect, seg, addr, sz, off, _, _, _, flags, _, _, _ = struct.unpack_from(
                            '<16s16sQQIIIIIIII', self.take(offset + 72 + 80 * i, 80), 0)
                        row = dict(name=sect.rstrip(b'\0').decode(), segment=seg.rstrip(b'\0').decode(), addr=addr,
                                   size=sz, offset=off, flags=flags, owner=segment)
                        need(row['segment'] == segment['name'], 'Mach-O section names a different segment')
                        if flags & 0xff != S_ZEROFILL: self.take(off, sz)
                        self.sections.append(row)
                elif cmd == LC_SYMTAB:
                    need(symtab is None and size == 24, 'Exactly one LC_SYMTAB required')
                    symtab = struct.unpack_from('<IIII', self.take(offset + 8, 16), 0)
                offset += size
            need(offset == 32 + sizeofcmds and self.segments and symtab, 'Mach-O needs segments and one unstripped symbol table')
            symoff, nsyms, stroff, strsize = symtab
            strings = self.take(stroff, strsize)
            for i in range(nsyms):
                strx, kind, sect, desc, value = struct.unpack_from('<IBBHQ', self.take(symoff + 16 * i, 16), 0)
                if kind & N_STAB or not strx:
                    continue
                need(strx < strsize, 'Mach-O symbol name outside its string table')
                name = strings[strx:strings.index(b'\0', strx)].decode()
                self.symbols.setdefault(name, []).append(dict(
                    external=bool(kind & N_EXT), defined=(kind & N_TYPE) == N_SECT, section=sect,
                    weak=bool(desc & N_WEAK_DEF), value=value))
        except (struct.error, ValueError, IndexError, UnicodeError) as error:
            raise ValueError('Malformed selected Mach-O: ' + str(error)) from error

    def take(self, offset, size):
        need(0 <= offset <= len(self.data) and 0 <= size <= len(self.data) - offset, 'Mach-O file span outside bounds')
        return self.data[offset:offset + size]

    def symbol(self, name, allow_weak=False):
        """name is the C name; Mach-O prefixes it with an underscore. The runtime declares raw functions
        weak (RECOMP_FUNC): callers may be, hook targets may not. A strong override elsewhere would take the
        symbol and show another owner in the ld64 map, which the owner check refuses."""
        rows = self.symbols.get('_' + name, [])
        need(len(rows) == 1, 'Mach-O symbol must be unique: ' + name)
        row = rows[0]
        # Hidden-visibility symbols are local in a linked Mach-O (ELF keeps them global); the symbol table
        # and the ld64 map must each still show exactly one section-defined definition.
        need(row['defined'] and (allow_weak or not row['weak']), 'Mach-O symbol must be section-defined' + ('' if allow_weak else ' and nonweak') + ': ' + name)
        need(0 < row['section'] <= len(self.sections), 'Mach-O symbol section index: ' + name)
        return row

    def span(self, row, size, executable):
        """File bytes of a symbol: one file-backed section of the read-only __TEXT segment.

        arm64 macOS refuses writes to __TEXT, so no dyld rebase or bind can alter a span inside it."""
        need(size > 0, 'Mach-O symbol span must be sized')
        start, section = row['value'], self.sections[row['section'] - 1]
        segment = section['owner']
        need(section['flags'] & 0xff != S_ZEROFILL, 'Symbol requires file-backed section data')
        need(segment['name'] == '__TEXT' and not segment['initprot'] & VM_PROT_WRITE, 'Symbol requires the read-only __TEXT segment')
        instructions = bool(section['flags'] & (S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS))
        need(instructions == executable, 'Symbol section permissions differ')
        need(section['addr'] <= start and size <= section['size'] and start - section['addr'] <= section['size'] - size,
             'Symbol span must belong to exactly one section')
        offset = section['offset'] + start - section['addr']
        need(segment['fileoff'] <= offset and offset + size <= segment['fileoff'] + segment['filesize'] and
             start - segment['vmaddr'] == offset - segment['fileoff'], 'Section/segment file offsets disagree')
        return self.take(offset, size)


def object_bijection(rows):
    """Archive member name -> full compile output; BSD ar keeps basenames, so duplicates are refused."""
    out = {}
    for row in rows:
        output = row['output'].replace('\\', '/')
        base = output.rsplit('/', 1)[-1]
        need(base.endswith('.o'), 'Mach-O object output must end in .o: ' + output)
        need(base not in out, 'Duplicate raw object basename: ' + base)
        out[base] = output
    return out


OBJECT_ROW = re.compile(r'\[\s*(\d+)\] (.+)')
SECTION_ROW = re.compile(r'0x([0-9A-Fa-f]+)\t0x([0-9A-Fa-f]+)\t(\S+)\t(\S+)')
SYMBOL_ROW = re.compile(r'0x([0-9A-Fa-f]+)\t0x([0-9A-Fa-f]+)\t\[\s*(\d+)\] (.+)')


class Ld64Map:
    """ld64 -map: output path, object-file index, output sections and per-symbol address, size and object."""

    def __init__(self, path, build):
        self.build = Path(build).resolve()
        # Unrelated symbol names may hold non-UTF-8 bytes; keep them lossless rather than refuse the map.
        text = Path(path).read_text(errors='surrogateescape')
        lines = text.split('\n')  # not splitlines(): odd symbol bytes would split a row
        if lines and lines[-1] == '': lines.pop()
        need(len(lines) > 4 and lines[0].startswith('# Path: ') and lines[1] == '# Arch: arm64', 'ld64 arm64 map required')
        self.output = self.resolve(lines[0][len('# Path: '):])
        self.objects, self.out_sections, self.defined = {}, [], {}
        part = None
        for line in lines[2:]:
            if line.startswith('# '):
                part = {'# Object files:': 'objects', '# Sections:': 'sections', '# Symbols:': 'symbols'}.get(line, 'other' if not line.startswith('# Address') else part)
                if line == '# Object files:':
                    need(not self.objects, 'ld64 map lists object files once')
                continue
            if part == 'objects':
                match = OBJECT_ROW.fullmatch(line)
                need(match and int(match[1]) not in self.objects, 'Unrecognised ld64 object-file row: ' + line)
                self.objects[int(match[1])] = self.file(match[2])
            elif part == 'sections':
                match = SECTION_ROW.fullmatch(line)
                need(match, 'Unrecognised ld64 section row: ' + line)
                self.out_sections.append((match[3], match[4], int(match[1], 16), int(match[2], 16)))
            elif part == 'symbols':
                match = SYMBOL_ROW.fullmatch(line)
                need(match and int(match[3]) in self.objects, 'Unrecognised ld64 symbol row: ' + line)
                self.defined.setdefault(match[4], []).append((int(match[1], 16), int(match[2], 16), self.objects[int(match[3])]))
        need(self.objects and self.out_sections and self.defined, 'ld64 map is missing a section')

    def resolve(self, text):
        path = Path(text)
        return (path if path.is_absolute() else self.build / path).resolve()

    def file(self, text):
        match = re.fullmatch(r'(.+)\(([^()/]+)\)', text)
        return (self.resolve(match[1]), match[2]) if match else (self.resolve(text), None)

    def bind(self, macho, exe):
        """ld64 writes no timestamp: bind the Path line plus the whole output section layout."""
        need(self.output == Path(exe).resolve(), 'ld64 map Path names a different executable')
        actual = {(x['segment'], x['name'], x['addr'], x['size']) for x in macho.sections if x['size']}
        need(len(actual) == len([x for x in macho.sections if x['size']]), 'Duplicate Mach-O section rows')
        need({x for x in self.out_sections if x[3]} == actual and len({x for x in self.out_sections if x[3]}) == len([x for x in self.out_sections if x[3]]),
             'ld64 map output sections differ from the Mach-O layout')

    def owner_of(self, name):
        rows = self.defined.get('_' + name, [])
        need(len(rows) == 1, 'ld64 map must list one definition: ' + name)
        return rows[0]


def bound_symbol(macho, lmap, name, executable, allow_weak=False):
    row = macho.symbol(name, allow_weak)
    address, size, owner = lmap.owner_of(name)
    need(address == row['value'], 'ld64 map and Mach-O symbol addresses differ: ' + name)
    data = macho.span(row, size, executable)
    return dict(row, size=size), owner, data


def owner_text(owner, build):
    path, member = owner
    build = Path(build).resolve()
    text = path.relative_to(build).as_posix() if path.is_relative_to(build) else path.as_posix()
    return text + ('(' + member + ')' if member else '')


def run(command):
    return subprocess.run([str(x) for x in command], check=True, capture_output=True, text=True,
                          env=dict(os.environ, LC_ALL='C')).stdout


def objdump_identity(tools):
    tools = Path(tools)
    tool = tools / 'llvm-objdump'
    need(tools.is_absolute() and tool.is_file(), 'Explicit absolute llvm-objdump required: ' + str(tool))
    lines = [x for x in run([tool, '--version']).splitlines() if x.strip()]
    need(lines and 'LLVM' in lines[0], 'LLVM objdump required: ' + (lines[0] if lines else ''))
    return dict(path=str(tool), sha256=sha(tool.resolve()), version=lines[0])


RELOCATION = re.compile(r'([0-9a-f]{16})\s+(ARM64_RELOC_\w+)\s+(\S+)')


def hook_relocations(objdump, obj, pattern=r'baseline_\w+'):
    """Hook references must be direct BRANCH26 relocations without addend, in __text; debug records are ignored."""
    names, forms, section, headers = Counter(), Counter(), None, 0
    hooks, addends = [], set()
    for line in run([objdump, '-r', obj]).splitlines():
        line = line.rstrip()
        if not line:
            continue
        if (match := re.fullmatch(r'.+:\tfile format (.+)', line)):
            need(match[1] == FORMAT and not headers, 'objdump must read one mach-o arm64 object')
            headers += 1
        elif (match := re.fullmatch(r'RELOCATION RECORDS FOR \[(.+)\]:', line)):
            section = match[1]
        elif re.fullmatch(r'OFFSET\s+TYPE\s+VALUE', line):
            need(section is not None, 'Relocation header outside a record block')
        elif (match := RELOCATION.fullmatch(line)):
            need(section is not None, 'Relocation outside a record block')
            if match[2] == 'ARM64_RELOC_ADDEND':
                addends.add((section, match[1]))
                continue
            symbol = match[3]
            if not symbol.startswith('_') or not re.fullmatch(pattern, symbol[1:]) or section.startswith('__debug'):
                continue
            need(section == '__text', 'Hook relocation outside executable text: ' + section)
            need(match[2] == 'ARM64_RELOC_BRANCH26', 'Hook relocation is not a direct branch: ' + line)
            hooks.append((section, match[1], symbol[1:], match[2]))
        else:
            need(False, 'Unrecognised objdump relocation line: ' + line)
    need(headers == 1, 'objdump produced no object header')
    for section, offset, name, kind in hooks:
        need((section, offset) not in addends, 'Hook relocation carries an addend: ' + name)
        names[name] += 1
        forms[kind] += 1
    return names, forms


INSTRUCTION = re.compile(r'\s*([0-9a-f]+):\s+(bl?)\s+0x([0-9a-f]+)(?:\s+<([^>]+)>)?')


def direct_branches(objdump, exe, name, start, size):
    """Direct b/bl targets inside [start, start+size). A branch island or stub shows up as a different
    target address, so the caller's gate refuses it instead of following it."""
    text = run([objdump, '-d', '--no-show-raw-insn', '--start-address=0x%x' % start,
                '--stop-address=0x%x' % (start + size), exe])
    need(re.search(r'^0*%x <_%s>:$' % (start, re.escape(name)), text, re.M), 'Disassembly does not start at linked caller: ' + name)
    branches = []
    for line in text.splitlines():
        match = INSTRUCTION.fullmatch(line.rstrip())
        if match:
            symbol = (match[4] or '')
            branches.append(('call' if match[2] == 'bl' else 'jmp', int(match[3], 16),
                             symbol[1:] if symbol.startswith('_') else symbol))
    return branches
