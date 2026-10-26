"""Mechanical local PE/map/selected-guest equality gate; metadata output only."""
import argparse, hashlib, json, re, struct, sys
from pathlib import Path

import elf_binding
import macho_binding

def digest(data): return hashlib.sha256(data).hexdigest()
def check(exe_path, map_path, guest_path, layout_path, fmt='pe', build=None):
    if fmt != 'pe':
        if fmt not in ('elf', 'macho') or build is None: raise ValueError("ELF/Mach-O embedded gate requires format elf or macho and an explicit build root")
        return (check_elf if fmt == 'elf' else check_macho)(exe_path, map_path, guest_path, layout_path, build)
    exe, mapping, guest, layout = (Path(x) for x in (exe_path,map_path,guest_path,layout_path))
    pe=exe.read_bytes(); text=mapping.read_text(); payload=guest.read_bytes()
    def need(test, why):
        if not test: raise ValueError(why)
    def take(offset, size):
        need(0 <= offset <= len(pe) and 0 <= size <= len(pe)-offset, "PE file span outside bounds")
        return pe[offset:offset+size]
    need(take(0,2)==b'MZ', "DOS signature")
    nt=struct.unpack('<I',take(0x3c,4))[0]; need(take(nt,4)==b'PE\0\0', "PE signature")
    count=struct.unpack('<H',take(nt+6,2))[0]; opt_size=struct.unpack('<H',take(nt+20,2))[0]
    opt=nt+24; need(struct.unpack('<H',take(opt,2))[0]==0x20b, "PE32+ required")
    need(opt_size>=32 and 0<count<=96, "PE section/optional-header bounds")
    image_base=struct.unpack('<Q',take(opt+24,8))[0]; sections=[]
    for i in range(count):
        raw=take(opt+opt_size+i*40,40)
        virtual_size,rva,raw_size,raw_offset=struct.unpack_from('<IIII',raw,8)
        take(raw_offset,raw_size); sections.append((rva,raw_size,raw_offset))
    def from_va(va, size):
        need(va>=image_base, "symbol below PE image base")
        rva=va-image_base; matches=[off+rva-start for start,n,off in sections if start<=rva and size<=n and rva-start<=n-size]
        need(len(matches)==1, "symbol span must have exactly one file-backed section")
        return take(matches[0],size)
    addresses={}; owners={}
    for name in ('baseline_boot_patch_bin','baseline_boot_patch_bin_size'):
        matches=re.findall(r'^\s*[0-9A-Fa-f]{4}:[0-9A-Fa-f]+\s+'+name+r'\s+([0-9A-Fa-f]{16})\s+(\S+)\s*$',text,re.M)
        need(len(matches)==1, "map symbol must have exactly one owner: "+name)
        address,owner=matches[0]; need(owner=='baseline_boot_patch_bin.c.obj', "unexpected embedded symbol owner")
        addresses[name]=int(address,16); owners[name]=owner
    size=struct.unpack('<Q',from_va(addresses['baseline_boot_patch_bin_size'],8))[0]
    need(size==len(payload), "linked embedded size differs from selected guest")
    linked=from_va(addresses['baseline_boot_patch_bin'],size)
    need(linked==payload, "linked embedded payload differs from selected guest")
    macros={name:int(value,0) for name,value in re.findall(r'^#define\s+(TOOIE_BRIDGE_\w+)\s+(0x[0-9A-Fa-f]+|[0-9]+)u\s*$',layout.read_text(),re.M)}
    image_bytes=macros['TOOIE_BRIDGE_IMAGE_BYTES']; offset=macros['TOOIE_BRIDGE_STATE_IMAGE_OFFSET']; vram=macros['TOOIE_BRIDGE_STATE_VRAM']
    need(size==image_bytes, "linked size differs from selected layout")
    need(offset<=size and size-offset>=23036, "selected layout state span outside image")
    need(vram==0x80801000+offset and vram+23036<=0x81000000, "selected layout VRAM extent")
    return {'status':'PASS','exe_sha256':digest(pe),'map_sha256':digest(mapping.read_bytes()),'guest_sha256':digest(payload),'layout_sha256':digest(layout.read_bytes()),'embedded_bytes':size,'embedded_sha256':digest(linked),'linked_payload_equals_selected_guest':True,'state_offset':offset,'state_bytes':23036,'state_vram':vram,'symbol_addresses':addresses,'symbol_owners':owners}

