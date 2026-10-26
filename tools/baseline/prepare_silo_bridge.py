"""Explicit held Silo guest candidate; accepted eight-body preparer is unchanged."""
import argparse
import importlib.util
import json
import re
import subprocess
from pathlib import Path

import toml
from elftools.elf.elffile import ELFFile
from elftools.elf.relocation import RelocationSection
import prepare_render_bridge as accepted

sha, win = accepted.sha, accepted.win
PAIR = ['func_80101808', 'func_800DE448']
SETTERS = ['func_8008B10C', 'anctrl_setSmoothTransition']
LEAF_FUNCTIONS = ['func_800DD998']
LEAF_CALLEES = {'mlMtx_get_stack_pointer', 'func_80018BB4', 'mlMtxApply',
                'func_8010F070', 'osVirtualToPhysical'}
LIFECYCLE_FUNCTIONS = ['func_80092898', 'func_800F3880']
LIFECYCLE_CALLEES = set('_babackpack_entrypoint_9 func_800936E8 func_80093700 func_800AE020 func_800AE080 func_800E09B8 func_800AE6FC func_800DBFF8 func_800EFD24 func_80093370 func_8009337C func_80093230 func_800931AC func_80092778 func_80092864 func_80098E64 heap_free'.split())
FUNCTIONS = accepted.FUNCTIONS + SETTERS + LEAF_FUNCTIONS + LIFECYCLE_FUNCTIONS
HELPER = 'tooie_silo_preflight'
PLAYER_HELPERS = ['tooie_player_begin', 'tooie_player_bone_push', 'tooie_player_bone_pop', 'tooie_player_leaf_begin', 'tooie_player_leaf_end', 'tooie_player_end']
ACTOR_HELPERS = ['tooie_actor_palette_begin', 'tooie_actor_palette_end']
# PC[8] secondary (implementation-s2): a selected owner object in the player helper section.
SECONDARY_HELPERS = ['tooie_secondary_route_begin', 'tooie_secondary_route_end', 'tooie_secondary_route_arm', 'tooie_secondary_route_disarm', 'tooie_player_secondary_begin']
# Closed imports per admission selection: source-derived; the first local measured generation of each
# selection must equal these exactly or replace them with its measured set (never a subset test).
SECONDARY_IMPORTS = {False: {'func_800A89F8', 'D_8012C948', 'tooie_render_bridge_state'},
                     True: {'func_800A89F8', 'func_800EB854', 'func_800AE080', 'D_8012C948', 'D_8012C968', 'D_8012C838', 'D_8012CF8C', 'D_8007BEDA', 'D_8007BCD0', 'D_8007BCD8', 'D_8007BCE8', 'D_8007BCF0', 'tooie_render_bridge_state'}}
# BK pipeline packet1: BK generic owner/root/bone tag helpers, source definition order, in the
# player helper section (as the secondary owner); resident state in its own .tooie_bk_state.
BK_HELPERS = ['tooie_bk_set_model_matrix_group', 'tooie_bk_pop_model_matrix_group', 'tooie_bk_frame_begin',
              'tooie_bk_root_begin', 'tooie_bk_root_end', 'tooie_bk_scope_end',
              'tooie_bk_menu_model_begin', 'tooie_bk_menu_model_end',
              'tooie_bk_actor_draw_begin', 'tooie_bk_de448_begin', 'tooie_bk_de448_end']
# Graph (bk_graph.inc, type-12 selector last) then sort (bk_sort.inc) helpers, in guest definition order.
BK_HELPERS += ['tooie_bk_list_begin', 'tooie_bk_list_end', 'tooie_bk_handler_begin', 'tooie_bk_handler_end',
               'tooie_bk_skin_segment', 'tooie_bk_skin_capture', 'tooie_bk_root_join',
               'tooie_bk_selector_begin', 'tooie_bk_selector_child', 'tooie_bk_selector_end', 'tooie_bk_sort_children']
# Sequential player attachment owner scope (bk_attach.inc, last).
BK_HELPERS += ['tooie_bk_attachment_begin', 'tooie_bk_attachment_end']
# Shadow producer owner scope (bk_shadow_attach.inc, last): route, light event, begin, end, then the DEFB0
# projected-body decision called by shadow_projection.c tooie_shadow_de498.
BK_HELPERS += ['tooie_bk_shadow_route', 'tooie_bk_shadow_light_event', 'tooie_bk_shadow_begin', 'tooie_bk_shadow_end', 'tooie_bk_shadow_project']
assert len(BK_HELPERS) == len(set(BK_HELPERS)) == 29
BK_IMPORTS = {'func_800A89F8', 'func_800EB854', 'func_800DE2A4', 'D_80132ED0', 'D_80135450', 'D_8012C948',
              'D_8012C964', 'D_8012C968', 'D_8012C978', 'D_8012C838', 'D_8012CA11', 'D_8012CF8C',
              'D_80127674', 'D_8012D500', 'D_8012D558', 'tooie_render_bridge_state', 'tooie_camera_state'}
