#!/bin/zsh
set -euo pipefail
ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
PROFILE_SRC="$HOME/Library/Application Support/Google/Chrome"
TMP_PROFILE="$(mktemp -d /tmp/youtube-upload-profile2.XXXXXX)"
PORT=9223
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LOG="$ROOT/automation/upload_chrome_batch_005_009.log"
PROFILE_DIR="Profile 2"
cleanup() {
  if [[ -n "${CHROME_PID:-}" ]]; then
    kill "$CHROME_PID" >/dev/null 2>&1 || true
    wait "$CHROME_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_PROFILE"
}
trap cleanup EXIT
mkdir -p "$ROOT/automation"
echo "Copying Chrome automation profile to $TMP_PROFILE"
rsync -a \
  --exclude='*/Cache/*' \
  --exclude='*/Code Cache/*' \
  --exclude='*/GPUCache/*' \
  --exclude='*/Service Worker/CacheStorage/*' \
  --exclude='*/Service Worker/ScriptCache/*' \
  "$PROFILE_SRC/Local State" "$TMP_PROFILE/" >/dev/null
rsync -a \
  --exclude='Cache' \
  --exclude='Code Cache' \
  --exclude='GPUCache' \
  --exclude='ShaderCache' \
  --exclude='GrShaderCache' \
  --exclude='GraphiteDawnCache' \
  --exclude='Service Worker/CacheStorage' \
  --exclude='Service Worker/ScriptCache' \
  "$PROFILE_SRC/$PROFILE_DIR" "$TMP_PROFILE/" >/dev/null

echo "Launching temporary Chrome profile on port $PORT"
"$CHROME" \
  --user-data-dir="$TMP_PROFILE" \
  --profile-directory="$PROFILE_DIR" \
  --remote-debugging-port="$PORT" \
  --no-first-run \
  --no-default-browser-check \
  about:blank >"$LOG" 2>&1 &
CHROME_PID=$!
for _ in {1..60}; do
  if curl -sf "http://127.0.0.1:$PORT/json/version" >/dev/null 2>&1; then break; fi
  sleep 1
done
curl -sf "http://127.0.0.1:$PORT/json/version" >/dev/null
python3 - <<'PY' > /tmp/youtube_batch_upload_items.tsv
import json
from pathlib import Path
ROOT=Path('/Users/yota/Projects/Automation/Youtube/知恵ネキ')
items=json.load(open(ROOT/'metadata/generated/release_batch_005_009.json'))
for v in items:
    video=str(ROOT/'renders'/f"{v['slug']}.mp4")
    print('\t'.join([v['slug'], video, v['title'], v['description'].replace('\n','\\n')]))
PY
while IFS=$'\t' read -r slug video title desc_escaped; do
  desc="${desc_escaped//\\n/$'\n'}"
  echo "=== Uploading $slug ==="
  node "$ROOT/scripts/upload_private_via_cdp.mjs" "$PORT" "$video" "$title" "$desc" true | tee -a "$ROOT/automation/upload_${slug}.log"
done < /tmp/youtube_batch_upload_items.tsv
