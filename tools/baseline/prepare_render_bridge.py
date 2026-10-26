"""Prepare only the reviewed baseline Honey bridge in the existing build tree.

Run with the existing .venv-codegen under WSL. Original baseline/raw and the
accepted heap image are immutable inputs. N64Recomp exclusively writes guest C.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

import toml
from elftools.elf.elffile import ELFFile
from elftools.elf.relocation import RelocationSection

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import guest_llvm

sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
PREFIX = 2760
FUNCTIONS = ['boot_osInitialize', 'tooie_core1_osInitialize', 'heap_realloc',
             'func_800EBED4', 'func_80800380_chhoneycarrier', 'func_800DCF48',
             'func_80101808', 'func_800DE448']
BRIDGE_FUNCTIONS = FUNCTIONS[3:5]
OMISSIONS = FUNCTIONS[3:]
BONE_CALLEES = {'func_800ADE2C', 'func_80019AA0', 'mlMtxApply', 'func_800DE2A4', 'mlMtxPop'}
BONE_DATA = {'D_8012C968': 0x8012C968, 'D_8012CE58': 0x8012CE58}


def authenticate_function_table(elf_path, overlay_path, section_name, expected_names):
    """Order one declared table by actual ELF offsets; preserve all other text."""
    with elf_path.open('rb') as stream:
        elf=ELFFile(stream);index=elf.get_section_index(section_name);section=elf.get_section(index)
        symbols={s.name:s for s in elf.get_section_by_name('.symtab').iter_symbols() if s.name}
        expected={name:(symbols[name]['st_value']-section['sh_addr'],symbols[name]['st_size']) for name in expected_names}
        assert len(expected)==len(expected_names)>0
        assert {s.name for s in symbols.values() if s['st_info']['type']=='STT_FUNC' and s['st_shndx']==index}==set(expected)
        ordered=sorted(expected,key=lambda name:expected[name][0]);end=0
        for name in ordered:
            offset,size=expected[name];assert size>0 and offset>=end and offset+size<=section['sh_size'];end=offset+size
    text=overlay_path.read_text();table='section_%d_%s_funcs'%(index,section_name.lstrip('.'))
    pattern=r'(static FuncEntry '+re.escape(table)+r'\[\] = \{\n)(.*?)(\n\};)'
    matches=list(re.finditer(pattern,text,re.S));assert len(matches)==1;match=matches[0]
    lines=match[2].splitlines();rows={}
    for line in lines:
        parsed=re.fullmatch(r'    \{ \.func = (\w+), \.offset = (0x[0-9A-Fa-f]+), \.rom_size = (0x[0-9A-Fa-f]+) \},',line)
        assert parsed and parsed[1] not in rows
        name=parsed[1];assert name in expected and (int(parsed[2],16),int(parsed[3],16))==expected[name];rows[name]=line
    assert set(rows)==set(expected) and len(lines)==len(expected)
    block='\n'.join(rows[name] for name in ordered)
    result=text[:match.start(2)]+block+text[match.end(2):]
    assert result[:match.start(2)]==text[:match.start(2)] and result[match.start(2)+len(block):]==text[match.end(2):]
    if result!=text:overlay_path.write_bytes(result.encode())
    return dict(section=section_name,index=index,elf_sha256=sha(elf_path),before_sha256=hashlib.sha256(text.encode()).hexdigest(),after_sha256=sha(overlay_path),members=[dict(name=name,offset=expected[name][0],bytes=expected[name][1]) for name in ordered],only_declared_rows_reordered=True)
PAIR_FUNCTIONS = FUNCTIONS[6:]
PAIR_CALLEES = {'func_800DF47C', 'func_801027F4', 'func_801018D8', 'func_8010347C',
                'func_800A7180', 'func_800DE498'}


def win(path):
    return guest_llvm.host_path(path)


def bodies(directory):
    result = {}
    for path in sorted(directory.glob('funcs_*.c')):
        text = path.read_text()
        matches = list(re.finditer(r'^RECOMP_FUNC void (\w+)\(', text, re.M))
        for i, match in enumerate(matches):
            end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
            assert match[1] not in result
            result[match[1]] = text[match.start():end].rstrip() + '\n'
    return result


def prepare_raw(root, output, run):
    import prepare_baseline_raw
    # Maintained successor of session06 condition 4666dfce, bound to this checkout's paths.
    parent = root / prepare_baseline_raw.CONFIG
    assert toml.loads(parent.read_text()) == prepare_baseline_raw.condition(root), 'raw parent differs from the maintained condition'
    raw = root / 'build/windows-dev/baseline/raw'
    before = bodies(raw)
    config = toml.loads(parent.read_text())
    hooks = config['patches']['hook']
    assert not any(item.get('func') in ['func_800DCF48'] + PAIR_FUNCTIONS for kind in ('hook', 'instruction')
                   for item in config['patches'].get(kind, []))
    for pc, name in [(0x800A78B0, 'baseline_first_sync_returned'),
                     (0x800A78E8, 'baseline_first_graphics_submit')]:
        assert [h['text'] for h in hooks if h['func'] == 'func_800A7840' and h.get('before_vram') == pc] == [name + '(rdram, ctx);']
    assert not any(h['func'] == 'func_8001A4B8' for h in hooks)
    assert not any(h['func'] == 'func_800A7840' and h.get('before_vram') == 0x800A7888 for h in hooks)
    hooks.append(dict(func='func_800A7840', before_vram=0x800A7888,
                      text='baseline_render_construction_begin(rdram, ctx);'))
    for name in OMISSIONS:
        assert name not in config['patches']['ignored']
        config['patches']['ignored'].append(name)
    edits = config['patches'].setdefault('instruction', [])
    for pc in (0x8001A3BC, 0x8001A3CC):
        assert not any(e['vram'] == pc for e in edits)
        edits.append(dict(func='func_8001A3A0', vram=pc, value=0x34048FC0))
    destination = output / 'raw'
    existing = destination.exists()
    destination.mkdir(exist_ok=True)
    config['input']['output_func_path'] = str(destination)
    config_path = output / 'raw.toml'
    serialized = toml.dumps(config)
    if existing:
        assert config_path.read_text() == serialized, 'existing raw config changed'
    else:
        config_path.write_text(serialized)
        run([root / 'deps/N64Recomp-codegen/build/N64Recomp', config_path], 'raw-codegen.log')
    after = bodies(destination)
    assert set(before) - set(after) == set(OMISSIONS) and not set(after) - set(before)
    assert not set(FUNCTIONS).intersection(after), 'raw/patch definition overlap'
    changed = [name for name in after if after[name] != before[name]]
    assert set(changed) == {'func_8001A3A0', 'func_800A7840'}, changed
    assert PAIR_CALLEES <= set(after), 'pair helpers must retain original raw providers'
    hook = '    baseline_render_construction_begin(rdram, ctx);\n'
    new = after['func_800A7840']
    assert new.count(hook) == 1 and new.replace(hook, '') == before['func_800A7840']
    position = new.index(hook)
    assert new.index('L_800A7874:') < position
    assert new.index('func_8001A4B8(rdram, ctx);') < position
    assert new.rindex('func_8001A4B8(rdram, ctx);') < position
    following = new[position + len(hook):]
    assert following.startswith('    // 0x800A7888: jal')
    assert following.index('ctx->r5 = MEM_W(ctx->r29, 0X20);') < following.index('func_800A73F4(rdram, ctx);')
    expected = before['func_8001A3A0']
    for pc in (0x8001A3BC, 0x8001A3CC):
        old = f'    // 0x{pc:08X}: addiu       $a0, $zero, 0x76C0\n    ctx->r4 = ADD32(0, 0X76C0);\n'
        replacement = f'    // 0x{pc:08X}: ori         $a0, $zero, 0x8FC0\n    ctx->r4 = 0 | 0X8FC0;\n'
        # Each original delay-slot instruction also has its unreachable copy.
        assert expected.count(old) == 2
        expected = expected.replace(old, replacement)
    assert after['func_8001A3A0'] == expected
    return dict(parent_sha256=sha(parent), original_body_count=len(before),
                child_body_count=len(after), omitted=OMISSIONS, changed=changed,
                unchanged_body_count=len(after)-2, hook_pc='800A7888',
                original_raw={p.name: sha(p) for p in raw.iterdir() if p.is_file()},
                outputs={p.name: sha(p) for p in destination.iterdir() if p.is_file()})


def prove_s1_image(root, new_path, pair_bytes):
    """Bound link-order proof; only state relocations may alter old text words."""
    old_path = root / 'build/windows-dev/baseline/render-bridge-dcf48/boot.elf'
    with old_path.open('rb') as old_stream, new_path.open('rb') as new_stream:
        old, new = ELFFile(old_stream), ELFFile(new_stream)
        old_text, new_text = old.get_section_by_name('.recomp_patch'), new.get_section_by_name('.recomp_patch')
        end = old_text['sh_addr'] + old_text['sh_size']
        shift = new_text['sh_size'] - old_text['sh_size']
        assert shift == pair_bytes and shift > 0, 'unexpected text growth/alignment'
        old_syms = {s.name: s for s in old.get_section_by_name('.symtab').iter_symbols() if s.name}
        new_syms = {s.name: s for s in new.get_section_by_name('.symtab').iter_symbols() if s.name}
        for name, symbol in old_syms.items():
            assert name in new_syms, name
            target = new_syms[name]
            expected = symbol['st_value'] + (shift if symbol['st_value'] >= end else 0)
            assert target['st_value'] == expected and target['st_size'] == symbol['st_size'], name
            assert target['st_info'] == symbol['st_info'], name
        old_funcs = {n for n, s in old_syms.items() if s['st_info']['type'] == 'STT_FUNC' and s['st_shndx'] != 'SHN_UNDEF'}
        new_funcs = {n for n, s in new_syms.items() if s['st_info']['type'] == 'STT_FUNC' and s['st_shndx'] != 'SHN_UNDEF'}
        assert new_funcs - old_funcs == set(PAIR_FUNCTIONS) and old_funcs <= new_funcs
        old_alloc = {s.name: s for s in old.iter_sections() if s['sh_flags'] & 2 and s['sh_size']}
        new_alloc = {s.name: s for s in new.iter_sections() if s['sh_flags'] & 2 and s['sh_size']}
        assert set(old_alloc) == set(new_alloc) == {'.recomp_patch', '.tooie_render_bridge_state'}
        assert old_alloc['.tooie_render_bridge_state'].data() == new_alloc['.tooie_render_bridge_state'].data()
        def relocs(elf):
            symbols = elf.get_section_by_name('.symtab')
            return [(rel['r_offset'], rel['r_info_type'], symbols.get_symbol(rel['r_info_sym']).name)
                    for section in elf.iter_sections() if isinstance(section, RelocationSection)
                    and section.name == '.rel.recomp_patch' for rel in section.iter_relocations()
                    if rel['r_offset'] < end]
        prior = relocs(old)
        assert relocs(new) == prior, 'existing relocation owners changed'
        a, b = bytearray(old_text.data()), bytearray(new_text.data()[:old_text['sh_size']])
        for offset, kind, name in prior:
            if name == 'tooie_render_bridge_state':
                assert kind in (5, 6), 'unexpected state relocation'
                index = offset - old_text['sh_addr']
                a[index + 2:index + 4] = b'\0\0'
                b[index + 2:index + 4] = b'\0\0'
        assert a == b, 'existing text changed outside bound state HI16/LO16 relocations'
        return dict(prior_elf_sha256=sha(old_path), common_state_shift=shift,
                    old_text_end=end, preserved_symbols=len(old_syms),
                    existing_text_unchanged_except_state_relocations=True)


def prepare_image(root, output, run):
    source = root / 'tools/baseline/guest'
    compiler = guest_llvm.pinned(root, 'clang')
    linker = guest_llvm.linker(root, check=True)
    includes = [source, root/'deps/banjo-tooie/include', root/'deps/banjo-tooie/lib/ultralib/include', root/'deps/rt64/include']
    compile_flags = [compiler, '-target', 'mips', '-EB', '-mips2', '-mabi=32', '-O2', '-G0',
         '-mno-abicalls', '-mno-odd-spreg', '-nostdinc', '-D_LANGUAGE_C', '-DMIPS',
         '-fno-builtin'] + ['-I'+win(p) for p in includes]
    run(compile_flags +
        ['-c', win(source/'render_bridge.c'), '-o', win(output/'bridge.o')], 'bridge-compile.log')
    prior_receipt = json.loads((root/'build/windows-dev/baseline/render-bridge-dcf48/receipt.json').read_text())
    prior_bridge_hash = next(value for name, value in prior_receipt['inputs'].items() if name.endswith('/bridge.o'))
    assert sha(output/'bridge.o') == prior_bridge_hash, 'bridge.o changed'
    run(compile_flags + ['-c', win(source/'bone_handler.c'), '-o', win(output/'bone.o')], 'bone-compile.log')
    prior_bone_hash = next(value for name, value in prior_receipt['inputs'].items() if name.endswith('/bone.o'))
    assert sha(output/'bone.o') == prior_bone_hash, 'bone.o changed'
    run(compile_flags + ['-c', win(source/'draw_boundaries.c'), '-o', win(output/'pair.o')], 'pair-compile.log')
    heap = root/'build/windows-dev/baseline/heap-patch'
    objects = [heap/'boot.o', heap/'core1.o', root/'generated/heap-patch-products/heap.o', output/'bridge.o', output/'bone.o', output/'pair.o']
    assert sha(objects[2]) == 'ed96838f19baceeab975fcd2bec9a3f24893879539a83dc4dad5bc32ba38d3e2'
    with (output/'bridge.o').open('rb') as stream:
        elf = ELFFile(stream)
        assert elf.elfclass == 32 and not elf.little_endian and elf['e_machine'] == 'EM_MIPS'
        functions = [s.name for s in elf.get_section_by_name('.symtab').iter_symbols()
                     if s['st_info']['type'] == 'STT_FUNC' and s['st_shndx'] != 'SHN_UNDEF']
        assert functions == BRIDGE_FUNCTIONS, functions
        assert not {s.name for s in elf.get_section_by_name('.symtab').iter_symbols()
                    if s['st_shndx'] == 'SHN_UNDEF'}.intersection(PAIR_FUNCTIONS), 'unexpected preexisting pair relocation'
        for section in elf.iter_sections():
            assert not (section['sh_flags'] & 2 and section['sh_size'] and section.name not in
                        {'.recomp_patch', '.tooie_render_bridge_state', '.reginfo', '.MIPS.abiflags'}), section.name
    with (output/'bone.o').open('rb') as stream:
        elf = ELFFile(stream)
        assert elf.elfclass == 32 and not elf.little_endian and elf['e_machine'] == 'EM_MIPS'
        symbols = list(elf.get_section_by_name('.symtab').iter_symbols())
        assert [s.name for s in symbols if s['st_info']['type'] == 'STT_FUNC' and s['st_shndx'] != 'SHN_UNDEF'] == ['func_800DCF48']
        assert {s.name for s in symbols if s.name and s['st_shndx'] == 'SHN_UNDEF'} == BONE_CALLEES | set(BONE_DATA)
        for section in elf.iter_sections():
            assert not (section['sh_flags'] & 2 and section['sh_size'] and section.name not in
                        {'.recomp_patch', '.reginfo', '.MIPS.abiflags'}), section.name
        bone_bytes = elf.get_section_by_name('.recomp_patch')['sh_size']
    with (output/'pair.o').open('rb') as stream:
        elf = ELFFile(stream)
        assert elf.elfclass == 32 and not elf.little_endian and elf['e_machine'] == 'EM_MIPS'
        symbols = list(elf.get_section_by_name('.symtab').iter_symbols())
        assert [s.name for s in symbols if s['st_info']['type'] == 'STT_FUNC' and s['st_shndx'] != 'SHN_UNDEF'] == PAIR_FUNCTIONS
        assert {s.name for s in symbols if s.name and s['st_shndx'] == 'SHN_UNDEF'} == PAIR_CALLEES
        for section in elf.iter_sections():
            assert not (section['sh_flags'] & 2 and section['sh_size'] and section.name not in
                        {'.recomp_patch', '.reginfo', '.MIPS.abiflags'}), section.name
        pair_text = elf.get_section_by_name('.recomp_patch').data()
        pair_bytes = len(pair_text)
        for index in range(0, pair_bytes, 4):
            word = int.from_bytes(pair_text[index:index+4], 'big')
            assert not (word >> 26 == 17 and ((word >> 21) & 31) >= 8), 'pair floating-point operation'
        pair_jals = [rel for section in elf.iter_sections() if isinstance(section, RelocationSection) and section.name == '.rel.recomp_patch'
                     for rel in section.iter_relocations()
                     if elf.get_section_by_name('.symtab').get_symbol(rel['r_info_sym']).name == 'func_800DE448']
        assert len(pair_jals) == 1 and pair_jals[0]['r_info_type'] == 4, 'pair boundary R_MIPS_26'
        jump_offset = pair_jals[0]['r_offset']
        assert int.from_bytes(pair_text[jump_offset:jump_offset+4], 'big') >> 26 == 3, 'pair boundary must be JAL, not tail J'
    run([*linker, '-m', 'elf32btsmip', '-T', win(source/'render_bridge.ld'),
         '--unresolved-symbols=ignore-all', '--emit-relocs', '--orphan-handling=error'] +
        [win(p) for p in objects] + ['-o', win(output/'boot.elf')], 'bridge-link.log')
    image_proof = prove_s1_image(root, output/'boot.elf', pair_bytes)
    with (output/'boot.elf').open('rb') as stream:
        elf = ELFFile(stream)
        symbols = {s.name: s for s in elf.get_section_by_name('.symtab').iter_symbols() if s.name}
        section = elf.get_section_by_name('.tooie_render_bridge_state')
        state = section.data()
        state_vram = symbols['tooie_render_bridge_state']['st_value']
        expected = bytearray(4180)
        expected[:4] = bytes.fromhex('42524731'); expected[4:8] = (1).to_bytes(4, 'big')
        expected[32:36] = (1).to_bytes(4, 'big')
        assert state == expected and state_vram % 4 == 0
        assert 0x80801000 <= state_vram and state_vram+len(state) <= 0x81000000
    data = toml.loads((heap/'data.syms.toml').read_text())
    existing_data = [s for section in data['section'] for s in section.get('symbols', [])]
    for name, address in BONE_DATA.items():
        assert not any(s['name'] == name or s['vram'] == address for s in existing_data)
    data['section'][0]['symbols'] += [dict(name=n, vram=a) for n,a in
        {'D_80132ED0':0x80132ED0,'D_8007BCE8':0x8007BCE8,'D_8007BEDA':0x8007BEDA,'D_8007BCD0':0x8007BCD0}.items()]
    data['section'][0]['symbols'] += [dict(name=name, vram=address) for name, address in BONE_DATA.items()]
    (output/'data.syms.toml').write_text(toml.dumps(data))
    config = dict(input=dict(elf_path=str(output/'boot.elf'), output_func_path=str(output),
        single_file_output=True, func_reference_syms_file=str(root/'config/selected.syms.toml'),
        data_reference_syms_files=[str(output/'data.syms.toml')], output_binary_path=str(output/'boot.bin'),
        strict_patch_mode=True, unpaired_lo16_warnings=False, recomp_include='#include "recomp.h"'))
    (output/'boot.toml').write_text(toml.dumps(config))
    run([root/'deps/N64Recomp-codegen/build/N64Recomp', output/'boot.toml'], 'bridge-codegen.log')
    binary = (output/'boot.bin').read_bytes(); prefix = (heap/'boot.bin').read_bytes()
    assert len(prefix) == PREFIX and binary[:PREFIX] == prefix
    assert binary[state_vram-0x80801000:state_vram-0x80801000+4180] == expected
    text=(output/'boot.c').read_text()
    assert re.findall(r'^RECOMP_FUNC void (\w+)\(',text,re.M)==FUNCTIONS
    # Reuse the established extracted-body comparison for the fixed three bodies.
    import importlib.util
    spec=importlib.util.spec_from_file_location('extract_bridge_body',root/'tests/extract_heap_realloc.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    for name in FUNCTIONS[:3]: assert module.extract(text,name)==module.extract((heap/'boot.c').read_text(),name)
    old_text = (root/'build/windows-dev/baseline/render-bridge-dcf48/boot.c').read_text()
    for name in FUNCTIONS[3:6]:
        old_body, new_body = module.extract(old_text,name), module.extract(text,name)
        assert set(re.findall(r'\b(\w+)\(rdram, ctx\);',old_body)) == set(re.findall(r'\b(\w+)\(rdram, ctx\);',new_body)), name
        assert 'LOOKUP_FUNC' not in old_body and 'LOOKUP_FUNC' not in new_body, name
    bone = module.extract(text, 'func_800DCF48')
    assert set(re.findall(r'\b(\w+)\(rdram, ctx\);', bone)) == BONE_CALLEES
    assert 'LOOKUP_FUNC' not in bone
    frame = re.search(r'ctx->r29 = ADD32\(ctx->r29, -0X([0-9A-F]+)\);', bone)
    assert frame, 'missing compiled frame adjustment'
    pair_frames = {}
    for name, expected_callees in [('func_80101808', PAIR_CALLEES - {'func_800A7180','func_800DE498'} | {'func_800DE448'}),
                                    ('func_800DE448', {'func_800A7180','func_800DE498'})]:
        body = module.extract(text,name)
        assert set(re.findall(r'\b(\w+)\(rdram, ctx\);',body)) == expected_callees, name
        assert 'LOOKUP_FUNC' not in body, name
        adjustment = re.search(r'ctx->r29 = ADD32\(ctx->r29, -0X([0-9A-F]+)\);',body)
        assert adjustment, name
        pair_frames[name] = int(adjustment[1],16)
    header = '#pragma once\n#define TOOIE_BRIDGE_STATE_VRAM 0x%08Xu\n#define TOOIE_BRIDGE_IMAGE_BYTES %du\n#define TOOIE_BRIDGE_STATE_IMAGE_OFFSET %du\n' % (state_vram,len(binary),state_vram-0x80801000)
    (output/'render_bridge_layout.h').write_text(header)
    receipt=dict(condition='BASELINE-RENDER-BRIDGE-DRAW-BOUNDARIES',state_vram=state_vram,state_bytes=4180,
                 prefix_bytes=PREFIX,definitions=FUNCTIONS,image_proof=image_proof,bone_frame_bytes=int(frame[1],16),
                 bone_imports=sorted(BONE_CALLEES | set(BONE_DATA)), bridge_object_unchanged=True,bone_object_unchanged=True,
                 pair_imports=sorted(PAIR_CALLEES),pair_frames=pair_frames,pair_boundary_JAL=True,prior_pair_R_MIPS26_mask_required=False,
                 inputs={str(p):sha(p) for p in objects+list(source.glob('render_bridge.*'))+[source/'bone_handler.c',source/'draw_boundaries.c']},
                 outputs={p.name:sha(p) for p in output.iterdir() if p.is_file()})
    (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    return receipt


def main():
    if not __debug__:  # also false when PYTHONOPTIMIZE is set
        raise SystemExit('prepare_render_bridge.py: required validation uses assert; run without -O and with PYTHONOPTIMIZE unset')
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path.cwd())
    parser.add_argument('--raw',action='store_true');parser.add_argument('--image',action='store_true');parser.add_argument('--camera',action='store_true')
    parser.add_argument('--pre-background',action='store_true',help='Guest-owned bounded PRE projection/model slots; accepted demo and paletteOFF only')
    parser.add_argument('--shadow-fix',action='store_true',help='Bounded guest fallback shadow projection and compositor; demo carrier and paletteOFF only')
    parser.add_argument('--demo-timing',action='store_true',help='Guest-owned recorded replay wait divisor; camera carrier only')
    parser.add_argument('--minimum-host',action='store_true',help='Explicit typed cutscene/G07 minimum host guest composition')
    parser.add_argument('--npc665',action='store_true',help='Explicit reviewed NPC665 original-pose owner; actor/PRE camera carrier only')
    parser.add_argument('--backpack621',action='store_true',help='Explicit finite621 owner; existing CPU625 transports required')
    parser.add_argument('--cpu625',action='store_true',help='Explicit reviewed CPU625 owner; actor/PRE carrier only')
    parser.add_argument('--actor-palette',action='store_true',help='Explicit held engineering actor route; camera image only')
    parser.add_argument('--shadow-observer',action='store_true',help='Finite observation-only shadow raw hooks; camera raw only')
    parser.add_argument('--shadow-coefficients',action='store_true',help='Player-accepted shadow route coefficient policy; 621 camera image only')
    parser.add_argument('--flap-flip-landing',action='store_true',help='Guest Flap Flip grounded landing correction')
    parser.add_argument('--first-person-aim',action='store_true',help='Five-body optional modern FPS component; selected HOST/621/Trot composition')
    args=parser.parse_args();assert args.raw or args.image
    assert not args.flap_flip_landing or (args.camera and args.first_person_aim), 'Landing correction requires the qualified player composition'
    assert not args.minimum_host or (args.camera and args.actor_palette and args.pre_background), "HOST requires actor/PRE camera carrier"
    assert not args.npc665 or (args.camera and args.actor_palette and args.pre_background), "NPC665 requires actor/PRE camera carrier"
    assert not args.cpu625 or (args.camera and args.actor_palette and args.pre_background), "CPU625 requires actor/PRE camera carrier"
    assert not args.backpack621 or args.cpu625, "Backpack621 requires selected CPU625 transports"
    assert not args.pre_background or (args.camera and args.demo_timing and args.shadow_fix), 'PRE requires accepted demo and shadow carrier'
    assert not args.shadow_fix or (args.camera and args.demo_timing), 'Shadow fix requires accepted demo carrier'
    assert not (args.shadow_fix and args.actor_palette) or args.pre_background, 'Combined actor/shadow requires reviewed PRE condition'
    assert not args.demo_timing or args.camera, 'Demo timing requires camera carrier'
    assert not args.actor_palette or (args.camera and args.image), 'Actor selection requires camera image'
    assert not args.shadow_observer or (args.camera and args.raw), 'Shadow observation requires camera raw'
    assert not args.shadow_coefficients or (args.camera and args.image and args.shadow_fix and args.backpack621), 'Shadow coefficient policy requires the 621 camera image'
    root=args.root.resolve();output=root/('build/windows-dev/baseline/render-bridge-camera-candidate/composition-v2' if args.camera else 'build/windows-dev/baseline/render-bridge-draw-boundaries');output.mkdir(exist_ok=True,parents=True)
    generator=root/'deps/N64Recomp-codegen/build/N64Recomp'
    assert sha(generator)=='34958d6ae8c047adb772090c75fdcc051036646a1db58595694f814c3a4a09b6'
    def run(command,label):
        with (output/label).open('w') as log:guest_llvm.run_guest(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
    if args.camera:
        import prepare_camera_bridge
        prepare_camera_bridge.prepare(root,output,run,args.raw,args.image,actor_palette=args.actor_palette,shadow_observer=args.shadow_observer,demo_timing=args.demo_timing,shadow_fix=args.shadow_fix,pre_background=args.pre_background,cpu625=args.cpu625,minimum_host=args.minimum_host,npc665=args.npc665,backpack621=args.backpack621,shadow_coefficients=args.shadow_coefficients,first_person_aim=args.first_person_aim,flap_flip_landing=args.flap_flip_landing)
        return
    if args.raw:
        receipt=prepare_raw(root,output,run)
        (output/'RAW_BINDING.json').write_text(json.dumps(receipt,indent=2)+'\n')
        print('raw binding',sha(output/'RAW_BINDING.json'))
    if args.image:
        prepare_image(root,output,run);print('image receipt',sha(output/'receipt.json'))


if __name__=='__main__':main()
