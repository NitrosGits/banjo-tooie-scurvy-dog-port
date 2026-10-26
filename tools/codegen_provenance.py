"""Fail-closed local codegen provenance. Receipts are emitted only by generators."""
from pathlib import Path
import argparse
import hashlib
import json
import re

import guest_llvm

RECEIPT = 'codegen-receipt.json'
REQUIRED_INPUTS = tuple('tools/' + name + '.py' for name in (
    'prepare_codegen', 'compile_current_codegen', 'codegen_provenance', 'codegen_io',
    'instrument_continuous', 'instrument_audio_pacing', 'prepare_core1_metadata',
    'prepare_main_metadata', 'prepare_core2_reference', 'prepare_overlay_validation',
    'prepare_boot_reference', 'prepare_native_fixture', 'prepare_ipl3_shape', 'prepare_heap_patch',
    'render_wrapper_contract', 'render_wrapper_validator', 'verify_render_wrapper_image',
    'lift_persistent_continuations')) + (
    'config/startup_coverage.json', 'config/boundary_adjustments.json',
    'config/runtime_exclusions.json', 'config/tooie.us.toml',
    'config/selected.syms.toml', 'config/overlay-ids.txt', 'config/symbol_renames.json',
    'patches/game/heap.c', 'patches/game/initialize.c', 'patches/game/heap.ld',
    'patches/render_wrapper/guest/production/graphics_buffers.c',
    'patches/render_wrapper/guest/production/family.c',
    'patches/render_wrapper/guest/production/model_nodes.c',
    'patches/render_wrapper/guest/production/player_release.c',
    'patches/game/native_aspect_projection.c', 'patches/game/widescreen_settings_abi.h',
    'src/boot_hooks.h', 'tools/guest_llvm.py',
    guest_llvm.TOOLS['clang'], guest_llvm.TOOLS['lld'])


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def generated_directory(root, directory=None):
    root = Path(root).resolve()
    result = (Path(directory) if directory is not None else root / 'generated').resolve()
    if result != root / 'generated':
        allowed = any(result.is_relative_to(root / area) for area in ('.codegen', 'local'))
        if not allowed or result.name != 'generated':
            raise ValueError('Temporary CPU output must be a generated directory under .codegen or local')
    return result



def configuration_directory(root, generated_dir=None):
    root = Path(root).resolve()
    generated = generated_directory(root, generated_dir)
    intended = root / 'config' if generated == root / 'generated' else generated.parent / 'config'
    resolved = intended.resolve()
    if resolved != intended:
        raise ValueError('Prepared configuration root must not alias or escape its intended sibling')
    return resolved


def outputs(root, generated_dir=None):
    directory = generated_directory(root, generated_dir)
    return {p.relative_to(directory).as_posix(): sha(p)
            for p in sorted(directory.rglob('*'))
            if p.is_file() and p.name != RECEIPT
            # RSP and dependency overlays have separate generators/receipts;
            # CPU regeneration must not bless outputs it did not reproduce.
            and (p.parent == directory or p.relative_to(directory).parts[0] in {'test-fixtures', 'heap-patch-products'})}


def write_receipt(root, inputs, evidence, generated_dir=None, required_inputs=REQUIRED_INPUTS):
    root = Path(root).resolve()
    # A required input reached through a junction (shared pinned deps checkout)
    # keeps its logical name; every other outside input stays absolute.
    aliases = {}
    for name in required_inputs:
        physical = (root / name).resolve()
        if not physical.is_relative_to(root) and aliases.setdefault(physical, name) != name:
            raise ValueError(f'Ambiguous required input alias: {physical}')
    manifest = {}
    for path in inputs:
        path = Path(path).resolve()
        digest = sha(path)
        if path in aliases:
            name = aliases[path]
            if sha(root / name) != digest:
                raise ValueError(f'Aliased required input differs from its logical path: {name}')
        else:
            name = path.relative_to(root).as_posix() if path.is_relative_to(root) else str(path)
        if manifest.setdefault(name, digest) != digest:
            raise ValueError(f'Conflicting codegen receipt input: {name}')
    directory = generated_directory(root, generated_dir)
    receipt = dict(schema=1, inputs=manifest, outputs=outputs(root, directory), evidence=evidence)
    destination = directory / RECEIPT
    temporary = destination.with_suffix('.tmp')
    temporary.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    temporary.replace(destination)
    return receipt


