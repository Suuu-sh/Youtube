#!/bin/zsh
set -euo pipefail

ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
SLUG="short_004_gpt_image_zajonc_coefont"
BUILD_DIR="$ROOT/assets/generated/$SLUG"
OUT_DIR="$ROOT/renders"
META_DIR="$ROOT/metadata/generated"
BASE_IMAGE="${1:-$BUILD_DIR/base.png}"

mkdir -p "$BUILD_DIR" "$OUT_DIR" "$META_DIR"

if [[ ! -f "$BASE_IMAGE" ]]; then
  echo "Base image not found: $BASE_IMAGE" >&2
  echo "Generate/copy a GPT-image base to $BUILD_DIR/base.png or pass its path as the first argument." >&2
  exit 1
fi

SOURCE_IMAGE="$BUILD_DIR/base.png"
POSTER_IMAGE="$BUILD_DIR/explainer_poster.png"
NARRATION_FILE="$BUILD_DIR/narration.txt"
COEFONT_MP4="$BUILD_DIR/coefont_hiroyuki_voice.mp4"
COEFONT_AUDIO="$BUILD_DIR/coefont_hiroyuki_voice.m4a"
MANIFEST_FILE="$BUILD_DIR/manifest.json"
VIDEO_FILE="$OUT_DIR/$SLUG.mp4"
METADATA_FILE="$META_DIR/$SLUG.md"

if [[ "$BASE_IMAGE" != "$SOURCE_IMAGE" ]]; then
  cp "$BASE_IMAGE" "$SOURCE_IMAGE"
fi

cat > "$NARRATION_FILE" <<'EOF'
これ、ザイオンス効果という心理学の話です。
人は、何度も見たものに、なんとなく好感を持ちやすいんですよ。
最初は知らない顔なので、ちょっと警戒します。
でも二回、五回、十回と見ていくと、脳が見慣れたものだと判断します。
その結果、危険じゃなさそう、信頼してもよさそう、という感覚が生まれます。
SNSで毎日見る人を、いつのまにか信頼してしまうのも、これに近いです。
つまり、好かれたいなら、すごい一発より、何度も自然に見られることが大事です。
EOF

swift "$ROOT/scripts/compose_zajonc_explainer_poster.swift" "$SOURCE_IMAGE" "$POSTER_IMAGE"

if [[ ! -f "$COEFONT_AUDIO" ]]; then
  PORT="${COEFONT_PORT:-9911}"
  TMP_PROFILE="$(mktemp -d /tmp/coefont-upload-profile.XXXXXX)"
  CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  LOG="$BUILD_DIR/coefont_chrome.log"

  cleanup() {
    if [[ -n "${CHROME_PID:-}" ]]; then
      kill "$CHROME_PID" >/dev/null 2>&1 || true
      wait "$CHROME_PID" >/dev/null 2>&1 || true
    fi
    rm -rf "$TMP_PROFILE"
  }
  trap cleanup EXIT

  "$CHROME" \
    --user-data-dir="$TMP_PROFILE" \
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

  cat > "$BUILD_DIR/voice_segment_01.txt" <<'EOF'
これ、ザイオンス効果という心理学の話です。
EOF
  cat > "$BUILD_DIR/voice_segment_02.txt" <<'EOF'
人は何度も見たものに、なんとなく好感を持ちやすいんですよ。
EOF
  cat > "$BUILD_DIR/voice_segment_03.txt" <<'EOF'
最初は知らない顔なので、ちょっと警戒します。
EOF
  cat > "$BUILD_DIR/voice_segment_04.txt" <<'EOF'
でも何回も見ると、脳が見慣れたものだと判断します。
EOF
  cat > "$BUILD_DIR/voice_segment_05.txt" <<'EOF'
その結果、危険じゃなさそう、信頼してもよさそう、という感覚が生まれます。
EOF
  cat > "$BUILD_DIR/voice_segment_06.txt" <<'EOF'
