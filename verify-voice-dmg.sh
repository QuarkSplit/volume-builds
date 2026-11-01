#!/bin/bash
set -euo pipefail
image="$(find package -name '*.dmg' -print -quit)"
test -n "$image"
mkdir "$RUNNER_TEMP/mounted"
hdiutil attach "$image" -readonly -nobrowse -mountpoint "$RUNNER_TEMP/mounted"
trap 'hdiutil detach "$RUNNER_TEMP/mounted" || true' EXIT
resources="$RUNNER_TEMP/mounted/Volume.app/Contents/Resources"
export UV_PYTHON_INSTALL_DIR="$RUNNER_TEMP/python"
export UV_CACHE_DIR="$RUNNER_TEMP/uv-cache"
"$resources/runtime-bin/uv" python install 3.12 --no-bin --no-registry
python3 verify-voice.py "$resources"