BK_STATE_BYTES = 3412
BK_STATE_INITIAL = bytes.fromhex('424b503100000001')+bytes(BK_STATE_BYTES-8)
BK_FLOAT_BYTES = 803072
BK_FLOAT_INITIAL = bytes.fromhex('00010000000000000000000100000000'+'00000000000100000000000000000001')+bytes(BK_FLOAT_BYTES-32)
BK_CUT_BYTES = 64
BK_CUT_INITIAL = bytes.fromhex('424b433100000001')+bytes(BK_CUT_BYTES-8)
# B4 in the BK selection: (calls, data) retired from these owners. Retired calls must be absent;
# an import may disappear only if it is one of these names; every remaining import stays closed.
BK_RETIRED = {
    'bone': ({'tooie_player_bone_push', 'tooie_player_bone_pop', 'tooie_npc665_bone_push', 'tooie_npc665_bone_pop',
              'tooie_backpack621_bone_push', 'tooie_backpack621_bone_pop'},
             {'tooie_npc665_state', 'tooie_backpack621_state'}),
    'pair': ({'baseline_npc665_end_checked', 'tooie_player_secondary_begin', 'func_80100368'},
             {'tooie_npc665_state'}),
}
BK_SHADOW_BYTES = 1144
BK_SHADOW_INITIAL = bytes.fromhex('424b533100000002')+bytes(BK_SHADOW_BYTES-8)
HELPERS = [HELPER] + PLAYER_HELPERS + ACTOR_HELPERS
GENERATED_FUNCTIONS = FUNCTIONS[:5] + PLAYER_HELPERS + ACTOR_HELPERS + FUNCTIONS[5:6] + [HELPER] + FUNCTIONS[6:8] + SETTERS + LEAF_FUNCTIONS + LIFECYCLE_FUNCTIONS
EXTRA_FUNCTIONS = {'func_80104248', 'func_800A89F8', 'func_800EB854', 'func_80100368', 'func_800AE080','func_80104148','func_80104200'}
RENDER_DATA = {'D_80132ED0','D_8007BCD0','D_8007BCD8','D_8007BCE8','D_8007BCF0',
               'D_8007BEDA','D_8012C948','D_8012C838','D_8012CF8C','D_8012CEC4',
               'D_8012CA11','D_8012C968','D_8012CE58','D_80135450','D_80136EE0',
               'D_80135490','D_801354B0','D_801354DC','D_8012C960',
               'D_80124740','D_8012C820','D_8012C824','D_8012C840','D_8012C850','D_8012CA18','D_80136E70'}
# Accepted draw-boundaries image; the maintained player recipe has none and binds the camera image pin instead.
HONEY_REFERENCE = 'build/windows-dev/baseline/render-bridge-draw-boundaries'


def symbols(elf):
    return {s.name: s for s in elf.get_section_by_name('.symtab').iter_symbols() if s.name}


def relocations(elf):
    syms = elf.get_section_by_name('.symtab')
    return [(r['r_offset'], r['r_info_type'], syms.get_symbol(r['r_info_sym']).name)
            for sec in elf.iter_sections() if isinstance(sec, RelocationSection)
            and sec.name in {'.rel.recomp_patch', '.rel.text.silo_preflight', '.rel.silo_helper', '.rel.text.player_boundary', '.rel.player_helper', '.rel.text.actor_palette', '.rel.actor_helper'} for r in sec.iter_relocations()]


