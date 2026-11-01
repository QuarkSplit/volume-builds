#!/bin/bash
set -euo pipefail
image="$(find package -name '*.dmg' -print -quit)"
test -n "$image"
mkdir "$RUNNER_TEMP/mounted"
hdiutil attach "$image" -readonly -nobrowse -mountpoint "$RUNNER_TEMP/mounted"
app="$RUNNER_TEMP/mounted/Volume.app"
codesign --verify --deep --strict "$app"
mkdir "$RUNNER_TEMP/install"
ditto "$app" "$RUNNER_TEMP/install/Volume.app"
hdiutil detach "$RUNNER_TEMP/mounted"
app="$RUNNER_TEMP/install/Volume.app"
/usr/libexec/PlistBuddy -c 'Set LSMinimumSystemVersion 15.4' "$app/Contents/Info.plist"
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
resources="$app/Contents/Resources"
tools="$resources/runtime-bin"
runtime="$resources/runtime"
"$tools/uv" --version
"$tools/llama-vulkan/llama-server" --version
"$tools/ffmpeg/bin/ffmpeg" -buildconf
"$tools/ffmpeg/bin/ffmpeg" -f lavfi -i 'sine=frequency=440:duration=1' -c:a libopus "$RUNNER_TEMP/probe.ogg"
test -s "$RUNNER_TEMP/probe.ogg"
swiftc -framework Cocoa -framework WebKit verify-audio.swift -o "$RUNNER_TEMP/verify-audio"
"$RUNNER_TEMP/verify-audio" "$RUNNER_TEMP/probe.ogg"
export UV_PYTHON_INSTALL_DIR="$RUNNER_TEMP/python"
export UV_CACHE_DIR="$RUNNER_TEMP/uv-cache"
"$tools/uv" python install 3.12 --no-bin --no-registry
"$tools/uv" venv "$RUNNER_TEMP/core" --python 3.12 --managed-python
py="$RUNNER_TEMP/core/bin/python"
"$tools/uv" pip install --python "$py" -r "$runtime/core/pyproject.toml"
export PYTHONPATH="$runtime/core/src"
"$py" -c 'import mathcat; text=mathcat.MathCAT().speak_latex(r"\frac{a+b}{c}"); assert "fraction" in text; print("Packaged MathCAT passed")'
"$py" -m vivavoce --help
executable="$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$app/Contents/Info.plist")"
export VIVAVOCE_PROFILE="$RUNNER_TEMP/fresh-profile"
"$app/Contents/MacOS/$executable" > "$RUNNER_TEMP/app.log" 2>&1 &
app_pid=$!
trap 'kill "$app_pid" 2>/dev/null || true' EXIT
sleep 15
kill -0 "$app_pid"
if grep -E 'panicked at|fatal error|dyld.*not loaded|React error #' "$RUNNER_TEMP/app.log"; then exit 1; fi
cat "$RUNNER_TEMP/app.log"
echo 'Packaged native tools, audio encoding, clean Python environment, maths speech and application startup passed.'
kill "$app_pid"
wait "$app_pid" || true
mkdir -p results
ln -s /Applications "$RUNNER_TEMP/install/Applications"
name="$(basename "$image")"
hdiutil create -volname Volume -srcfolder "$RUNNER_TEMP/install" -format UDZO "results/$name"
hdiutil verify "results/$name"
shasum -a 256 "results/$name" > results/SHA256SUMS.txt
cp package/parity.json results/
