# Banjo-Tooie: Scurvy Dog Port

Banjo-Tooie: Scurvy Dog Port is an unofficial PC port of Banjo-Tooie. It
statically recompiles the original game code with
[N64Recomp](https://github.com/N64Recomp/N64Recomp) and renders it with
[RT64](https://github.com/rt64/rt64). It is an alpha. The game is not
included: you need your own NTSC-U 1.0 ROM.

This project is a work in progress. The design is not final, and improvements are continually evaluated.

The current release is for Windows x64.

**This project is not affiliated with BanjoRecomp.**

## AI disclosure

AI tools generated substantial portions of this project's code and assisted
with engineering and review. The project owner directs development, tests the
game and checks its behavior. Some upstream projects do not accept AI-generated
contributions. Respect their policies when you contribute to them.

## Play

Download the latest ZIP from
[Releases](https://github.com/some-scurvy-dog/banjo-tooie-scurvy-dog-port/releases).
Extract all of it into one folder and run `BanjoTooieScurvyDogPort.exe`. On
first launch, choose your ROM when asked.

- [Player guide](docs/PLAYER_GUIDE.md): supported ROM, saves, bringing over an
  Alpha 3 save, controls, settings and troubleshooting.
- [Release notes](docs/RELEASE_NOTES.md): changes and known issues.

## What changed in Alpha 4

Feedback on Alpha 1 to 3 exposed three design problems:

- The port rewrote code that N64Recomp had generated, instead of patching
  through N64Recomp's patch system.
- Native C++ code quietly took over game logic and game memory that the
  original game should own.
- Game-specific policy was built into the runtime and the renderer.

Alpha 4 changes direction:

- Game changes are written as plain C patches for the original game's ABI.
  They are compiled to MIPS and recompiled in N64Recomp's patch mode.
- Start-up, overlays, input, audio and saves use the runtime's intended
  mechanisms.
- Smooth frame interpolation is tagged with RT64's public display-list
  commands.

This is progress, not a finished migration. Native hooks, carried upstream
patches, raw memory offsets and the custom menu remain. Current source supports
[RT64 texture packs](docs/PLAYER_GUIDE.md); code mods and ROM patches are not
supported. [Architecture](docs/ARCHITECTURE.md) lists what is still open.

## Renderer improvements since Alpha 4

Alpha 4 rebuilt the port around the original game's recompiled code. The work
since then has focused on keeping rendering consistent between game updates,
including model parts that deform, change branches or draw separately.

The selected character pipeline tracks which object, model part and view a draw
belongs to across frames. CPU-deformed animation supplies floating-point vertex
positions and motion alongside the original game output. Banjo and Kazooie have
separate histories when split, and attachments use their owner's identity rather
than whichever character happened to draw last.

Camera and model transforms have separate responsibilities. Geometry branches
keep consistent labels, and an abrupt change can skip interpolation for one
update without losing the object's identity. Submitted display-list data is
protected until the renderer has parsed it. These shared rules address causes
that can affect many characters, rather than relying only on individual enemy
fixes. They do not change the game's simulation rate.

Player testing has confirmed improvements to ordinary models, split-player
animation and camera movement. Backpack and slope shadows remain known issues.
Alpha 4.4 also includes menu and transition-edge corrections that await broader
player testing. This is not a claim that every scene or effect is correct. See the
[rendering architecture](docs/RENDERING.md) for the current design and limits.

## Build and contribute

- [Windows build guide](docs/WINDOWS.md): the maintained way to build and
  package the port from source.
- [macOS build guide](docs/MACOS.md): an experimental Apple Silicon build.
- [Contributing](CONTRIBUTING.md): reporting problems and proposing changes.
- [Architecture](docs/ARCHITECTURE.md): what is built, who owns each
  behavior, and the rules for changes.

`python tools/check_repository.py` runs the ROM-free source checks.

### Agents: start here

If you are an AI agent or automated tool working in this repository:

1. Read [CONTRIBUTING.md](CONTRIBUTING.md). Its rules on checks, private
   files and AI disclosure apply to you.
2. Read [Rules for changes](docs/ARCHITECTURE.md#rules-for-changes) before
   you edit code.
3. Use
   [How to find what is selected](docs/ARCHITECTURE.md#how-to-find-what-is-selected)
   to confirm that a file is in the player before you change it.

## Report a problem

See [how to report a problem](CONTRIBUTING.md#report-a-problem).

## Credits and license

The port uses N64Recomp, N64ModernRuntime, RT64, Dear ImGui, SDL2 and other
projects listed in [third-party notices](THIRD_PARTY_NOTICES.md). The
[Banjo-Tooie decompilation](https://github.com/Mr-Wiseguy/banjo-tooie) provides
symbols and reverse-engineering groundwork. Credit for that work stays with
their contributors.

Project material that its authors can license is under
[GPL-3.0-only](LICENSE). Dependencies and game-derived material keep their own
terms. Banjo-Tooie belongs to its rights holders.