def check_elf(exe_path, map_path, guest_path, layout_path, build_path):
    need = elf_binding.need
    exe, mapping, guest, layout = (Path(x) for x in (exe_path, map_path, guest_path, layout_path))
    build = Path(build_path).resolve(); payload = guest.read_bytes()
    elf = elf_binding.Elf(exe); gmap = elf_binding.GnuMap(mapping, build); gmap.bind(elf, exe)
    # The single compiled owner comes from this build's compile database, never a basename guess.
    source = (build/'baseline'/'baseline_boot_patch_bin.c').resolve()
    rows = [r for r in json.loads((build/'compile_commands.json').read_text()) if (Path(r['directory'])/r['file']).resolve() == source]
    need(len(rows) == 1, "embedded payload must have exactly one compiled owner")
    compiled = elf_binding.compile_command(rows[0], build)
    owner = ((build/compiled['output']).resolve(), None)
    addresses, owners, spans = {}, {}, {}
    for name, expected in (('baseline_boot_patch_bin', len(payload)), ('baseline_boot_patch_bin_size', 8)):
        symbol, linked_owner, data = elf_binding.bound_symbol(elf, gmap, name, elf_binding.STT_OBJECT, False)
        need(linked_owner == owner, "unexpected embedded symbol owner")
        need(symbol['size'] == expected, "linked embedded symbol size differs from selected guest: "+name)
        elf.unrelocated(symbol)
        addresses[name], owners[name], spans[name] = symbol['value'], elf_binding.owner_text(owner, build), data
    size = struct.unpack('<Q', spans['baseline_boot_patch_bin_size'])[0]
    need(size == len(payload), "linked embedded size differs from selected guest")
    linked = spans['baseline_boot_patch_bin']
    need(linked == payload, "linked embedded payload differs from selected guest")
    found = re.findall(r'^#define\s+(TOOIE_BRIDGE_\w+)\s+(0x[0-9A-Fa-f]+|[0-9]+)u\s*$', layout.read_text(), re.M)
    need(len({name for name, _ in found}) == len(found), "selected layout macro is duplicated")
    macros = {name: int(value, 0) for name, value in found}
    image_bytes=macros['TOOIE_BRIDGE_IMAGE_BYTES']; offset=macros['TOOIE_BRIDGE_STATE_IMAGE_OFFSET']; vram=macros['TOOIE_BRIDGE_STATE_VRAM']
    need(size==image_bytes, "linked size differs from selected layout")
    need(offset<=size and size-offset>=23036, "selected layout state span outside image")
    need(vram==0x80801000+offset and vram+23036<=0x81000000, "selected layout VRAM extent")
    return {'status':'PASS','format':'elf','exe_sha256':digest(exe.read_bytes()),'map_sha256':digest(mapping.read_bytes()),'guest_sha256':digest(payload),'layout_sha256':digest(layout.read_bytes()),'embedded_bytes':size,'embedded_sha256':digest(linked),'linked_payload_equals_selected_guest':True,'state_offset':offset,'state_bytes':23036,'state_vram':vram,'symbol_addresses':addresses,'symbol_owners':owners}

def check_macho(exe_path, map_path, guest_path, layout_path, build_path):
    need = macho_binding.need
    exe, mapping, guest, layout = (Path(x) for x in (exe_path, map_path, guest_path, layout_path))
    build = Path(build_path).resolve(); payload = guest.read_bytes()
    macho = macho_binding.Macho(exe); lmap = macho_binding.Ld64Map(mapping, build); lmap.bind(macho, exe)
    # The single compiled owner comes from this build's compile database, never a basename guess.
    source = (build/'baseline'/'baseline_boot_patch_bin.c').resolve()
    rows = [r for r in json.loads((build/'compile_commands.json').read_text()) if (Path(r['directory'])/r['file']).resolve() == source]
    need(len(rows) == 1, "embedded payload must have exactly one compiled owner")
    compiled = elf_binding.compile_command(rows[0], build)
    owner = ((build/compiled['output']).resolve(), None)
    addresses, owners, spans = {}, {}, {}
    for name, expected in (('baseline_boot_patch_bin', len(payload)), ('baseline_boot_patch_bin_size', 8)):
        symbol, linked_owner, data = macho_binding.bound_symbol(macho, lmap, name, False)
        need(linked_owner == owner, "unexpected embedded symbol owner")
        need(symbol['size'] == expected, "linked embedded symbol size differs from selected guest: "+name)
        addresses[name], owners[name], spans[name] = symbol['value'], macho_binding.owner_text(owner, build), data
    size = struct.unpack('<Q', spans['baseline_boot_patch_bin_size'])[0]
    need(size == len(payload), "linked embedded size differs from selected guest")
    linked = spans['baseline_boot_patch_bin']
    need(linked == payload, "linked embedded payload differs from selected guest")
    found = re.findall(r'^#define\s+(TOOIE_BRIDGE_\w+)\s+(0x[0-9A-Fa-f]+|[0-9]+)u\s*$', layout.read_text(), re.M)
    need(len({name for name, _ in found}) == len(found), "selected layout macro is duplicated")
    macros = {name: int(value, 0) for name, value in found}
    image_bytes=macros['TOOIE_BRIDGE_IMAGE_BYTES']; offset=macros['TOOIE_BRIDGE_STATE_IMAGE_OFFSET']; vram=macros['TOOIE_BRIDGE_STATE_VRAM']
    need(size==image_bytes, "linked size differs from selected layout")
    need(offset<=size and size-offset>=23036, "selected layout state span outside image")
    need(vram==0x80801000+offset and vram+23036<=0x81000000, "selected layout VRAM extent")
    return {'status':'PASS','format':'macho','exe_sha256':digest(exe.read_bytes()),'map_sha256':digest(mapping.read_bytes()),'guest_sha256':digest(payload),'layout_sha256':digest(layout.read_bytes()),'embedded_bytes':size,'embedded_sha256':digest(linked),'linked_payload_equals_selected_guest':True,'state_offset':offset,'state_bytes':23036,'state_vram':vram,'symbol_addresses':addresses,'symbol_owners':owners}

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('exe');parser.add_argument('map');parser.add_argument('guest');parser.add_argument('layout')
    parser.add_argument('--format',choices=('pe','elf','macho'),default='pe');parser.add_argument('--build');args=parser.parse_args()
    try: print(json.dumps(check(args.exe,args.map,args.guest,args.layout,args.format,args.build)))
    except (OSError,ValueError,KeyError,struct.error) as error:
        print(json.dumps({'status':'FAIL','error':str(error)}));sys.exit(1)