def compile_objects(root, output, run, cpu_root=False, cpu625=False, lifecycle_only=False, npc665=False, shared=False, backpack621=False, hand862=False, talon_trot_toggle=False, honey_reference=HONEY_REFERENCE, required_stop=False, player_secondary=False, secondary_admit=False, bk_pipeline=False):
    assert all(type(x) is bool for x in (cpu_root,cpu625,lifecycle_only,npc665,shared,backpack621,hand862,talon_trot_toggle,player_secondary,secondary_admit,bk_pipeline))
    assert (shared or not player_secondary) and (player_secondary or not secondary_admit), 'the secondary owner needs the partitioned MAIN extent; admission needs the owner'
    assert not bk_pipeline or player_secondary, 'BK pipeline joins only the current player composition'
    assert type(required_stop) is bool and (not required_stop or (shared and cpu_root))
    assert not hand862 or (cpu_root and backpack621), 'Hand862 is compiled only into the selected actor-palette 621 composition'
    assert honey_reference is None or type(honey_reference) is str
    source = root/'tools/baseline/guest/silo-candidate'
    compiler = accepted.guest_llvm.pinned(root, 'clang')
    assert sha(source/'render_bridge.c') == sha(root/'tools/baseline/guest/render_bridge.c')
    includes = [source, root/'deps/banjo-tooie/include', root/'deps/banjo-tooie/lib/ultralib/include', root/'deps/rt64/include']
    flags = [compiler, '-target', 'mips', '-EB', '-mips2', '-mabi=32', '-O2', '-G0',
             '-mno-abicalls', '-mno-odd-spreg', '-nostdinc', '-D_LANGUAGE_C', '-DMIPS', '-fno-builtin']
    flags += ['-I'+win(p) for p in includes]+['-DTOOIE_CPU625='+str(int(cpu625)),'-DTOOIE_NPC665='+str(int(npc665)),'-DTOOIE_BACKPACK621='+str(int(backpack621)),'-DTOOIE_TROT_TOGGLE='+str(int(talon_trot_toggle))]
    flags += ['-DTOOIE_BRIDGE_PHYSICAL_LIST_BYTES='+('0x5BEC0u' if shared else '0x8FC0u'),'-DTOOIE_BK_PIPELINE='+str(int(bk_pipeline))]
    owners = {'bridge': ('render_bridge.c', accepted.BRIDGE_FUNCTIONS),
              'bone': ('bone_handler.c', ['func_800DCF48', HELPER]),
              'pair': ('draw_boundaries.c', PAIR), 'silo': ('silo_nodes.c', SETTERS),
              'player': ('player_boundary.c', PLAYER_HELPERS),
              'actor': ('actor_palette.c', ACTOR_HELPERS),
              'leaf': ('leaf_handler.c', LEAF_FUNCTIONS),
              'lifecycle': ('player_lifecycle.c', LIFECYCLE_FUNCTIONS)}
    if player_secondary:
        owners['secondary']=('player_secondary.c',SECONDARY_HELPERS)
    if bk_pipeline:
        owners['bk']=('bk_pipeline.c',BK_HELPERS)
    if cpu_root and not shared:
        owners={name:owners[name] for name in ('actor','pair')}
    if shared:owners.pop('bridge')
    if cpu_root:
        owners['actor']=('actor_palette.c',ACTOR_HELPERS[:1]+['tooie_actor_cpu_root_begin','tooie_actor_feather_leaf_id']+ACTOR_HELPERS[1:])
    if lifecycle_only:owners={'lifecycle':owners['lifecycle']}
    receipt = {}
    state={'tooie_render_bridge_state'}
    owner_data={'D_80132ED0','D_80135450','D_80136EE0'}
    expected_imports={'pair':accepted.PAIR_CALLEES|{'func_800A89F8','func_800EB854','tooie_player_begin','tooie_player_end','tooie_actor_palette_end'}|{'D_8012C948'}|owner_data|state,
                      'bone':accepted.BONE_CALLEES|{'func_80104248','func_80100368','tooie_player_bone_push','tooie_player_bone_pop'}|
                          (RENDER_DATA-{'D_80135490','D_801354B0','D_801354DC','D_8012C960','D_80124740','D_8012C820','D_8012C824','D_8012C840','D_8012C850','D_8012CA18','D_80136E70'})|state,
                      'silo':{'D_80135450'}|state,
                      'player': {'func_800AE080','func_800A89F8','func_800EB854',
                          'D_80135490','D_801354B0','D_8012C948',
                          'D_8012C838','D_8012C968','D_8012CF8C','D_8007BCD0',
                          'D_8007BEDA','D_8007BCE8','D_8007BCF0'}|state,
                      'leaf': LEAF_CALLEES|{'D_8012C960','D_8012CEC4','tooie_player_leaf_begin','tooie_player_leaf_end'},
                      'lifecycle': LIFECYCLE_CALLEES|state|({'tooie_cpu625_retire'} if cpu625 else set()),
                      'actor': set('D_8007BCD0 D_8007BCD8 D_8007BCE8 D_8007BCF0 D_8007BEDA D_80124740 D_8012C820 D_8012C824 D_8012C838 D_8012C840 D_8012C850 D_8012C948 D_8012C968 D_8012CA18 D_8012CE58 D_8012CEC4 D_8012CF8C D_80132ED0 D_80135450 D_80136E70 D_80136EE0 func_800AE080 func_80100368 func_80104148 func_80104200'.split())|state}
    if cpu_root:expected_imports['actor'].add('D_8012C960')
    if cpu_root and npc665:
        expected_imports['pair'].add('func_80100368')
        expected_imports['actor']|={'func_80100094','func_800A89F8','func_800EB854'}
    if required_stop:expected_imports['actor'].add('tooie_bridge_required_stop')
    if npc665:
        for name in ('pair','bone','silo','actor'):expected_imports[name].add('tooie_npc665_state')
        expected_imports['pair'].add('baseline_npc665_end_checked')
        expected_imports['bone']|={'tooie_npc665_bone_push','tooie_npc665_bone_pop'}
        expected_imports['leaf']|={'tooie_render_bridge_state','tooie_npc665_leaf_begin','tooie_npc665_leaf_end'}
    if backpack621:
        expected_imports['bone']|={'tooie_backpack621_state','tooie_backpack621_bone_push','tooie_backpack621_bone_pop'}
        expected_imports['leaf']|={'tooie_backpack621_state','tooie_backpack621_leaf_begin','tooie_backpack621_leaf_end'}
        expected_imports['lifecycle'].add('tooie_backpack621_retire')
    if talon_trot_toggle:expected_imports['lifecycle'].add('tooie_trot_toggle_retire')
    if player_secondary:
        expected_imports['pair'].add('tooie_player_secondary_begin')
        expected_imports['secondary']=set(SECONDARY_IMPORTS[secondary_admit])
    if bk_pipeline:
        # Bone and pair call the BK helpers; bone also advances the BK traversal words directly.
        expected_imports['bone']|={'tooie_bk_state','tooie_bk_set_model_matrix_group','tooie_bk_pop_model_matrix_group'}
        expected_imports['pair']|={'tooie_bk_actor_draw_begin','tooie_bk_scope_end','tooie_bk_de448_begin','tooie_bk_de448_end'}
        expected_imports['bk']=set(BK_IMPORTS)
        # The leaf's BK list node supersedes the row leaf labels in this path.
        expected_imports['leaf']=LEAF_CALLEES|{'D_8012C960','D_8012CEC4','tooie_bk_list_begin','tooie_bk_list_end'}
    for name, (filename, definitions) in owners.items():
        obj = output/(name+'.o')
        # Actor and player row chains must stay instructions: -fno-jump-tables also stops LLVM's
        # switch-to-lookup-table, so neither object emits the .rodata the section check forbids.
        command=flags+(['-DTOOIE_BRIDGE_REQUIRED_STOP='+str(int(required_stop))] if name=='actor' else [])+(['-DTOOIE_ACTOR_PALETTE='+str(int(cpu_root))] if name in ('actor','pair') else [])+(['-DTOOIE_PLAYER_SECONDARY='+str(int(player_secondary))] if name=='pair' else [])+(['-DTOOIE_PLAYER_SECONDARY_ADMIT='+str(int(secondary_admit))] if name=='secondary' else [])+(['-fno-jump-tables'] if name in ('actor','player','secondary','bk') else [])+(['-DTOOIE_HAND862=1'] if name=='actor' and hand862 else [])+['-c',win(source/filename),'-o',win(obj)]
        run(command, name+'-compile.log')
        with obj.open('rb') as stream:
            elf = ELFFile(stream); syms = symbols(elf)
            assert elf.elfclass == 32 and not elf.little_endian and elf['e_machine'] == 'EM_MIPS'
            actual = [n for n,s in syms.items() if s['st_info']['type']=='STT_FUNC' and s['st_shndx']!='SHN_UNDEF']
            assert actual == definitions, (name,actual)
            imports = {n for n,s in syms.items() if s['st_shndx']=='SHN_UNDEF'}
            if name in expected_imports and bk_pipeline and name in BK_RETIRED:
                retired_calls, retired_data = BK_RETIRED[name]
                assert imports <= expected_imports[name] and not imports & retired_calls and \
                    expected_imports[name] - imports <= retired_calls | retired_data, ('B4 closed imports', name, imports, expected_imports[name])
            elif name in expected_imports: assert imports==expected_imports[name], ('closed imports',name,imports,expected_imports[name])
            if name == 'silo': assert imports <= {'tooie_render_bridge_state','D_80135450'}|({'tooie_npc665_state'} if npc665 else set()), imports
            for sec in elf.iter_sections():
                assert not (sec['sh_flags']&2 and sec['sh_size'] and sec.name not in
                            {'.recomp_patch','.tooie_render_bridge_state','.reginfo','.MIPS.abiflags'} | ({'.text.silo_preflight'} if name == 'bone' else {'.text.player_boundary'} if name in ('player','secondary') else {'.text.player_boundary','.tooie_bk_state','.tooie_bk_float','.tooie_bk_cut','.tooie_bk_shadow'} if name == 'bk' else {'.text.actor_palette'} if name == 'actor' else set())), (name,sec.name)
            text = elf.get_section_by_name('.text.player_boundary' if name in ('player','secondary','bk') else '.text.actor_palette' if name == 'actor' else '.recomp_patch').data()
            for sec in elf.iter_sections():
                if not (sec['sh_flags'] & 4 and sec['sh_size']): continue
                assert sec.name in ({'.recomp_patch', '.text.silo_preflight'} if name == 'bone' else {'.text.player_boundary'} if name in ('player','secondary','bk') else {'.text.actor_palette'} if name == 'actor' else {'.recomp_patch'})
                for i in range(0,sec['sh_size'],4):
                    word=int.from_bytes(sec.data()[i:i+4],'big')
                    assert not (word>>26==0 and word&63 in {0x1a,0x1b,0x34,0x0d}), ('division/trap opcode',name,sec.name,i,hex(word))
            assert all(r[1] in (2,4,5,6) for r in relocations(elf)), ('executable relocation closure',name)
            if name == 'bk':
                state = elf.get_section_by_name('.tooie_bk_state')
                assert state['sh_type']=='SHT_PROGBITS' and state.data()==BK_STATE_INITIAL, 'BK resident state layout1 initializer'
                arena = elf.get_section_by_name('.tooie_bk_float')
                assert arena['sh_type']=='SHT_PROGBITS' and arena.data()==BK_FLOAT_INITIAL, 'BK float producer layout1 initializer'
                cut = elf.get_section_by_name('.tooie_bk_cut')
                assert cut['sh_type']=='SHT_PROGBITS' and cut.data()==BK_CUT_INITIAL, 'BK cut adapter layout1 initializer'
                shadow = elf.get_section_by_name('.tooie_bk_shadow')
                assert shadow['sh_type']=='SHT_PROGBITS' and shadow.data()==BK_SHADOW_INITIAL, 'BK shadow state layout2 initializer'
                # R_MIPS_26 encodes both named JAL calls and assembler-local J branches.
                # A section-symbol J is accepted only within its exact originating function.
                for relsec in elf.iter_sections():
                    if not isinstance(relsec, RelocationSection): continue
                    relsyms = elf.get_section(relsec['sh_link'])
                    code = elf.get_section(relsec['sh_info'])
                    for rel in relsec.iter_relocations():
                        if rel['r_info_type'] != 4: continue
                        offset = rel['r_offset']
                        assert code.name == '.text.player_boundary' and offset % 4 == 0 and offset + 4 <= code['sh_size'], 'BK control relocation extent'
                        word = int.from_bytes(code.data()[offset:offset+4], 'big')
                        target = relsyms.get_symbol(rel['r_info_sym'])
                        if word >> 26 == 3:
                            assert target.name in {'func_800A89F8','func_800EB854','func_800DE2A4','tooie_bk_root_end','tooie_bk_scope_end','tooie_bk_set_model_matrix_group','tooie_bk_pop_model_matrix_group'} and word & 0x3FFFFFF == 0, ('BK helper call closure',offset,target.name)
                        else:
                            owners = [s for s in syms.values() if s['st_info']['type'] == 'STT_FUNC' and s['st_shndx'] == relsec['sh_info'] and s['st_value'] <= offset < s['st_value'] + s['st_size']]
                            destination = target['st_value'] + ((word & 0x3FFFFFF) << 2)
                            assert word >> 26 == 2 and target['st_info']['type'] == 'STT_SECTION' and target['st_shndx'] == relsec['sh_info'] and len(owners) == 1 and owners[0].name in BK_HELPERS and owners[0]['st_value'] <= destination < owners[0]['st_value'] + owners[0]['st_size'], ('BK same-function local J',offset,target.name,hex(destination))
            if name == 'silo':
                assert all(int.from_bytes(text[i:i+4],'big')>>26 != 17 for i in range(0,len(text),4)), 'setter COP1'
            if name == 'pair':
                calls = [r for r in relocations(elf) if r[2]=='func_800DE448']
                assert calls and all(c[1]==4 for c in calls)
                assert all(int.from_bytes(text[c[0]:c[0]+4],'big')>>26==3 for c in calls), 'every pair boundary must use JAL'
            if name == 'bridge' and honey_reference:
                with (root/honey_reference/'bridge.o').open('rb') as old_stream:
                    old=ELFFile(old_stream)
                    assert text==old.get_section_by_name('.recomp_patch').data(), 'Honey object text changed'
                    assert relocations(elf)==relocations(old), 'Honey object relocations changed'
            frames = {}
            for function in definitions:
                symbol = syms[function]
                section=elf.get_section(symbol['st_shndx'])
                instructions = section.data()[symbol['st_value']:symbol['st_value']+symbol['st_size']]
                adjustments = [int.from_bytes(instructions[i:i+4],'big') & 0xffff
                               for i in range(0,len(instructions),4)
                               if int.from_bytes(instructions[i:i+4],'big') >> 16 == 0x27bd]
                frames[function] = max((0x10000-v for v in adjustments if v & 0x8000), default=0)
            if name == 'bone' and not npc665 and not backpack621:
                assert frames=={'func_800DCF48':48, HELPER:56}, ('exact measured object frames',frames)
                helper=syms[HELPER]; assert helper['st_info']['bind']=='STB_GLOBAL'
                code=elf.get_section(helper['st_shndx']).data()[helper['st_value']:helper['st_value']+helper['st_size']]
                prologues=[i for i in range(0,len(code),4) if int.from_bytes(code[i:i+4],'big')==0x27BDFFC8]
                if honey_reference:
                    # Measurements of the historical standalone Silo composition. The maintained player recipe
                    # (--no-prior-honey) skips them: bone_handler.c changed after they were taken (Alpha 4.4)
                    # and the camera image pin binds the result instead.
                    assert sha(obj)=='7356a8f35224811c6fc8f5b730988fac05a003ca1d94c852dd174b0ef4dcf8a3', 'measured bone object changed'
                    assert __import__('hashlib').sha256(code).hexdigest()=='eb5c7f47930974014df369080ef90cd7b731aa9d06e9724d520ff0c3fa216fd9', 'retained Silo helper body changed'
                    assert prologues==[0x1C0], ('helper shrinkwrapped frame',prologues)
                assert len(prologues)==1, ('helper shrinkwrapped frame',prologues)
                calls=[r for r in relocations(elf) if r[2]==HELPER]
                assert len(calls)==1 and calls[0][1:]==(4,HELPER), ('sole direct helper JAL',calls)
            receipt[name] = dict(sha256=sha(obj), definitions=actual, imports=sorted(imports),text_bytes=len(text))
            receipt[name]['frames'] = frames
            if name == 'bone' and not npc665 and not backpack621: receipt[name]['helper_prologue_offset'] = prologues[0]
            receipt[name]['compile_argv']=[str(x) for x in command]
            if name == 'pair': receipt[name]['pair_boundary_JAL_sites'] = [c[0] for c in calls]
    (output/'OBJECT_BINDING.json').write_text(json.dumps(receipt,indent=2)+'\n')
    return receipt


