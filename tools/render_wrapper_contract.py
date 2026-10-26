"""Finite contract of the qualified eight-object rendering replacement image.

Shared by the canonical preparer and strict verifier. Original reference rows
are normalized identities, not original instructions or a runtime registry.
"""
import guest_llvm

CALLEES = ('heap_resize_block', 'func_8001B864', 'heap_alloc',
           'aligned8_memcpy', 'func_8001BD30', 'heap_free')
HEAP_DATA = {'D_8003F750': 0x8003F750}
INITIALIZE_DATA = {
    'boot___osFinalrom': 0x80006F50, 'boot_osClockRate': 0x80004250,
    'boot_osViClock': 0x80004258, 'boot___Dom1SpeedParam': 0x80006F60,
    'boot___Dom2SpeedParam': 0x80006FD8, 'boot___osExceptionPreamble': 0x80001C90,
    '__osFinalrom': 0x8007EAD0, 'osClockRate': 0x80041390,
    'osViClock': 0x80041398, '__Dom1SpeedParam': 0x8007EAE0,
    '__Dom2SpeedParam': 0x8007EB58, '__osExceptionPreamble': 0x80031FE0,
    'osTvType': 0x80000300, 'osResetType': 0x8000030C, 'osAppNMIBuffer': 0x8000031C}
REPLACEMENTS = {'heap_realloc': (0x8001B208, 0x180),
                'boot_osInitialize': (0x800016F0, 0x2A8),
                'tooie_core1_osInitialize': (0x8002D7B0, 0x2A8),
                'func_8001A3A0': (0x8001A3A0, 160), 'func_8001A324': (0x8001A324, 124),
                'func_800A7840': (0x800A7840, 220), 'func_800EBED4': (0x800EBED4, 184),
                'func_8010A79C': (0x8010A79C, 100), 'func_800E42F0': (0x800E42F0, 332)}
RENDER_STORAGE = {'.tooie_gfx_buffers': ('tooie_gfx_pools', 112016, 8),
                  '.tooie_family_birth_state': ('tooie_family_birth_state', 1168, 4)}
NATIVE_IMPORT = {'tooie_get_construction_model_policy': 0x8F000000}
HUD_IMPORT = {'tooie_get_hud_half_width_bits': 0x8F000004}
HUD_DATA = {'widescreen_enabled': 0x800799B8, 'D_8012D554': 0x8012D554}
HUD_CALLEES = ('guOrtho', 'guMtxIdent', *HUD_IMPORT)
HUD_LITERALS = bytes.fromhex('44180000444a8000c4180000c44a8000')
HUD_LINKED_LITERALS = bytes.fromhex('44180000c44a8000c4180000444a8000')
GRAPHICS_DATA = {name: int(name[2:], 16) for name in (
    'D_8007BCD0', 'D_8007BCD8', 'D_8007BCE0', 'D_8007BCE8', 'D_8007BEDA',
    'D_80127634', 'D_80127658', 'D_80127650', 'D_801255F4')}
FAMILY_DATA = {name: int(name[2:], 16) for name in (
    'D_80132ED0', 'D_80135450', 'D_8007BCD0', 'D_8007BCE8', 'D_8007BEDA')}
GRAPHICS_CALLEES = ('heap_alloc', 'heap_free', 'func_8001A570', 'func_800A9800',
    'func_8001A63C', 'func_8001A4B8', 'func_80014F58', 'func_8001BD50',
    'func_800A73F4', 'func_80015410', 'func_800A7FD4', 'func_800E82EC',
    'func_8001A270', 'func_80015878', 'func_800E4628', *NATIVE_IMPORT)
FAMILY_CALLEES = ('_bzero', 'func_800EBD78', 'func_800EC854', 'func_800EBB50',
    'func_800EBE74', 'func_80100368', 'func_800A7180', 'func_800A89F8', 'func_800EB854')

