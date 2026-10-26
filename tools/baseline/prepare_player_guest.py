"""Maintained player guest recipe: baseline raw, boot/core1/heap, Silo, then the
selected 621 composition with the existing shadow policy, qualified hand labels
and a public refresh-rate command using the intended game/demo cadence.

Run under the existing WSL codegen environment after tools/prepare_codegen.py has
produced config/, generated/heap-patch-products/ and generated/core2-expected.bin
from the user's validated ROM (--rom) and decomp build. Every step writes only
fresh build/windows-dev/baseline outputs.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

BASELINE = 'build/windows-dev/baseline'
CAMERA = BASELINE + '/render-bridge-camera-candidate/composition-v2'
OUTPUTS = [BASELINE + '/raw', BASELINE + '/heap-patch', BASELINE + '/render-bridge-silo-candidate', CAMERA,
           BASELINE + '/core1-publication', BASELINE + '/core2-publication', BASELINE + '/ipl3-scatter']
# Explicit render-bridge flags; shadow_observer stays OFF. Quiet/Toggled Talon
# Trot follow backpack621 + shadow-coefficients + minimum-host in camera preparation.
# The receipt and independent image pins below identify the complete selection.
SELECTION = ['--actor-palette', '--demo-timing', '--shadow-fix', '--pre-background', '--cpu625',
             '--minimum-host', '--npc665', '--backpack621', '--shadow-coefficients', '--first-person-aim', '--flap-flip-landing']
# Historical quiet-only image: 3ab2614823ac33e1d6f271aeb0ba6a34f8457efcbf5b75da6d2c4b952f7c7e7e
PRE_MUSIC_IMAGE_SHA256 = '290755f1ecd95da325877c5dab99ed807c8bc373db04ec1c8a3a85fc633f6aaf'
PRE_MUSIC_IMAGE_BYTES = 320976
PRE_MUSIC_LAYOUT_SHA256 = 'b726ebea67ddb48241d9fe590a41048ca7d89c576158ac36297098526746b8c7'
# Unqualified music composition: root installs only measured, independently checked pins.
IMAGE_SHA256 = '263e1d27d21ebd9d1604f7096cf6f97466b1b74041dbd745cce278980b21b3d8'
IMAGE_BYTES = 1830544
LAYOUT_SHA256 = '230267fc2b821e27c9f9dff5b4a76af1952a8df2c3df6a143d4a8e07303b0061'
ROM_SHA256 = '9ec37fba6890362eba86fb855697a9cff1519275531b172083a1a6a045483583'
DECOMPRESSED_SHA256 = '8c9d316b2edca686ec8393ddf95d480a7dfd9879ef434dbcfc4ea3000f2ffe89'
# Files of the legacy standalone Silo directory that prepare_camera_bridge reads as premises.
LEGACY_PREMISE_FILES = ('boot.bin', 'data.syms.toml')
# Native publication references that Baseline.cmake authenticates at configure.
CORE1_OBSERVATION = BASELINE + '/core1-publication/core1-observation.bin'
CORE1_RANGE = (0x01E29B60, 0x01E5AEB0)  # Decompressed ROM core1 slice, 201552 bytes.
CORE1_SHA256 = '965ccdb935542a113c1d58e12fccdb3ff326f3c02abebdda95cc7657403d7ad0'
CORE2_OBSERVATION = BASELINE + '/core2-publication/core2-observation.bin'
CORE2_SHA256 = '6522eefee489b670fb24e594642c5bfb693e639e2c6d82c40dc9fe2eaa12adc7'
IPL3_SHAPE = BASELINE + '/ipl3-scatter/ipl3_shape.hpp'
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()


def prepare_native_references(root, rom):
    """Core1/core2 observation bytes and the IPL3 shape from the validated ROM inputs."""
    if sha(rom) != ROM_SHA256:
        raise ValueError('NTSC-U ROM identity mismatch')
    decompressed = (root / 'deps/banjo-tooie/decompressed.us.z64').read_bytes()
    if hashlib.sha256(decompressed).hexdigest() != DECOMPRESSED_SHA256:
        raise ValueError('decompressed ROM identity mismatch')
    # Core2 is prepare_codegen's ELF-checked inflation of the ROM's compressed core2 streams.
    for name, data, digest in [(CORE1_OBSERVATION, decompressed[CORE1_RANGE[0]:CORE1_RANGE[1]], CORE1_SHA256),
                               (CORE2_OBSERVATION, (root / 'generated/core2-expected.bin').read_bytes(), CORE2_SHA256)]:
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError(f'native reference differs from its pin: {name}')
        (root / name).parent.mkdir(parents=True)
        (root / name).write_bytes(data)
    sys.path.insert(0, str(root / 'tools'))
    from prepare_ipl3_shape import prepare as prepare_ipl3_shape
    (root / IPL3_SHAPE).parent.mkdir(parents=True)
    prepare_ipl3_shape(rom, root / IPL3_SHAPE)


def main():
    # The camera/render/Silo steps check identity with assert; never skip them.
    if not __debug__:  # also false when PYTHONOPTIMIZE is set
        raise SystemExit('prepare_player_guest.py: required validation uses assert; '
                         'run without -O and with PYTHONOPTIMIZE unset')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--rom', type=Path, required=True, help='User-supplied NTSC-U ROM; never copied')
    parser.add_argument('--legacy-standalone-dir', type=Path,
                        help='Silo step output from commit 61caf07. prepare_camera_bridge reads its boot.bin (pinned as '
                             'LEGACY_STANDALONE_IMAGE_SHA256) and data.syms.toml as premises that a fresh Silo step cannot '
                             'regenerate. Those two files replace the fresh ones; everything else stays fresh.')
    args = parser.parse_args()
    root, rom = args.root.resolve(), args.rom.resolve()
    if sys.platform != 'linux':
        raise RuntimeError('Use the existing WSL codegen environment')
    for name in OUTPUTS:
        if (root / name).exists():
            raise ValueError(f'fresh build tree required; preserve existing {name}')
    prepare_native_references(root, rom)
    tools = root / 'tools/baseline'
    def step(script, *args):
        subprocess.run([sys.executable, str(tools / script), '--root', str(root), *args], cwd=root, check=True)
    step('prepare_baseline_raw.py')
    step('prepare_boot_heap.py')
    step('prepare_silo_bridge.py', '--raw', '--image', '--no-prior-honey')
    # The 621 image proves its existing owner objects unchanged against a same-selection OFF carrier.
    sys.path.insert(0, str(tools))
    import prepare_camera_bridge as camera_owner
    import guest_llvm
    if args.legacy_standalone_dir:
        if sha(args.legacy_standalone_dir / 'boot.bin') != camera_owner.LEGACY_STANDALONE_IMAGE_SHA256:
            raise ValueError('--legacy-standalone-dir boot.bin differs from the pinned legacy standalone image')
        silo = root / BASELINE / 'render-bridge-silo-candidate'
        for name in LEGACY_PREMISE_FILES:
            shutil.copyfile(args.legacy_standalone_dir / name, silo / name)
    camera = root / CAMERA
    camera.mkdir(parents=True)
    def run(command, label):
        with (camera / label).open('w') as log:
            guest_llvm.run_guest(command, cwd=root, stdout=log, stderr=subprocess.STDOUT)
    # P04a: the carrier's CPU625 object uses the image's derived ckpack copy-storage selection
    # (prepare_camera_bridge.prepare), so the 621 custody check compares like objects. That selection is
    # CPU625 + Flap Flip and not the BK pipeline, which these two flags select by default: copy storage is OFF.
    camera_owner.compile_backpack621_carrier(root, camera, run, actor_palette=True, pre_background=True,
                                             cpu625=True, npc665=True, ckpack_copy_storage=False)
    step('prepare_render_bridge.py', '--camera', '--raw', '--image', *SELECTION)
    image, receipt = camera / 'boot.bin', json.loads((camera / 'receipt.json').read_text())
    if (sha(image) != IMAGE_SHA256 or image.stat().st_size != IMAGE_BYTES or
            sha(camera / 'render_bridge_layout.h') != LAYOUT_SHA256 or receipt.get('shadow_coefficients') is not True or receipt.get('talon_trot_toggle') is not True or receipt.get('first_person_aim') is not True or receipt.get('flap_flip_landing') is not True):
        raise ValueError('selected player guest image/layout/policy differs')
    record = dict(selection=SELECTION, image_sha256=IMAGE_SHA256, image_bytes=IMAGE_BYTES,
                  layout_sha256=LAYOUT_SHA256, raw_binding_sha256=sha(camera / 'RAW_BINDING.json'),
                  receipt_sha256=sha(camera / 'receipt.json'),
                  baseline_raw=json.loads((root / BASELINE / 'raw-receipt.json').read_text())['outputs'],
                  native_references={name: sha(root / name) for name in (CORE1_OBSERVATION, CORE2_OBSERVATION, IPL3_SHAPE)})
    (camera / 'PLAYER_GUEST.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({k: record[k] for k in ('image_sha256', 'image_bytes', 'layout_sha256')}))


if __name__ == '__main__':
    main()
