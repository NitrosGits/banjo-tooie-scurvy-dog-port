#!/bin/sh
# Run a command in the Linux x86_64 codegen container with the checkout at /work.
# Usage: tools/macos/codegen.sh [command...]   (default: an interactive shell)
#   tools/macos/codegen.sh python3 tools/generate_local.py --rom baserom.us.z64
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
image=tooie-codegen:ubuntu24.04
docker build --platform linux/amd64 -t "$image" -f "$root/tools/macos/Dockerfile.codegen" "$root/tools/macos"
tty=
if [ -t 0 ] && [ -t 1 ]; then tty=-it; fi
[ $# -gt 0 ] || set -- bash
exec docker run --rm $tty --platform linux/amd64 -v "$root:/work" -w /work "$image" "$@"
