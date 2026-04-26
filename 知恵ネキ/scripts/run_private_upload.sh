#!/bin/zsh
set -euo pipefail

ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
PROFILE_SRC="$HOME/Library/Application Support/Google/Chrome"
TMP_PROFILE="$(mktemp -d /tmp/youtube-upload-profile.XXXXXX)"
PORT=9222
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LOG="$ROOT/automation/upload_chrome.log"

VIDEO_PATH="$ROOT/renders/short_001_gmail_filter.mp4"
TITLE="Gmailの自動振り分け3分設定 #shorts"
DESCRIPTION=$'毎日のメール整理を減らすなら、まず1つフィルタを作るだけ。\n検索欄から条件を入れて、フィルタを作成し、ラベル付けや受信トレイのスキップを設定します。\n自分の運用に合わせて調整してください。\n\n#Gmail #自動化 #仕事効率化 #shorts'

cleanup() {
  if [[ -n "${CHROME_PID:-}" ]]; then
    kill "$CHROME_PID" >/dev/null 2>&1 || true
    wait "$CHROME_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_PROFILE"
}
trap cleanup EXIT

mkdir -p "$ROOT/automation"

echo "Copying Chrome profile to $TMP_PROFILE"
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
  "$PROFILE_SRC/Default" "$TMP_PROFILE/" >/dev/null

echo "Launching temporary Chrome profile on port $PORT"
"$CHROME" \
  --user-data-dir="$TMP_PROFILE" \
  --profile-directory=Default \
  --remote-debugging-port="$PORT" \
  --no-first-run \
  --no-default-browser-check \
  about:blank >"$LOG" 2>&1 &
CHROME_PID=$!

for _ in {1..60}; do
  if curl -sf "http://127.0.0.1:$PORT/json/version" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -sf "http://127.0.0.1:$PORT/json/version" >/dev/null

node "$ROOT/scripts/upload_private_via_cdp.mjs" "$PORT" "$VIDEO_PATH" "$TITLE" "$DESCRIPTION"
