#!/bin/sh
# Rebuild the legacy standalone Silo directory that tools/baseline/prepare_camera_bridge.py pins
# (LEGACY_STANDALONE_IMAGE_SHA256) by running commit 61caf07's own recipe on the Linux toolchain.
# A fresh Silo step at the current commit cannot reproduce it: the guest sources changed afterwards.
#
# Needs: Docker, the shared deps/ folder (tools/macos/codegen.sh has fetched it) and baserom.us.z64.
# Output: local/legacy-silo-candidate/, passed to prepare_player_guest.py --legacy-standalone-dir.
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
tree="$root/local/legacy-61caf07"
out="$root/local/legacy-silo-candidate"
pin=$(sed -n "s/^LEGACY_STANDALONE_IMAGE_SHA256='\([0-9a-f]*\)'.*/\1/p" "$root/tools/baseline/prepare_camera_bridge.py")
[ -n "$pin" ] || { echo "cannot read LEGACY_STANDALONE_IMAGE_SHA256" >&2; exit 1; }
[ ! -e "$out" ] || { echo "$out exists; move it aside first" >&2; exit 1; }
[ -f "$root/baserom.us.z64" ] && [ -d "$root/deps" ] || { echo "need baserom.us.z64 and deps/" >&2; exit 1; }

git -C "$root" worktree add --detach "$tree" 61caf07
python3 "$root/tools/macos/port_old_tree.py" "$tree"

docker build --platform linux/amd64 -t tooie-codegen:ubuntu24.04 -f "$root/tools/macos/Dockerfile.codegen" "$root/tools/macos"
run() {
    docker run --rm --platform linux/amd64 -v "$tree:/work" -v "$root/deps:/work/deps" \
        -v "$root/baserom.us.z64:/work/baserom.us.z64:ro" -w /work tooie-codegen:ubuntu24.04 "$@"
}
run python3 tools/generate_local.py --rom baserom.us.z64 --jobs "$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
# The old recipe stops in its camera step (it still hard-codes the Windows toolchain there); the Silo
# directory this needs is written before that.
run .venv-codegen/bin/python tools/baseline/prepare_player_guest.py --rom baserom.us.z64 || true

silo="$tree/build/windows-dev/baseline/render-bridge-silo-candidate"
actual=$(shasum -a 256 "$silo/boot.bin" | cut -d' ' -f1)
if [ "$actual" != "$pin" ]; then
    echo "legacy standalone boot.bin is $actual, expected $pin" >&2
    exit 1
fi
cp -R "$silo" "$out"
git -C "$root" worktree remove --force "$tree"
echo "legacy standalone directory ready: $out"
