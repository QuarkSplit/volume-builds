#!/bin/bash
set -euo pipefail
image="$(find package -name '*.dmg' -print -quit)"
mkdir "$RUNNER_TEMP/mounted" "$RUNNER_TEMP/install"
hdiutil attach "$image" -readonly -nobrowse -mountpoint "$RUNNER_TEMP/mounted"
ditto "$RUNNER_TEMP/mounted/Volume.app" "$RUNNER_TEMP/install/Volume.app"
hdiutil detach "$RUNNER_TEMP/mounted"
app="$RUNNER_TEMP/install/Volume.app"
executable="$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$app/Contents/Info.plist")"
export VIVAVOCE_PROFILE="$RUNNER_TEMP/startup-profile"
"$app/Contents/MacOS/$executable" > "$RUNNER_TEMP/app.log" 2>&1 &
app_pid=$!
trap 'kill "$app_pid" 2>/dev/null || true' EXIT
sleep 60
kill -0 "$app_pid"
cat "$RUNNER_TEMP/app.log"
find "$VIVAVOCE_PROFILE" -type f -name '*.log' -print -exec tail -n 100 {} \;
python3 - "$VIVAVOCE_PROFILE" <<'PY'
import json,sys
from pathlib import Path
root=Path(sys.argv[1])
for p in root.glob('*.json'):
    try:
        j=json.loads(p.read_text());print(p.name,'keys',list(j),'library entries',len(j.get('library',[])))
    except Exception as e:print(p.name,str(e))
print('Book folders',len(list(root.glob('Books/*.p2a'))))
PY
mkdir -p results
screencapture -x results/mac-startup-60s.png || true