def image(root, output, run, honey_reference=HONEY_REFERENCE):
    source=root/'tools/baseline/guest/silo-candidate'
    object_receipt=compile_objects(root,output,run,honey_reference=honey_reference)
    heap=root/'build/windows-dev/baseline/heap-patch'
    objects=[heap/'boot.o',heap/'core1.o',root/'generated/heap-patch-products/heap.o']+[output/(n+'.o') for n in ('bridge','player','actor','bone','pair','silo','leaf','lifecycle')]
    linker=accepted.guest_llvm.linker(root,check=True)
    run([*linker,'-m','elf32btsmip','-T',win(source/'render_bridge.ld'),'--unresolved-symbols=ignore-all','--emit-relocs','--orphan-handling=error']+
        [win(p) for p in objects]+['-o',win(output/'boot.elf')], 'bridge-link.log')
    with (output/'boot.elf').open('rb') as stream:
        elf=ELFFile(stream); syms=symbols(elf)
        assert [n for n,s in syms.items() if s['st_info']['type']=='STT_FUNC' and s['st_shndx']!='SHN_UNDEF']==GENERATED_FUNCTIONS
        assert {s.name for s in elf.iter_sections() if s['sh_flags']&2 and s['sh_size']}=={'.recomp_patch','.silo_helper','.player_helper','.actor_helper','.tooie_render_bridge_state'}
        expected=bytearray(23036); expected[:4]=bytes.fromhex('42524731'); expected[4:8]=(5).to_bytes(4,'big'); expected[32:36]=(1).to_bytes(4,'big')
        assert elf.get_section_by_name('.tooie_render_bridge_state').data()==expected
        state_vram=syms['tooie_render_bridge_state']['st_value']; assert state_vram%4==0 and state_vram+23036<=0x81000000
        linked_text=elf.get_section_by_name('.recomp_patch'); new_relocs=relocations(elf)
        if honey_reference:
            with (root/honey_reference/'boot.elf').open('rb') as old_stream:
                old=ELFFile(old_stream); old_syms=symbols(old); old_text=old.get_section_by_name('.recomp_patch')
                for name in accepted.BRIDGE_FUNCTIONS:
                    a,b=old_syms[name],syms[name]; assert a['st_size']==b['st_size']
                    left=bytearray(old_text.data()[a['st_value']-old_text['sh_addr']:a['st_value']-old_text['sh_addr']+a['st_size']])
                    right=bytearray(linked_text.data()[b['st_value']-linked_text['sh_addr']:b['st_value']-linked_text['sh_addr']+b['st_size']])
                    old_rs=[(o-a['st_value'],t,n) for o,t,n in relocations(old) if a['st_value']<=o<a['st_value']+a['st_size']]
                    new_rs=[(o-b['st_value'],t,n) for o,t,n in new_relocs if b['st_value']<=o<b['st_value']+b['st_size']]
                    assert old_rs==new_rs
                    for offset,kind,target in old_rs:
                        if target=='tooie_render_bridge_state':
                            assert kind in (5,6); left[offset+2:offset+4]=b'\0\0';right[offset+2:offset+4]=b'\0\0'
                    assert left==right, ('Honey linked text',name)
    data=toml.loads((heap/'data.syms.toml').read_text())
    # Author's explicit data imports are checked against the reviewed selected-symbol addresses.
    required=set().union(*(set(v['imports']) for v in object_receipt.values()))
    function_imports=accepted.BONE_CALLEES|accepted.PAIR_CALLEES|EXTRA_FUNCTIONS|LEAF_CALLEES|LIFECYCLE_CALLEES|set(FUNCTIONS)|set(HELPERS)
    old_imports=set(object_receipt['bridge']['imports'])
    function_imports |= {n for n in old_imports if n.startswith('func_') or n in {'bzero'}}
    function_imports |= old_imports
    data_names={n for n in required if n.startswith('D_')}
    assert data_names <= RENDER_DATA, ('unreviewed renderer data',data_names-RENDER_DATA)
    assert required-data_names-{'tooie_render_bridge_state'} <= function_imports, ('unapproved function imports',required-function_imports-data_names)
    existing_symbols=[s for section in data['section'] for s in section.get('symbols',[])]
    existing={s['name'] for s in existing_symbols}
    for name in data_names:
        address=int(name[2:],16)
        assert not any((s['name']==name and s['vram']!=address) or (s['vram']==address and s['name']!=name)
                       for s in existing_symbols), ('data owner collision',name)
    for name in sorted(data_names-existing):
        data['section'][0]['symbols'].append(dict(name=name,vram=int(name[2:],16)))
    (output/'data.syms.toml').write_text(toml.dumps(data))
    config=dict(input=dict(elf_path=str(output/'boot.elf'),output_func_path=str(output),single_file_output=True,
        func_reference_syms_file=str(root/'config/selected.syms.toml'),data_reference_syms_files=[str(output/'data.syms.toml')],
        output_binary_path=str(output/'boot.bin'),strict_patch_mode=True,unpaired_lo16_warnings=False,recomp_include='#include "recomp.h"'))
    (output/'boot.toml').write_text(toml.dumps(config));run([root/'deps/N64Recomp-codegen/build/N64Recomp',output/'boot.toml'],'bridge-codegen.log')
    binary=(output/'boot.bin').read_bytes();assert binary[:2760]==(heap/'boot.bin').read_bytes()
    assert binary[state_vram-0x80801000:state_vram-0x80801000+23036]==expected
    text=(output/'boot.c').read_text();assert re.findall(r'^RECOMP_FUNC void (\w+)\(',text,re.M)==GENERATED_FUNCTIONS
    spec=importlib.util.spec_from_file_location('extract',root/'tests/extract_heap_realloc.py');extract=importlib.util.module_from_spec(spec);spec.loader.exec_module(extract)
    for name in FUNCTIONS[:3]:assert extract.extract(text,name)==extract.extract((heap/'boot.c').read_text(),name)
    frames={}
    for name in ['func_800DCF48',HELPER]+PAIR+SETTERS+PLAYER_HELPERS+ACTOR_HELPERS+LEAF_FUNCTIONS+LIFECYCLE_FUNCTIONS:
        body=extract.extract(text,name)
        if name in LEAF_FUNCTIONS:
            assert body.count('LOOKUP_FUNC')==2, 'original DD998 callback pair'
        else:
            assert 'LOOKUP_FUNC' not in body
        m=re.search(r'ctx->r29 = ADD32\(ctx->r29, -0X([0-9A-F]+)\);',body)
        frames[name]=int(m[1],16) if m else 0
    assert frames['func_800DCF48']==48 and frames[HELPER]==56, ('exact translated frames',frames)
    bone=extract.extract(text,'func_800DCF48'); helper=extract.extract(text,HELPER)
    for offset,register in [(0x2C,31),(0x28,30)]+[(0x14+4*i,16+i) for i in range(5)]:
        assert f'MEM_W(0X{offset:X}, ctx->r29) = ctx->r{register};' in bone, ('DCF translated saved layout',offset,register)
    assert bone.count(HELPER+'(rdram, ctx);')==1
    assert re.findall(r'ctx->r29 = ADD32\(ctx->r29, -0X([0-9A-F]+)\);',helper)==['38']
    assert (output/'funcs.h').read_text().count('void '+HELPER+'(uint8_t* rdram, recomp_context* ctx);')==1
    assert (output/'recomp_overlays.inl').read_text().count('.func = '+HELPER+',')==1
    header='#pragma once\n#define TOOIE_BRIDGE_STATE_VRAM 0x%08Xu\n#define TOOIE_BRIDGE_IMAGE_BYTES %du\n#define TOOIE_BRIDGE_STATE_IMAGE_OFFSET %du\n'%(state_vram,len(binary),state_vram-0x80801000)
    (output/'render_bridge_layout.h').write_text(header)
    receipt=dict(condition='BASELINE-SILO-GUEST-HELD-CANDIDATE',state_vram=state_vram,state_bytes=23036,prefix_bytes=2760,
        definitions=FUNCTIONS,helper_definitions=HELPERS,raw_omissions=FUNCTIONS[3:],helper_frame_bytes=frames[HELPER],helper_prologue_offset=object_receipt['bone'].get('helper_prologue_offset',0x1C0),bone_frame_bytes=frames['func_800DCF48'],leaf_frame_bytes=frames['func_800DD998'],pair_frames={n:frames[n] for n in PAIR},player_frames={n:frames[n] for n in PLAYER_HELPERS},actor_frames={n:frames[n] for n in ACTOR_HELPERS},lifecycle_frames={n:frames[n] for n in LIFECYCLE_FUNCTIONS},frames=frames,
        honey_reference=honey_reference,honey_object_text_relocations_identical=bool(honey_reference),honey_linked_text_only_state_HI_LO=bool(honey_reference),
        object_binding_sha256=sha(output/'OBJECT_BINDING.json'),inputs={str(p):sha(p) for p in objects+list(source.iterdir()) if p.is_file()},
        outputs={p.name:sha(p) for p in output.iterdir() if p.is_file()})
    (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')


def main():
    if not __debug__:  # also false when PYTHONOPTIMIZE is set
        raise SystemExit('prepare_silo_bridge.py: required validation uses assert; run without -O and with PYTHONOPTIMIZE unset')
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,required=True);parser.add_argument('--raw',action='store_true');parser.add_argument('--image',action='store_true');parser.add_argument('--objects',action='store_true')
    parser.add_argument('--no-prior-honey',action='store_true',help='Maintained recipe: no historical draw-boundaries image; the camera image pin binds the result');args=parser.parse_args()
    root=args.root.resolve();output=root/'build/windows-dev/baseline/render-bridge-silo-candidate';output.mkdir(exist_ok=True)
    assert sha(root/'deps/N64Recomp-codegen/build/N64Recomp')=='34958d6ae8c047adb772090c75fdcc051036646a1db58595694f814c3a4a09b6'
    def run(command,label):
        with (output/label).open('w') as log:accepted.guest_llvm.run_guest(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
    if args.raw:
        accepted.FUNCTIONS=FUNCTIONS;accepted.OMISSIONS=FUNCTIONS[3:];accepted.PAIR_FUNCTIONS=PAIR+SETTERS
        receipt=accepted.prepare_raw(root,output,run);(output/'RAW_BINDING.json').write_text(json.dumps(receipt,indent=2)+'\n');print('raw',sha(output/'RAW_BINDING.json'))
    honey_reference=None if args.no_prior_honey else HONEY_REFERENCE
    if args.image:image(root,output,run,honey_reference);print('image',sha(output/'receipt.json'))
    elif args.objects:compile_objects(root,output,run,honey_reference=honey_reference);print('objects',sha(output/'OBJECT_BINDING.json'))


if __name__=='__main__':main()
