#!/bin/sh
# Assemble an ad-hoc signed BanjoTooieScurvyDogPort.app from a gated macOS build (docs/MACOS.md step 4).
#
# The player links SDL2 (Homebrew's sdl2-compat, which loads SDL3 at runtime) and libcrypto, and loads the Vulkan
# loader and MoltenVK by name at runtime. All five go into Contents/Frameworks with @rpath install names; the
# loader finds MoltenVK through an ICD manifest in Contents/Resources/vulkan/icd.d.
#
# Usage: tools/macos/package_app.sh [build-dir] [output-dir]
# The app contains compiled code derived from your ROM (not the ROM). Do not publish it.
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
build="${1:-$root/build/windows-dev}"
out="${2:-$root/dist/macos}"
name=BanjoTooieScurvyDogPort
exe="$build/baseline/player-bin/$name"
receipt="$build/baseline/raw-qualification/native.json"

[ -f "$exe" ] || { echo "no player at $exe; build it first (docs/MACOS.md)" >&2; exit 1; }
# The native receipt is written by the gated link; a newer executable means it was not gated.
[ -f "$receipt" ] && [ ! "$exe" -nt "$receipt" ] || { echo "the player is newer than its gate receipt; rebuild with the gates" >&2; exit 1; }

app="$out/$name.app"
[ ! -e "$app" ] || { echo "$app exists; move it aside first" >&2; exit 1; }
mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks" "$app/Contents/Resources/vulkan/icd.d" "$app/Contents/Resources/licenses"
cp "$exe" "$app/Contents/MacOS/$name"

prefix() { brew --prefix "$1"; }
sdl2=$(prefix sdl2-compat)/lib/libSDL2-2.0.0.dylib
sdl3=$(prefix sdl3)/lib/libSDL3.0.dylib
crypto=$(prefix openssl@3)/lib/libcrypto.3.dylib
vulkan=$(prefix vulkan-loader)/lib/libvulkan.1.dylib
moltenvk=$(prefix molten-vk)/lib/libMoltenVK.dylib
fw="$app/Contents/Frameworks"
# cp -L: Homebrew's opt/ paths are symlinks into the Cellar.
cp -L "$sdl2" "$fw/libSDL2-2.0.0.dylib"
cp -L "$sdl3" "$fw/libSDL3.dylib"      # sdl2-compat looks for exactly this name next to itself
cp -L "$crypto" "$fw/libcrypto.3.dylib"
cp -L "$vulkan" "$fw/libvulkan.1.dylib"
ln -s libvulkan.1.dylib "$fw/libvulkan.dylib"
cp -L "$moltenvk" "$fw/libMoltenVK.dylib"
chmod u+w "$fw"/*.dylib

for lib in libSDL2-2.0.0 libSDL3 libcrypto.3 libvulkan.1 libMoltenVK; do
    install_name_tool -id "@rpath/$lib.dylib" "$fw/$lib.dylib"
done
# Point the player at the bundled copies and drop Homebrew from its search path.
install_name_tool -change "$(otool -L "$exe" | awk '/libSDL2-2.0.0.dylib/{print $1}')" @rpath/libSDL2-2.0.0.dylib "$app/Contents/MacOS/$name"
install_name_tool -change "$(otool -L "$exe" | awk '/libcrypto.3.dylib/{print $1}')" @rpath/libcrypto.3.dylib "$app/Contents/MacOS/$name"
for rpath in $(otool -l "$exe" | awk '/LC_RPATH/{getline; getline; print $2}'); do
    install_name_tool -delete_rpath "$rpath" "$app/Contents/MacOS/$name"
done
install_name_tool -add_rpath @executable_path/../Frameworks "$app/Contents/MacOS/$name"
# Any other Homebrew reference means the app would not run on a clean machine.
if otool -L "$app/Contents/MacOS/$name" "$fw"/*.dylib | grep -q "/opt/homebrew"; then
    echo "a Homebrew path remains in the bundle:" >&2
    otool -L "$app/Contents/MacOS/$name" "$fw"/*.dylib | grep "/opt/homebrew" >&2
    exit 1
fi

cat > "$app/Contents/Resources/vulkan/icd.d/MoltenVK_icd.json" <<'JSON'
{
    "file_format_version" : "1.0.0",
    "ICD": {
        "library_path": "../../../Frameworks/libMoltenVK.dylib",
        "api_version" : "1.4.0",
        "is_portability_driver" : true
    }
}
JSON

version=$(python3 - "$root" <<'PY'
import json, sys
print(json.load(open(sys.argv[1] + '/release/player-windows-files.json'))['version'])
PY
)
python3 - "$app/Contents/Info.plist" "$name" "$version" <<'PY'
import plistlib, sys
path, name, version = sys.argv[1:]
plistlib.dump({
    'CFBundleName': 'Banjo-Tooie: Scurvy Dog Port',
    'CFBundleDisplayName': 'Banjo-Tooie: Scurvy Dog Port',
    'CFBundleIdentifier': 'io.github.some-scurvy-dog.banjo-tooie-scurvy-dog-port',
    'CFBundleExecutable': name,
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': version.split('-')[0],
    'CFBundleVersion': version,
    'LSMinimumSystemVersion': '11.0',
    'NSHighResolutionCapable': True,
    'LSApplicationCategoryType': 'public.app-category.games',
}, open(path, 'wb'))
PY

# Licenses for the bundled libraries and the project's own notices.
cp "$root/LICENSE" "$root/THIRD_PARTY_NOTICES.md" "$app/Contents/Resources/"
cp -R "$root/third_party/notices" "$app/Contents/Resources/notices"
for formula in sdl2-compat sdl3 openssl@3 vulkan-loader molten-vk; do
    dir=$(brew --prefix "$formula")
    for file in LICENSE LICENSE.txt LICENSE.md COPYING; do
        [ -f "$dir/$file" ] && cp "$dir/$file" "$app/Contents/Resources/licenses/$formula-$file" || true
    done
done

# Ad-hoc signature (libraries first). It satisfies Apple silicon's rule that code is signed; it is not a
# Developer ID signature, so Gatekeeper still asks before opening a copy that was downloaded.
for lib in "$fw"/*.dylib; do [ -L "$lib" ] || codesign --force --sign - "$lib"; done
codesign --force --sign - "$app/Contents/MacOS/$name"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
echo "built $app"
