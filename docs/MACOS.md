# Building Banjo-Tooie: Scurvy Dog Port on macOS (Apple Silicon)

This is an experimental macOS arm64 build of the player. It is not a supported
release target: the project ships for Windows x64 only. Follow
[WINDOWS.md](WINDOWS.md) for what each step does; this guide covers where macOS differs.

Status: built and run on macOS 27 (SDK 27) with Xcode's Apple clang 21 on an Apple M3 Pro.
The raw archive, native hook and embedded guest gates pass, and the game starts, loads its
menu and draws through RT64's Metal backend. See [Known gaps](#known-gaps) before relying on it.

## How the build fits together

1. **Docker (linux/amd64):** generate ROM-derived source and prepare the guest image. The pinned IDO,
   GCC 2.7.2 and binutils tools, and the MIPS guest compiler, are Linux x86_64 programs.
2. **macOS:** configure, compile the raw archive, qualify it once, then build the gated player.

Generated output stays in the ignored `deps/`, `generated/`, `build/` and `local/` folders.

## Requirements

- macOS on Apple Silicon, Xcode (for Apple clang, the Metal compiler and `llvm-objdump`), and Docker Desktop.
- Homebrew: `cmake`, `ninja`, `sdl2` (or `sdl2-compat`), `openssl@3`, `python`.
- Your own NTSC-U 1.0 ROM as `baserom.us.z64` in the checkout root (SHA-256 in [WINDOWS.md](WINDOWS.md#2-supply-and-check-your-rom)).

## 1. Code generation and guest preparation

`tools/macos/codegen.sh` builds an Ubuntu 24.04 `linux/amd64` image (emulated on Apple Silicon) and
runs a command in it with the checkout mounted. It reproduces the pinned N64Recomp hash exactly.

```bash
tools/macos/codegen.sh python3 tools/generate_local.py --rom baserom.us.z64 --jobs 12
```

Guest preparation needs the preserved legacy standalone Silo directory that
`tools/baseline/prepare_camera_bridge.py` pins (see [Known gaps](#known-gaps)). Rebuild it once from
commit 61caf07, then prepare the guest:

```bash
tools/macos/build_legacy_standalone.sh
tools/macos/codegen.sh .venv-codegen/bin/python tools/baseline/prepare_player_guest.py \
  --rom baserom.us.z64 --legacy-standalone-dir local/legacy-silo-candidate
```

The script prints the selected guest image and layout hashes; they must match the pins in
`prepare_player_guest.py`. Preparation refuses to run if `build/windows-dev` already exists.

## 2. Configure and compile the raw archive

The `macos-player` preset uses `build/windows-dev` because the preparation scripts write there.
Its `TOOIE_BASELINE_MACHO_TOOLS_DIR` must be the absolute directory of the `llvm-objdump` the gates
use (the default is Xcode's toolchain `usr/bin`; edit the preset if Xcode is elsewhere).

```bash
cmake --preset macos-player
mkdir -p build/windows-dev/raw-qualification-input
cmake --build build/windows-dev --target BaselineRecompiledFuncs librecomp ultramodern rt64 \
  > build/windows-dev/raw-qualification-input/compile.log 2>&1
```

The log must come from the build that compiled all 416 raw sources.

## 3. Qualify the raw archive once

```bash
SHA=$(python3 tools/macos/collect_raw_evidence.py)
python3 tools/baseline/verify_baseline_binding.py qualify --format macho \
  --build build/windows-dev \
  --raw build/windows-dev/baseline/render-bridge-camera-candidate/composition-v2/raw \
  --archive build/windows-dev/libBaselineRecompiledFuncs.a \
  --tools "$(sed -n 's/^TOOIE_BASELINE_MACHO_TOOLS_DIR:[A-Z]*=//p' build/windows-dev/CMakeCache.txt)" \
  --snapshot build/windows-dev/baseline/raw-qualification/qualified.json \
  --expected-count 416 \
  --evidence build/windows-dev/raw-qualification-input/evidence.json \
  --compile-log build/windows-dev/raw-qualification-input/compile.log \
  --accepted-archive-sha "$SHA"
```

The Mach-O gates (`tools/baseline/macho_binding.py`) mirror the ELF ones: BSD `ar` members, ld64 `-map`
ownership, `llvm-objdump` relocations and direct `bl`/`b` branches. The qualification records the
objdump's path and hash, so `--tools` must be the same directory the preset names (the command above reads it
from the configured cache) and a new Xcode needs a fresh qualification.

## 4. Build and run

```bash
cmake --build --preset macos-player
build/windows-dev/baseline/player-bin/BanjoTooieScurvyDogPort --profile-dir build/test-profile --rom baserom.us.z64
```

The build runs the archive gate, then checks every linked hook call and that the embedded guest image
equals the selected one. `BaselinePlayerStartupTest` is an optional target.

## 5. Package an app bundle (optional)

```bash
tools/macos/package_app.sh        # writes dist/macos/BanjoTooieScurvyDogPort.app
```

The script refuses a player newer than its gate receipt. It copies SDL2 (the sdl2-compat shim), SDL3, libcrypto,
the Vulkan loader and MoltenVK into `Contents/Frameworks` with `@rpath` install names, adds the MoltenVK driver
manifest under `Contents/Resources/vulkan/icd.d`, writes `Info.plist`, copies the licenses and notices, and signs
everything ad hoc. Inside a bundle the player points the Vulkan loader at that manifest alone (`VK_DRIVER_FILES`,
unless you set it), so a Homebrew MoltenVK is never loaded as a second driver. Checked on this Mac: run with an empty
environment, the app maps no Homebrew library and draws the title screen.

The ad-hoc signature satisfies Apple silicon's signed-code rule but is not a Developer ID signature or a notarisation:
a copy that was downloaded or AirDropped will be blocked by Gatekeeper until it is opened with right-click, Open. The
app holds code compiled from your ROM; do not publish it. There is no icon yet (the repository has no PNG artwork).

## Known gaps

- **Legacy standalone premise:** `prepare_camera_bridge.py` pins a Silo `boot.bin` (and reads its
  `data.syms.toml`) that a fresh checkout cannot regenerate, because the guest sources changed in
  Alpha 4.4. `build_legacy_standalone.sh` rebuilds it from commit 61caf07, which reproduces the pinned hash
  on the Linux toolchain. The maintainers should decide whether to keep that premise, re-pin it, or drop it.
- **Stale legacy checks:** the historical bone/helper measurements in `prepare_silo_bridge.py` run only
  for the standalone case, and the carrier's `ckpack_copy_storage` now follows the image's derived value.
- **Renderer:** RT64 runs on Vulkan through MoltenVK, not native Metal: the in-game menu draws through
  RT64's ImGui inspector, which has only Vulkan and D3D12 backends. MoltenVK asks the main thread for the
  screen refresh rate on every frame, so on macOS `main()` runs the runtime on a helper thread and the main thread
  pumps SDL events and serves its run loop (the runtime thread reads events with `SDL_PeepEvents`). Without that,
  shutdown deadlocked about half the time. Verified by repeated 20 and 60 second runs; keyboard, controller and
  window-close behaviour have not been tested by hand.
- **Profile folder:** macOS has no path for a held directory descriptor, so the profile is reached by the
  path it was opened under. If the folder is moved and another is put at the same path while the game runs,
  runtime writes through `storage()` land in the replacement; Linux and Windows guarantee they cannot.
- **Untested by hand:** that a picture appears, keyboard and controller input, sound, closing the window, and
  launching with no arguments. Bounded runs (`--seconds`) start, run the game and exit cleanly.
- **CI:** `.github/workflows/platform-checks.yml` runs the repository checks and the player startup test
  (`tools/ci/startup_test.sh`) on Linux and macOS. It cannot build the player: that needs your ROM.
  `.github/workflows/full-build.yml` (manual) runs this whole guide from a `ROM_URL` secret: code generation on
  Linux, then the gated macOS build, handing the ROM-derived files over as an encrypted artifact (`ARTIFACT_KEY`).
- **Distribution:** the app is ad-hoc signed only (no Developer ID, notarisation or icon), and the bundled libraries come from Homebrew's builds on the packaging machine.
- **Compiler hash:** `.comment` build paths differ between the Linux and Windows LLVM builds, so Linux guest
  objects are normalized to the Windows identity (`tools/guest_llvm.py`); this is what keeps the object pins valid.
