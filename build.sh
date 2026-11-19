#!/usr/bin/env bash
# Builds dist/hyprland-opt_*.deb in a clean Ubuntu 26.04 container.
set -euo pipefail
cd "$(dirname "$0")"

command -v podman >/dev/null || { echo "podman is required: sudo apt install podman" >&2; exit 1; }

# What build/ held, uncommitted edits included. install.sh only uses a local .deb whose stamp matches the
# build/ it's run with, so an older build of the same version can't stand in for a newer one. Same as
# build_hash in install.sh.
build_hash() { find build -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1; }

. build/versions.env
deb=dist/hyprland-opt_${HYPRLAND_TAG#v}-${PKG_REVISION}~ubuntu26.04_amd64.deb
hash=$(build_hash)
rm -f "$deb.build"

podman build -t omarchy-ubuntu-builder -f build/Containerfile build
mkdir -p dist .cache
podman run --rm \
  -v "$PWD:/src:ro" \
  -v "$PWD/.cache:/work" \
  -v "$PWD/dist:/out" \
  omarchy-ubuntu-builder bash /src/build/build-inside.sh

# The container reads build/ as it goes; a change during the build leaves the .deb unstamped.
if [[ $(build_hash) == "$hash" ]]; then
  echo "$hash" >"$deb.build"
else
  echo "build/ changed during the build: $deb is left unstamped, so install.sh won't pick it. Build again." >&2
fi

ls -lh dist/
