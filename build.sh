#!/usr/bin/env bash
# Builds dist/hyprland-opt_*.deb in a clean Ubuntu 26.04 container.
set -euo pipefail
cd "$(dirname "$0")"

command -v podman >/dev/null || { echo "podman is required: sudo apt install podman" >&2; exit 1; }

podman build -t omarchy-ubuntu-builder -f build/Containerfile build
mkdir -p dist .cache
podman run --rm \
  -v "$PWD:/src:ro" \
  -v "$PWD/.cache:/work" \
  -v "$PWD/dist:/out" \
  omarchy-ubuntu-builder bash /src/build/build-inside.sh

ls -lh dist/
