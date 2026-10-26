"""Prepare the qualified finite rendering replacements through one pipeline."""
from pathlib import Path
import json
import re
import subprocess
import toml
from elftools.elf.elffile import ELFFile
from codegen_provenance import generated_directory, sha
import guest_llvm
from render_wrapper_contract import (
    CALLEES, HEAP_DATA, HUD_LITERALS, HUD_LINKED_LITERALS, REPLACEMENTS,
    RENDER_STORAGE, NATIVE_IMPORTS, ORIGINAL_REFERENCES, OBJECT_CONTRACTS,
    SOURCES, PATCH_INPUTS, LITERAL_SECTIONS, ORIGINAL_ELF_SHA256,
    object_parameters, linked_parameters)
from render_wrapper_validator import validate_heap_object
from verify_render_wrapper_image import verify as verify_image


def windows_path(path):
    return guest_llvm.host_path(Path(path).resolve())


def prepare_heap_patch(app, executable, selected, elf_path, evidence, generated_dir=None):
    app = Path(app).resolve()
    generated = generated_directory(app, generated_dir)
    raw = generated / 'heap-patch-products'
    raw.mkdir(parents=True, exist_ok=True)
    log_dir = Path(evidence) / 'logs'
    log_dir.mkdir(parents=True, exist_ok=True)
    reference = generated.parent / 'config/selected.syms.toml'
    inputs = [app / name for name in PATCH_INPUTS] + [Path(executable).resolve(),
                                                   Path(elf_path).resolve(), reference]
    includes = [app / 'patches/render_wrapper/guest/production',
                app / 'patches/render_wrapper/guest', app / 'patches/game',
                app / 'deps/rt64/include', app / 'deps/banjo-tooie/include',
                app / 'deps/banjo-tooie/src', app / 'deps/banjo-tooie/lib/ultralib/include']
    initial = {path.resolve(): sha(path) for path in inputs}
    initial.update({path.resolve(): sha(path) for directory in includes for path in directory.rglob('*.h')})
    functions = {f['name']: f for section in selected for f in section['functions']}
    for name, identity in REPLACEMENTS.items():
        row = functions.get(name)
        if row is None or (row['vram'], row['size']) != identity:
            raise ValueError(f'original replacement identity changed: {name}')
    if sha(Path(elf_path)) != ORIGINAL_ELF_SHA256:
        raise ValueError('original reference ELF identity changed')
    with Path(elf_path).open('rb') as stream:
        elf = ELFFile(stream)
        symbols = {symbol.name: symbol for symbol in elf.get_section_by_name('.symtab').iter_symbols()
                   if symbol.name}
        types = {0: 'STT_NOTYPE', 1: 'STT_OBJECT', 2: 'STT_FUNC'}
        for name, (address, size, kind) in ORIGINAL_REFERENCES.items():
            symbol = symbols.get(name)
            if symbol is None or (symbol['st_value'], symbol['st_size'], symbol['st_info']['type']) != (
                    address, size, types[kind]):
                raise ValueError(f'original reference row changed: {name}')

    data, definitions, callees = linked_parameters()
    # Original exception preambles are function-typed ELF symbols consumed as
    # data by the authored initializer. Preserve that declared import use.
    original_data = {name: address for name, address in data.items() if address is not None}
    (raw / 'data.syms.toml').write_text(toml.dumps({'section': [dict(
        name='.absolute_guest_data', vram=0, size=0,
        symbols=[dict(name=name, vram=address) for name, address in sorted(original_data.items())])]}))
    patch_config = {'input': dict(elf_path='heap.elf', output_func_path='.', single_file_output=True,
        func_reference_syms_file=str(reference),
        data_reference_syms_files=['data.syms.toml'], output_binary_path='heap.bin',
        strict_patch_mode=True, use_absolute_symbols=True, unpaired_lo16_warnings=False,
        recomp_include='#include "recomp.h"\n#include "boot_hooks.h"\n'
        '#define osGetThreadId osGetThreadId_recomp')}
    # The alias is fresh linked data; append it after strict linking below.
    (raw / 'heap.toml').write_text(toml.dumps(patch_config))
    (raw / 'syms.ld').unlink(missing_ok=True)

    commands = []
    def run(command, name):
        command = [str(arg) for arg in command]
        commands.append(dict(name=name, argv=command))
        with (log_dir / name).open('w') as output:
            guest_llvm.run_guest(command, cwd=app, stdout=output, stderr=subprocess.STDOUT)

    clang = guest_llvm.tool(app, 'clang')
    linker = guest_llvm.linker(app)
    objcopy = guest_llvm.tool(app, 'objcopy')
    object_facts = []
    for row in OBJECT_CONTRACTS:
        stem = row['stem']
        source_path = app / SOURCES[stem]
        output = raw / (stem + '.o')
        raw_output = raw / (stem + '.raw.o') if stem == 'model_nodes' else output
        command = [clang, '-target', 'mips', '-EB', '-mips2', '-mabi=32', '-O2', '-G0',
            '-mno-abicalls', '-mno-odd-spreg', '-nostdinc', '-D_LANGUAGE_C', '-DMIPS',
            '-fno-builtin', '-MMD', '-MT', stem, '-MF', windows_path(raw / (stem + '.d'))]
        if stem == 'native_aspect_projection':
            command.append('-fno-jump-tables')
        command += ['-I' + windows_path(directory) for directory in includes]
        command += ['-c', windows_path(source_path), '-o', windows_path(raw_output)]
        run(command, stem + '-compile.log')
        local_data, local_functions, local_calls, storage, native = object_parameters(row)
        kwargs = dict(storage=storage, native=native, literals=stem == 'hud_projection',
                      wrapper_literals=stem == 'model_nodes',
                      aspect_literals=stem == 'native_aspect_projection')
        validate_heap_object(raw_output, local_data, local_functions, local_calls,
                             raw_wrapper_literal=stem == 'model_nodes', **kwargs)
        if stem == 'model_nodes':
            run([objcopy, '--redefine-sym', '$CPI0_0=$WRP0_0',
                 windows_path(raw_output), windows_path(output)], 'model-nodes-literal-normalize.log')
            validate_heap_object(output, local_data, local_functions, local_calls, **kwargs)
        object_facts.append(dict(stem=stem, source=SOURCES[stem], raw_sha256=sha(raw_output),
                                 sha256=sha(output), functions=row['functions'],
                                 imports=row['imports']))
        dependency_text = (raw / (stem + '.d')).read_text().replace('\\\n', '').split(':', 1)[1]
        for token in re.findall(r'(?:\\.|[^\s])+', dependency_text):
            token = token.replace('\\ ', ' ').replace('\\\\', '\\')
            dependency = guest_llvm.from_host_path(token).resolve()
            if dependency not in initial:
                raise ValueError(f'unexpected guest header dependency: {dependency}')
            if dependency not in inputs:
                inputs.append(dependency)

    run([*linker, '-m', 'elf32btsmip', '-T', windows_path(app / 'patches/game/heap.ld'),
         '--unresolved-symbols=ignore-all', '--emit-relocs', '--orphan-handling=error',
         *[windows_path(raw / (row['stem'] + '.o')) for row in OBJECT_CONTRACTS],
         '-o', windows_path(raw / 'heap.elf')], 'heap-link.log')
    with (raw / 'heap.elf').open('rb') as stream:
        elf = ELFFile(stream)
        symbol = elf.get_section_by_name('.symtab').get_symbol_by_name('tooie_family_birth_state')[0]
        alias = symbol['st_value'] + 804
    layout = validate_heap_object(raw / 'heap.elf', data, definitions, callees, linked=True,
        storage=RENDER_STORAGE, native=NATIVE_IMPORTS, literals=True, wrapper_literals=True,
        aspect_literals=True, aliases={'tooie_wrapper_state': alias},
        extra_file_symbols=('model_nodes.c', 'player_release.c', 'native_aspect_projection.c'))
    original_data['tooie_wrapper_state'] = alias
    (raw / 'data.syms.toml').write_text(toml.dumps({'section': [dict(
        name='.absolute_guest_data', vram=0, size=0,
        symbols=[dict(name=name, vram=address) for name, address in sorted(original_data.items())])]}))
    run([executable, raw / 'heap.toml'], 'heap-codegen.log')
    source = (raw / 'heap.c').read_text()
    # Reference symbols retain the SDK name; bind its declared host shim ABI.
    # Retire this alias when reference emission itself supplies the shim name.
    host_alias = '#define osGetThreadId osGetThreadId_recomp'
    reference_calls = re.findall(r'\bosGetThreadId\(rdram,\s*ctx\);', source)
    shim_declaration = re.search(
        r'void\s+osGetThreadId_recomp\(uint8_t\*\s*rdram,\s*recomp_context\*\s*ctx\);',
        (raw / 'funcs.h').read_text())
    if source.count(host_alias) != 1 or len(reference_calls) != 4 or not shim_declaration:
        raise ValueError('heap SDK reference host-name/prototype contract changed')
    emitted = re.findall(r'^RECOMP_FUNC void (\w+)\(', source, re.M)
    if len(emitted) != len(REPLACEMENTS) or set(emitted) != set(REPLACEMENTS):
        raise ValueError(f'patch image emitted unexpected definitions: {emitted}')
    gfx, gfx_size = layout['tooie_gfx_pools']
    family, family_size = layout['tooie_family_birth_state']
    (generated / 'render_layout.h').write_text('#pragma once\n'
        f'#define TOOIE_GFX_POOLS_VRAM 0x{gfx:08X}u\n'
        f'#define TOOIE_GFX_POOLS_END_VRAM 0x{gfx + gfx_size:08X}u\n'
        f'#define TOOIE_RENDER_BIRTH_VRAM 0x{family:08X}u\n')
    (generated / 'render_patch_layout.h').write_text('#pragma once\n'
        f'#define TOOIE_RENDER_FAMILY_VRAM 0x{family:08X}u\n'
        f'#define TOOIE_RENDER_FAMILY_BYTES {family_size}u\n'
        f'#define TOOIE_RENDER_GFX_VRAM 0x{gfx:08X}u\n'
        f'#define TOOIE_RENDER_GFX_BYTES {gfx_size}u\n')
    (generated / 'heap_patch.c').write_text(source)
    facts = dict(schema=1, objects=object_facts, definitions=sorted(definitions),
                 replacements={name:list(identity) for name,identity in REPLACEMENTS.items()},
                 native_imports=NATIVE_IMPORTS,
                 host_reference_aliases={'osGetThreadId': 'osGetThreadId_recomp'},
                 layout={name:list(value) for name,value in layout.items()},
                 wrapper_alias=alias, original_elf_sha256=ORIGINAL_ELF_SHA256, commands=commands)
    # Semantic subrecord only. codegen_provenance owns the sole top-level receipt.
    (raw / 'module-semantic.json').write_text(json.dumps(facts, indent=2, sort_keys=True) + '\n')
    verify_image(generated, require_receipt=False)
    if any(sha(path) != initial[path.resolve()] for path in inputs):
        raise ValueError('heap patch inputs changed during preparation')
    return inputs
