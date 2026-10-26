#!/bin/sh
# ROM-free: build and run the POSIX player startup test on the host (Linux or macOS).
# Needs the pinned rt64 checkout (for nfd), SDL2 and CMake. Used by .github/workflows/platform-checks.yml.
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
out="${1:-$root/build/ci-startup}"
nfd_src="$root/deps/rt64/src/contrib/nativefiledialog-extended"
[ -d "$nfd_src" ] || { echo "run: python3 tools/bootstrap_dependencies.py --only rt64" >&2; exit 1; }

mkdir -p "$out/generated"
cat > "$out/generated/player_version.hpp" <<'HPP'
#pragma once
namespace baseline::player::build {
inline constexpr char product[] = "Banjo-Tooie: Scurvy Dog Port";
inline constexpr char version[] = "0.0.0-ci";
}
HPP

nfd_options=""
case "$(uname -s)" in Linux) nfd_options="-DNFD_PORTAL=ON" ;; esac
cmake -S "$nfd_src" -B "$out/nfd" -DCMAKE_BUILD_TYPE=Release -DNFD_BUILD_TESTS=OFF $nfd_options >/dev/null
cmake --build "$out/nfd" --parallel >/dev/null
nfd_lib=$(find "$out/nfd" -name 'libnfd.a' | head -1)

extra=""
case "$(uname -s)" in
    Darwin) extra="-framework AppKit -framework UniformTypeIdentifiers" ;;
    Linux) extra="$(pkg-config --libs dbus-1)" ;;
esac
# shellcheck disable=SC2046
${CXX:-c++} -std=c++20 -O1 -Wall \
    -I "$root/tools/baseline" -I "$out/generated" -I "$nfd_src/src/include" $(sdl2-config --cflags) \
    "$root/tests/baseline_player_startup_posix_test.cpp" "$root/tools/baseline/player_startup_posix.cpp" \
    "$nfd_lib" $(sdl2-config --libs) $extra -o "$out/startup_test"
"$out/startup_test"