SNSで毎日見る人を、いつのまにか信頼してしまうのも、これに近いです。
EOF
  cat > "$BUILD_DIR/voice_segment_07.txt" <<'EOF'
つまり、好かれたいなら、すごい一発より、何度も自然に見られることが大事です。
EOF

  segment_mp4s=()
  for i in 01 02 03 04 05 06 07; do
    segment_mp4="$BUILD_DIR/coefont_segment_${i}.mp4"
    node "$ROOT/scripts/generate_coefont_hiroyuki_mp4.mjs" "$PORT" "$BUILD_DIR" "$BUILD_DIR/voice_segment_${i}.txt" "coefont_segment_${i}.mp4"
    segment_mp4s+=("$segment_mp4")
  done

  swift "$ROOT/scripts/concat_audio_from_videos.swift" "$COEFONT_AUDIO" "${segment_mp4s[@]}"

  # Keep a convenient first-segment mp4 path for manual inspection.
  cp "$BUILD_DIR/coefont_segment_01.mp4" "$COEFONT_MP4"

  trap - EXIT
  cleanup
fi

cat > "$MANIFEST_FILE" <<EOF
{
  "width": 1080,
  "height": 1920,
  "fps": 24,
  "imagePath": "$POSTER_IMAGE",
  "badge": "図でわかる心理学",
  "footer": "保存してSNS運用に使う / #心理学 #ザイオンス効果 #shorts",
  "backdropMode": "solid",
  "captions": [
    {
      "start": 0.0,
      "end": 5.4,
      "title": "ザイオンス効果",
      "body": "何度も見たものに\\n好感を持ちやすい心理。",
      "focusX": 0.50,
      "focusY": 0.43,
      "zoom": 1.00
    },
    {
      "start": 5.4,
      "end": 11.5,
      "title": "最初は警戒する",
      "body": "知らない顔や情報は\\n少し距離を置かれやすい。",
      "focusX": 0.43,
      "focusY": 0.36,
      "zoom": 1.25
    },
    {
      "start": 11.5,
      "end": 18.2,
      "title": "見慣れる",
      "body": "2回、5回、10回と\\n接触回数が増えていく。",
      "focusX": 0.43,
      "focusY": 0.53,
      "zoom": 1.25
    },
    {
      "start": 18.2,
      "end": 25.6,
      "title": "警戒心が下がる",
      "body": "脳が「危険じゃない」と\\n判断しやすくなる。",
      "focusX": 0.43,
      "focusY": 0.70,
      "zoom": 1.25
    },
    {
      "start": 25.6,
      "end": 40.5,
      "title": "SNSで効く理由",
      "body": "すごい一発より、\\n自然に何度も見られること。",
      "focusX": 0.50,
      "focusY": 0.87,
      "zoom": 1.15
    }
  ]
}
EOF

swift "$ROOT/scripts/render_infographic_kenburns_short.swift" "$MANIFEST_FILE" "$COEFONT_AUDIO" "$VIDEO_FILE"

cat > "$METADATA_FILE" <<'EOF'
# short_004_gpt_image_zajonc_coefont

## Title
何度も見ると好きになる心理｜ザイオンス効果 #shorts

## Description
ザイオンス効果を、説明入り画像とナレーションで短く解説します。
人は何度も見たものに好感を持ちやすくなることがあります。
SNSで毎日見る人を信頼しやすくなる理由にもつながります。

音声: CoeFont おしゃべりひろゆきメーカー
画像: GPT-image生成ベース + コードで日本語テキストを合成

#心理学 #ザイオンス効果 #SNS運用 #仕事術 #shorts

## Hashtags
#心理学 #ザイオンス効果 #SNS運用 #仕事術 #shorts

## Upload settings
- Privacy: Private
- Made for kids: No
- Altered or synthetic content disclosure: Yes
- Music: None
- Related video: None
EOF

echo "Built video: $VIDEO_FILE"
echo "Metadata: $METADATA_FILE"
