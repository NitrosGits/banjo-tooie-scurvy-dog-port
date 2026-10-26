"""Prepare the fixed boot/core1 initializers with the accepted M2 heap body.

Maintained successor of the A-BOOT/A-CORE1-INIT/M2 preparation: the same authored
guest C, placement and N64Recomp patch mode, bound to the accepted combined image
instead of the historical intermediate images. Run under the existing WSL codegen
environment after tools/prepare_codegen.py and prepare_baseline_raw.py.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import toml
from elftools.elf.elffile import ELFFile
from elftools.elf.relocation import RelocationSection

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import guest_llvm

OUTPUT = 'build/windows-dev/baseline/heap-patch'
SOURCE = 'tools/baseline/guest/boot-initializer'
DATA = {'boot___osFinalrom': 0x80006F50, 'boot_osClockRate': 0x80004250,
        'boot_osViClock': 0x80004258, 'boot___Dom1SpeedParam': 0x80006F60,
        'boot___Dom2SpeedParam': 0x80006FD8, 'boot___osExceptionPreamble': 0x80001C90,
        'osTvType': 0x80000300, 'osResetType': 0x8000030C, 'osAppNMIBuffer': 0x8000031C}
CALLEES = {'boot___osSetFpcCsr'}
CORE1_DATA = {'__osFinalrom': 0x8007EAD0, 'osClockRate': 0x80041390,
              'osViClock': 0x80041398, '__Dom1SpeedParam': 0x8007EAE0,
              '__Dom2SpeedParam': 0x8007EB58, '__osExceptionPreamble': 0x80031FE0,
              **{n: DATA[n] for n in ('osTvType', 'osResetType', 'osAppNMIBuffer')}}
HEAP_DATA = {'D_8003F750': 0x8003F750}
FUNCTIONS = ['boot_osInitialize', 'tooie_core1_osInitialize', 'heap_realloc']
PINS = {'deps/banjo-tooie/build/us/banjotooie_decompressed.elf': '331fe74764f14ef480688da128bb0c75ee388c416e6af7de38beff7defb8373f',
        'config/selected.syms.toml': '37998003f59c74676667c898ef960641f195bfdefb4b47181665e75a8aada395',
        # Canonical prepare_codegen heap_realloc object accepted into the M2 image.
        'generated/heap-patch-products/heap.o': 'ed96838f19baceeab975fcd2bec9a3f24893879539a83dc4dad5bc32ba38d3e2',
        **guest_llvm.PINS,
        'deps/N64Recomp-codegen/build/N64Recomp': '34958d6ae8c047adb772090c75fdcc051036646a1db58595694f814c3a4a09b6'}
# Accepted combined image; the Silo and camera images keep it as their exact prefix.
ACCEPTED = {'boot.bin': '7b0b5a18e4d9ffb4ddf4bfd3bce2166d060b7da0c03792eff4b8dcaa644ddd42',
            'boot.c': '1ba3f809964fc715e3ca92e1d1a8cfb805170b4b0ad834774177533e720a5184'}
IMAGE_BYTES = 2760
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()


def win(path):
    path = Path(path).resolve()
    return guest_llvm.host_path(path)


def validate(path, data, functions, callees, linked=False):
    with path.open('rb') as stream:
        elf = ELFFile(stream)
        if elf.elfclass != 32 or elf.little_endian or elf['e_machine'] != 'EM_MIPS':
            raise ValueError('expected big-endian MIPS32 ELF')
        symbols = list(elf.get_section_by_name('.symtab').iter_symbols())
        imports = {s.name for s in symbols if s.name and s['st_shndx'] == 'SHN_UNDEF'}
        if imports != callees | set(data):
            raise ValueError(f'unexpected imports: {sorted(imports)}')
        definitions = [s.name for s in symbols if s['st_info']['type'] == 'STT_FUNC' and s['st_shndx'] != 'SHN_UNDEF']
        if set(definitions) != set(functions) or len(definitions) != len(functions):
            raise ValueError(f'function definition drift: {definitions}')
        code_index = next(i for i, s in enumerate(elf.iter_sections()) if s.name == '.recomp_patch')
        code = elf.get_section(code_index).data()
        for section in elf.iter_sections():
            allowed_sections = {'.recomp_patch'} if linked else {'.recomp_patch', '.reginfo', '.MIPS.abiflags'}
            if section.name.startswith('.got') or (section['sh_flags'] & 2 and section['sh_size'] and section.name not in allowed_sections):
                raise ValueError(f'unexpected allocated storage: {section.name}')
            if isinstance(section, RelocationSection) and section['sh_info'] == code_index:
                table = elf.get_section(section['sh_link'])
                for reloc in section.iter_relocations():
                    symbol = table.get_symbol(reloc['r_info_sym'])
                    name, kind = symbol.name, reloc['r_info_type']
                    if kind == 4 and symbol['st_info']['type'] == 'STT_SECTION' and symbol['st_shndx'] == code_index:
                        offset = reloc['r_offset'] - (elf.get_section(code_index)['sh_addr'] if linked else 0)
                        target = (int.from_bytes(code[offset:offset+4], 'big') & 0x03FFFFFF) << 2
                        origin = elf.get_section(code_index)['sh_addr'] if linked else 0
                        if linked:
                            target |= (origin + offset + 4) & 0xF0000000
                        if not origin <= target < origin + len(code):
                            raise ValueError('local jump leaves patch')
                    elif name not in callees | set(data) or kind not in {4, 5, 6} or (kind == 4 and name not in callees):
                        raise ValueError(f'unsupported relocation: {name} type {kind}')
        for offset in range(0, len(code), 4):
            word = int.from_bytes(code[offset:offset+4], 'big')
            if word >> 26 not in {2, 3} and (28 in {(word >> 21) & 31, (word >> 16) & 31} or (word >> 26 == 0 and (word >> 11) & 31 == 28)):
                raise ValueError(f'GP dependency at {offset:x}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    root = parser.parse_args().root.resolve()
    output, source = root / OUTPUT, root / SOURCE
    if output.exists() and any(output.iterdir()):
        raise ValueError('heap image requires a fresh output; preserve prior evidence')
    for name, digest in PINS.items():
        if sha(root / name) != digest:
            raise ValueError(f'pinned heap image input changed: {name}')
    original = root / 'deps/banjo-tooie/build/us/banjotooie_decompressed.elf'
    selected = root / 'config/selected.syms.toml'
    heap_object = root / 'generated/heap-patch-products/heap.o'
    generator = root / 'deps/N64Recomp-codegen/build/N64Recomp'
    compiler = guest_llvm.tool(root, 'clang')
    linker = guest_llvm.linker(root)
    raw_header = root / 'build/windows-dev/baseline/raw/funcs.h'
    data = DATA | CORE1_DATA | HEAP_DATA
    with original.open('rb') as stream:
        symbols = {s.name: s for s in ELFFile(stream).get_section_by_name('.symtab').iter_symbols() if s.name}
        if any(symbols[n]['st_value'] != address for n, address in data.items()):
            raise ValueError('ELF data address drift')
        for name, identity in [('boot_osInitialize', (0x800016F0, 0x2A8)), ('osInitialize', (0x8002D7B0, 0x2A8))]:
            if (symbols[name]['st_value'], symbols[name]['st_size']) != identity:
                raise ValueError(f'original initializer identity drift: {name}')
    with heap_object.open('rb') as stream:
        heap_imports = {s.name for s in ELFFile(stream).get_section_by_name('.symtab').iter_symbols()
                        if s.name and s['st_shndx'] == 'SHN_UNDEF'}
    if not set(HEAP_DATA) <= heap_imports:
        raise ValueError('accepted heap object data import changed')
    # The pinned object fixes its own callees; the linked image imports exactly these.
    callees = CALLEES | (heap_imports - set(HEAP_DATA))
    includes = [root / 'deps/banjo-tooie/include', root / 'deps/banjo-tooie/lib/ultralib/include']
    inputs = [original, selected, heap_object, generator, compiler, guest_llvm.tool(root, 'lld'), raw_header, Path(__file__).resolve(),
              source / 'boot_initialize.c', source / 'core1_init.c', source / 'boot_initialize.ld']
    initial = {p.resolve(): sha(p) for p in inputs}
    initial.update({p.resolve(): sha(p) for directory in includes for p in directory.rglob('*.h')})
    output.mkdir(parents=True, exist_ok=True)
    commands = []
    def run(command, name):
        commands.append([str(a) for a in command])
        with (output / name).open('w') as log:
            guest_llvm.run_guest(command, cwd=root, stdout=log, stderr=subprocess.STDOUT)
    for stem, filename, object_data, object_functions in [
            ('boot', 'boot_initialize.c', DATA, ['boot_osInitialize']),
            ('core1', 'core1_init.c', CORE1_DATA, ['tooie_core1_osInitialize'])]:
        run([compiler, '-target', 'mips', '-EB', '-mips2', '-mabi=32', '-O2', '-G0', '-mno-abicalls',
             '-mno-odd-spreg', '-nostdinc', '-D_LANGUAGE_C', '-DMIPS', '-fno-builtin', '-MMD', '-MT', stem,
             '-MF', win(output / (stem + '.d'))] + ['-I' + win(p) for p in includes] +
            ['-c', win(source / filename), '-o', win(output / (stem + '.o'))], stem + '-compile.log')
        validate(output / (stem + '.o'), object_data, object_functions, CALLEES)
        dependencies = (output / (stem + '.d')).read_text().replace('\\\n', '').split(':', 1)[1]
        for token in re.findall(r'(?:\\.|[^\s])+', dependencies):
            token = token.replace('\\ ', ' ').replace('\\\\', '\\')
            path = guest_llvm.from_host_path(token)
            path = path.resolve()
            if path not in initial:
                raise ValueError(f'unexpected included header: {path}')
            if path not in inputs:
                inputs.append(path)
    run([*linker, '-m', 'elf32btsmip', '-T', win(source / 'boot_initialize.ld'), '--unresolved-symbols=ignore-all',
         '--emit-relocs', '--orphan-handling=error', win(output / 'boot.o'), win(output / 'core1.o'), win(heap_object),
         '-o', win(output / 'boot.elf')], 'link.log')
    validate(output / 'boot.elf', data, FUNCTIONS, callees, linked=True)
    (output / 'data.syms.toml').write_text(toml.dumps({'section': [dict(name='.absolute_boot_data', vram=0, size=0,
        symbols=[dict(name=n, vram=a) for n, a in data.items()])]}))
    config = {'input': dict(elf_path=str(output / 'boot.elf'), output_func_path=str(output), single_file_output=True,
        func_reference_syms_file=str(selected), data_reference_syms_files=[str(output / 'data.syms.toml')],
        output_binary_path=str(output / 'boot.bin'), strict_patch_mode=True, unpaired_lo16_warnings=False,
        recomp_include='#include "recomp.h"')}
    (output / 'boot.toml').write_text(toml.dumps(config))
    run([generator, output / 'boot.toml'], 'codegen.log')
    if re.findall(r'^RECOMP_FUNC void (\w+)\(', (output / 'boot.c').read_text(), re.M) != FUNCTIONS:
        raise ValueError('generated definition drift')
    if (output / 'boot.bin').stat().st_size != IMAGE_BYTES or any(sha(output / n) != d for n, d in ACCEPTED.items()):
        raise ValueError('combined initializer/heap image differs from the accepted M2 image')
    # BaselineBootPatch force-includes raw funcs.h; the FCSR helper ABI must be declared there.
    if 'void boot___osSetFpcCsr(uint8_t* rdram, recomp_context* ctx);' not in raw_header.read_text():
        raise ValueError('raw corpus lacks the boot FCSR helper prototype')
    if any(sha(p) != initial[p.resolve()] for p in inputs):
        raise ValueError('preparation inputs changed')
    receipt = dict(condition='BASELINE-BOOT-CORE1-M2/code-only', inputs={str(p): initial[p.resolve()] for p in inputs},
                   commands=commands, config=config,
                   outputs={p.name: sha(p) for p in sorted(output.iterdir()) if p.is_file() and p.name != 'receipt.json'})
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    main()