REPLACEMENTS.update({
    'func_80015D14': (0x80015D14, 76),
    'func_800DE448': (0x800DE448, 80),
    'func_800F3880': (0x800F3880, 40),
    'func_800F482C': (0x800F482C, 144),
    'func_800F759C': (0x800F759C, 132),
    'babackpack_entrypoint_3': (0x80800320, 276),
})
NATIVE_IMPORTS = {
    "tooie_get_construction_model_policy": 2399141888,
    "tooie_get_hud_half_width_bits": 2399141892,
    "tooie_get_submitted_render_tuple": 2399141896,
    "tooie_wrapper_attachment_begin": 2399141900,
    "tooie_wrapper_attachment_end": 2399141904,
    "tooie_wrapper_source_span_begin": 2399141908,
    "tooie_wrapper_source_span_end": 2399141912,
    "tooie_get_scene_tuple32": 2399141916,
    "tooie_get_latched_widescreen_settings": 2399141920
}
ORIGINAL_REFERENCES = {
    "D_8003F750": [
        2147743568,
        0,
        1
    ],
    "D_80041710": [
        2147751696,
        0,
        0
    ],
    "D_8007BCD0": [
        2147990736,
        0,
        0
    ],
    "D_8007BCD8": [
        2147990744,
        0,
        0
    ],
    "D_8007BCE0": [
        2147990752,
        0,
        0
    ],
    "D_8007BCE8": [
        2147990760,
        0,
        0
    ],
    "D_8007BCF0": [
        2147990768,
        0,
        0
    ],
    "D_8007BEDA": [
        2147991258,
        0,
        0
    ],
    "D_8007BF00": [
        2147991296,
        0,
        1
    ],
    "D_8007E990": [
        2148002192,
        0,
        1
    ],
    "D_80123198": [
        2148675992,
        0,
        0
    ],
    "D_80123418": [
        2148676632,
        0,
        1
    ],
    "D_80123428": [
        2148676648,
        0,
        1
    ],
    "D_801255F4": [
        2148685300,
        0,
        0
    ],
    "D_8012762C": [
        2148693548,
        0,
        1
    ],
    "D_80127634": [
        2148693556,
        0,
        0
    ],
    "D_80127650": [
        2148693584,
        0,
        1
    ],
    "D_80127658": [
        2148693592,
        0,
        1
    ],
    "D_80127760": [
        2148693856,
        0,
        0
    ],
    "D_8012B3F1": [
        2148709361,
        0,
        0
    ],
    "D_8012B3F2": [
        2148709362,
        0,
        0
    ],
    "D_8012C824": [
        2148714532,
        0,
        1
    ],
    "D_8012C838": [
        2148714552,
        0,
        0
    ],
    "D_8012C83C": [
        2148714556,
        0,
        0
    ],
    "D_8012C840": [
        2148714560,
        0,
        0
    ],
    "D_8012C844": [
        2148714564,
        0,
        0
    ],
    "D_8012C848": [
        2148714568,
        0,
        0
    ],
    "D_8012C948": [
        2148714824,
        0,
        0
    ],
    "D_8012C9A8": [
        2148714920,
        0,
        0
    ],
    "D_8012C9B0": [
        2148714928,
        0,
        0
    ],
    "D_8012CA28": [
        2148715048,
        0,
        0
    ],
    "D_8012CEC4": [
        2148716228,
        0,
        0
    ],
    "D_8012CF8C": [
        2148716428,
        0,
        0
    ],
    "D_8012D554": [
        2148717908,
        0,
        1
    ],
    "D_8012D5E0": [
        2148718048,
        0,
        1
    ],
    "D_80132ED0": [
        2148740816,
        0,
        0
    ],
    "D_80135450": [
        2148750416,
        0,
        0
    ],
    "D_80135490": [
        2148750480,
        0,
        1
    ],
    "D_801354B0": [
        2148750512,
        0,
        0
    ],
    "D_801354D9": [
        2148750553,
        0,
        0
    ],
    "__Dom1SpeedParam": [
        2148002528,
        116,
        1
    ],
    "__Dom2SpeedParam": [
        2148002648,
        116,
        1
    ],
    "__osExceptionPreamble": [
        2147688416,
        16,
        2
    ],
    "__osFinalrom": [
        2148002512,
        4,
        1
    ],
    "_bzero": [
        2147669728,
        156,
        2
    ],
    "aligned8_memcpy": [
        2147589744,
        40,
        2
    ],
    "baanim_getTimer": [
        2148059848,
        36,
        2
    ],
    "babackpack_entrypoint_1": [
        2155872480,
        60,
        2
    ],
    "boot___Dom1SpeedParam": [
        2147512160,
        116,
        1
    ],
    "boot___Dom2SpeedParam": [
        2147512280,
        116,
        1
    ],
    "boot___osExceptionPreamble": [
        2147490960,
        16,
        2
    ],
    "boot___osFinalrom": [
        2147512144,
        4,
        1
    ],
    "boot___osSetFpcCsr": [
        2147490768,
        16,
        2
    ],
    "boot_osClockRate": [
        2147500624,
        8,
        1
    ],
    "boot_osViClock": [
        2147500632,
        4,
        1
    ],
    "func_80014F58": [
        2147569496,
        12,
        2
    ],
    "func_80015410": [
        2147570704,
        32,
        2
    ],
    "func_80015878": [
        2147571832,
        108,
        2
    ],
    "func_8001A270": [
        2147590768,
        32,
        2
    ],
    "func_8001A4B8": [
        2147591352,
        184,
        2
    ],
    "func_8001A570": [
        2147591536,
        8,
        2
    ],
    "func_8001A63C": [
        2147591740,
        132,
        2
    ],
    "func_8001B864": [
        2147596388,
        12,
        2
    ],
    "func_8001BD30": [
        2147597616,
        32,
        2
    ],
    "func_8001BD50": [
        2147597648,
        92,
        2
    ],
    "func_8008B10C": [
        2148053260,
        40,
        2
    ],
    "func_8008B304": [
        2148053764,
        32,
        2
    ],
    "func_8008B4D4": [
        2148054228,
        32,
        2
    ],
    "func_8008CA74": [
        2148059764,
        36,
        2
    ],
    "func_80098E64": [
        2148109924,
        824,
        2
    ],
    "func_800A0714": [
        2148140820,
        1292,
        2
    ],
    "func_800A3274": [
        2148151924,
        12,
        2
    ],
    "func_800A7180": [
        2148168064,
        12,
        2
    ],
    "func_800A73F4": [
        2148168692,
        400,
        2
    ],
    "func_800A7FD4": [
        2148171732,
        404,
        2
    ],
    "func_800A89F8": [
        2148174328,
        12,
        2
    ],
    "func_800A91F4": [
        2148176372,
        180,
        2
    ],
    "func_800A9800": [
        2148177920,
        40,
        2
    ],
    "func_800DE498": [
        2148394136,
        3724,
        2
    ],
    "func_800DF41C": [
        2148398108,
        12,
        2
    ],
    "func_800DF720": [
        2148398880,
        12,
        2
    ],
    "func_800DF738": [
        2148398904,
        12,
        2
    ],
    "func_800DF818": [
        2148399128,
        12,
        2
    ],
    "func_800E4628": [
        2148419112,
        24,
        2
    ],
    "func_800E82EC": [
        2148434668,
        1008,
        2
    ],
    "func_800EB854": [
        2148448340,
        12,
        2
    ],
    "func_800EBB50": [
        2148449104,
        12,
        2
    ],
    "func_800EBD78": [
        2148449656,
        172,
        2
    ],
    "func_800EBE74": [
        2148449908,
        96,
        2
    ],
    "func_800EC854": [
        2148452436,
        60,
        2
    ],
    "func_800F82C0": [
        2148500160,
        20,
        2
    ],
    "func_80100368": [
        2148533096,
        36,
        2
    ],
    "func_80100AC4": [
        2148534980,
        120,
        2
    ],
    "func_80101238": [
        2148536888,
        152,
        2
    ],
    "func_8080021C_babackpack": [
        2155872796,
        72,
        2
    ],
    "guMtxIdent": [
        2147675964,
        48,
        2
    ],
    "guOrtho": [
        2147671556,
        100,
        2
    ],
    "heap_alloc": [
        2147593420,
        32,
        2
    ],
    "heap_free": [
        2147594372,
        68,
        2
    ],
    "heap_resize_block": [
        2147594696,
        64,
        2
    ],
    "osAppNMIBuffer": [
        2147484444,
        0,
        1
    ],
    "osClockRate": [
        2147750800,
        8,
        1
    ],
    "osGetThreadId": [
        2147687376,
        24,
        2
    ],
    "osResetType": [
        2147484428,
        0,
        1
    ],
    "osTvType": [
        2147484416,
        0,
        1
    ],
    "osViClock": [
        2147750808,
        4,
        1
    ],
    "widescreen_enabled": [
        2147981752,
        0,
        1
    ]
}
OBJECT_CONTRACTS = [
    {
        "stem": "heap",
        "functions": [
            "heap_realloc"
        ],
        "imports": [
            "D_8003F750",
            "aligned8_memcpy",
            "func_8001B864",
            "func_8001BD30",
            "heap_alloc",
            "heap_free",
            "heap_resize_block"
        ]
    },
    {
        "stem": "initialize",
        "functions": [
            "boot_osInitialize",
            "tooie_core1_osInitialize"
        ],
        "imports": [
            "__Dom1SpeedParam",
            "__Dom2SpeedParam",
            "__osExceptionPreamble",
            "__osFinalrom",
            "boot___Dom1SpeedParam",
            "boot___Dom2SpeedParam",
            "boot___osExceptionPreamble",
            "boot___osFinalrom",
            "boot___osSetFpcCsr",
            "boot_osClockRate",
            "boot_osViClock",
            "osAppNMIBuffer",
            "osClockRate",
            "osResetType",
            "osTvType",
            "osViClock"
        ]
    },
    {
        "stem": "hud_projection",
        "functions": [
            "func_800E42F0"
        ],
        "imports": [
            "D_8012D554",
            "guMtxIdent",
            "guOrtho",
            "tooie_get_hud_half_width_bits",
            "widescreen_enabled"
        ]
    },
    {
        "stem": "graphics_buffers",
        "functions": [
            "func_8001A324",
            "func_8001A3A0",
            "func_800A7840"
        ],
        "imports": [
            "D_8007BCD0",
            "D_8007BCD8",
            "D_8007BCE0",
            "D_8007BCE8",
            "D_8007BEDA",
            "D_801255F4",
            "D_80127634",
            "D_80127650",
            "D_80127658",
            "func_80014F58",
            "func_80015410",
            "func_80015878",
            "func_8001A270",
            "func_8001A4B8",
            "func_8001A570",
            "func_8001A63C",
            "func_8001BD50",
            "func_800A73F4",
            "func_800A7FD4",
            "func_800A9800",
            "func_800E4628",
            "func_800E82EC",
            "heap_alloc",
            "heap_free",
            "osGetThreadId",
            "tooie_get_construction_model_policy",
            "tooie_get_submitted_render_tuple",
            "tooie_wrapper_state"
        ]
    },
    {
        "stem": "family",
        "functions": [
            "func_800EBED4",
            "func_8010A79C"
        ],
        "imports": [
            "D_8007BCD0",
            "D_8007BCE8",
            "D_8007BEDA",
            "D_80132ED0",
            "D_80135450",
            "_bzero",
            "func_800A7180",
            "func_800A89F8",
            "func_800EB854",
            "func_800EBB50",
            "func_800EBD78",
            "func_800EBE74",
            "func_800EC854",
            "func_80100368",
            "tooie_gfx_pools"
        ]
    },
    {
        "stem": "model_nodes",
        "functions": [
            "babackpack_entrypoint_3",
            "func_800DE448",
            "func_800F3880"
        ],
        "imports": [
            "D_8007BCD0",
            "D_8007BCD8",
            "D_8007BCE8",
            "D_8007BCF0",
            "D_8007BEDA",
            "D_8007BF00",
            "D_8007E990",
            "D_80123198",
            "D_80123418",
            "D_80123428",
            "D_8012762C",
            "D_80127634",
            "D_80127760",
            "D_8012B3F1",
            "D_8012B3F2",
            "D_8012C824",
            "D_8012C838",
            "D_8012C83C",
            "D_8012C840",
            "D_8012C844",
            "D_8012C848",
            "D_8012C948",
            "D_8012C9A8",
            "D_8012C9B0",
            "D_8012CA28",
            "D_8012CEC4",
            "D_8012CF8C",
            "D_8012D5E0",
            "D_80135490",
            "baanim_getTimer",
            "babackpack_entrypoint_1",
            "func_8008B10C",
            "func_8008B304",
            "func_8008B4D4",
            "func_8008CA74",
            "func_80098E64",
            "func_800A0714",
            "func_800A7180",
            "func_800A89F8",
            "func_800DE498",
            "func_800DF41C",
            "func_800DF720",
            "func_800DF738",
            "func_800DF818",
            "func_800EB854",
            "func_80100AC4",
            "func_8080021C_babackpack",
            "heap_free",
            "osGetThreadId",
            "tooie_get_scene_tuple32",
            "tooie_get_submitted_render_tuple",
            "tooie_gfx_pools",
            "tooie_wrapper_attachment_begin",
            "tooie_wrapper_attachment_end",
            "tooie_wrapper_source_span_begin",
            "tooie_wrapper_source_span_end",
            "tooie_wrapper_state"
        ]
    },
    {
        "stem": "player_release",
        "functions": [
            "func_800F482C",
            "func_800F759C"
        ],
        "imports": [
            "D_80135490",
            "D_801354B0",
            "D_801354D9",
            "func_800A3274",
            "func_800A91F4",
            "func_800F3880",
            "func_800F82C0",
            "func_80101238",
            "tooie_wrapper_state"
        ]
    },
    {
        "stem": "native_aspect_projection",
        "functions": [
            "func_80015D14"
        ],
        "imports": [
            "D_80041710",
            "tooie_get_latched_widescreen_settings",
            "widescreen_enabled"
        ]
    }
]
SOURCES = {
    "heap": "patches/game/heap.c",
    "initialize": "patches/game/initialize.c",
    "hud_projection": "patches/game/hud_projection.c",
    "native_aspect_projection": "patches/game/native_aspect_projection.c",
    "graphics_buffers": "patches/render_wrapper/guest/production/graphics_buffers.c",
    "family": "patches/render_wrapper/guest/production/family.c",
    "model_nodes": "patches/render_wrapper/guest/production/model_nodes.c",
    "player_release": "patches/render_wrapper/guest/production/player_release.c"
}
CUSTOM_DATA = {'tooie_gfx_pools', 'tooie_family_birth_state', 'tooie_wrapper_state'}
PATCH_INPUTS = (
    *SOURCES.values(), 'patches/game/heap.ld',
    'tools/prepare_heap_patch.py', 'tools/render_wrapper_contract.py',
    'tools/render_wrapper_validator.py', 'tools/verify_render_wrapper_image.py',
    'tools/codegen_provenance.py',
    'tools/guest_llvm.py',
    *(guest_llvm.TOOLS[name] for name in ('clang', 'lld', 'objcopy')),
)
LITERAL_SECTIONS = ('.tooie_hud_literals', '.tooie_wrapper_literals', '.tooie_aspect_literals')
ORIGINAL_ELF_SHA256 = '331fe74764f14ef480688da128bb0c75ee388c416e6af7de38beff7defb8373f'

def object_parameters(row):
    imports = set(row['imports'])
    data_names = {name for name in imports if name.startswith('D_') or
                  name in INITIALIZE_DATA or name == 'widescreen_enabled' or name in CUSTOM_DATA}
    data = {name: ORIGINAL_REFERENCES[name][0] if name in ORIGINAL_REFERENCES else None
            for name in data_names}
    calls = imports - data_names
    storage = {section: entry for section, entry in RENDER_STORAGE.items()
               if row['stem'] == ('graphics_buffers' if entry[0] == 'tooie_gfx_pools' else 'family')}
    native = {name: address for name, address in NATIVE_IMPORTS.items() if name in imports}
    return data, row['functions'], calls, storage, native

def linked_parameters():
    definitions = set(REPLACEMENTS)
    all_imports = {name for row in OBJECT_CONTRACTS for name in row['imports']}
    data_names = {name for row in OBJECT_CONTRACTS for name in object_parameters(row)[0]}
    data = {name: ORIGINAL_REFERENCES[name][0] if name in ORIGINAL_REFERENCES else None
            for name in data_names}
    return data, definitions, all_imports - data_names