def validate(root, required_inputs=REQUIRED_INPUTS, replay=False, generated_dir=None):
    root = Path(root).resolve()
    directory = generated_directory(root, generated_dir)
    path = directory / RECEIPT
    try:
        receipt = json.loads(path.read_text())
    except (OSError, ValueError) as error:
        raise ValueError('Missing/invalid codegen receipt; run full prepare_codegen.py') from error
    if receipt.get('schema') != 1 or not isinstance(receipt.get('inputs'), dict):
        raise ValueError('Unsupported codegen receipt')
    missing = set(required_inputs) - receipt['inputs'].keys()
    if missing:
        raise ValueError(f'Codegen receipt missing required input: {sorted(missing)}')
    # Replay regenerates these scripts' outputs, but cannot re-attest changed
    # preparation tools, prepared config, generator binary or metadata outputs.
    replay_inputs = {'tools/instrument_continuous.py', 'tools/instrument_audio_pacing.py',
                     'tools/compile_current_codegen.py'} if replay else set()
    for name, expected in receipt['inputs'].items():
        if name in replay_inputs:
            continue
        source = root / name
        if not source.is_file() or sha(source) != expected:
            raise ValueError(f'Codegen input changed: {name}; regenerate before building')
    actual = outputs(root, directory)
    expected = receipt.get('outputs', {})
    if 'render_layout.h' not in expected:
        raise ValueError('Codegen receipt lacks authenticated rendering layout')
    if replay:
        def inherited(name):
            if name.startswith('heap-patch-products/'):
                return True
            return not (name.endswith('.c') or name in {
                'funcs.h', 'lookup.cpp', 'recomp_overlays.inl',
                'test-fixtures/audio_pacing_functions.inc'})
        actual = {k: v for k, v in actual.items() if inherited(k)}
        expected = {k: v for k, v in expected.items() if inherited(k)}
    if not expected or actual != expected:
        raise ValueError('Codegen output set/content differs from receipt; regenerate before building')
    if not replay:
        from verify_render_wrapper_image import verify
        verify(directory, receipt=receipt)
    return receipt


def validate_sdl(path, pinned, observer=''):
    if observer and not re.fullmatch('[0-9a-fA-F]{64}', observer):
        raise ValueError('SDL observer override must be exactly 64 hexadecimal characters')
    actual = sha(path)
    expected = observer.lower() if observer else pinned.lower()
    if actual != expected:
        raise ValueError(f'SDL DLL hash mismatch: expected {expected}, found {actual}')
    return actual


def validate_build(root, executable):
    validate(root)
    executable = Path(executable)
    try:
        receipt = json.loads(executable.with_name('codegen-build-receipt.json').read_text())
    except (OSError, ValueError) as error:
        raise ValueError('Missing codegen build receipt; rebuild executable') from error
    expected = {'schema': 1, 'executable_sha256': sha(executable),
                'codegen_receipt_sha256': sha(Path(root) / 'generated' / RECEIPT)}
    if receipt != expected:
        raise ValueError('Executable/codegen build receipt mismatch; rebuild executable')
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--attest-build', type=Path)
    parser.add_argument('--generated-dir', type=Path)
    args = parser.parse_args()
    validate(args.root, generated_dir=args.generated_dir)
    if args.attest_build:
        receipt = {'schema': 1, 'executable_sha256': sha(args.attest_build),
                   'codegen_receipt_sha256': sha(generated_directory(args.root, args.generated_dir) / RECEIPT)}
        destination = args.attest_build.with_name('codegen-build-receipt.json')
        destination.write_text(json.dumps(receipt, indent=2) + '\n')
    print('Codegen provenance verified')


if __name__ == '__main__':
    main()
