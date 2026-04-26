#!/bin/zsh
set -euo pipefail

ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
SLUG="short_003_zajonc_infographic"
SOURCE_IMAGE="${1:-/Users/yota/Downloads/IMG_9827.JPG}"
BUILD_DIR="$ROOT/assets/generated/$SLUG"
OUT_DIR="$ROOT/renders"
META_DIR="$ROOT/metadata/generated"

mkdir -p "$BUILD_DIR" "$OUT_DIR" "$META_DIR"

if [[ ! -f "$SOURCE_IMAGE" ]]; then
  echo "Source image not found: $SOURCE_IMAGE" >&2
  exit 1
fi

IMAGE_FILE="$BUILD_DIR/source.jpg"
NARRATION_FILE="$BUILD_DIR/narration.txt"
AUDIO_QUERY_FILE="$BUILD_DIR/audio_query.json"
AUDIO_FILE="$BUILD_DIR/voice.wav"
MANIFEST_FILE="$BUILD_DIR/manifest.json"
VIDEO_FILE="$OUT_DIR/$SLUG.mp4"
METADATA_FILE="$META_DIR/$SLUG.md"

cp "$SOURCE_IMAGE" "$IMAGE_FILE"

cat > "$NARRATION_FILE" <<'EOF'
これ、ザイオンス効果という心理学の話です。
要するに、人は何度も見たものに、なんとなく好感を持ちやすいんですよ。
実験では、知らない人の写真を、被験者に一回、二回、五回、十回と見せました。
すると、見た回数が多い顔ほど、好感度が上がりやすかった。
ポイントは、説得されたから好きになるんじゃなくて、接触回数が増えたから、警戒心が下がること。
SNSで毎日見かける人を、少し信頼してしまうのも、この仕組みに近いです。
EOF

"$HOME/.codex/bin/voicevox-engine-launch.sh"

curl -fsS -X POST \
  "http://127.0.0.1:50021/audio_query" \
  --get \
  --data-urlencode "text=$(cat "$NARRATION_FILE")" \
  --data-urlencode "speaker=13" \
  -o "$AUDIO_QUERY_FILE"

python3 - "$AUDIO_QUERY_FILE" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

# Generic calm male explainer settings.
# This intentionally does not imitate any specific real person's voice.
data["speedScale"] = 1.12
data["pitchScale"] = -0.04
data["intonationScale"] = 0.82
data["volumeScale"] = 1.35
data["prePhonemeLength"] = 0.08
data["postPhonemeLength"] = 0.10
data["outputSamplingRate"] = 48000
data["outputStereo"] = False

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
PY

curl -fsS -X POST \
  "http://127.0.0.1:50021/synthesis?speaker=13" \
  -H "Content-Type: application/json" \
  --data-binary "@$AUDIO_QUERY_FILE" \
  -o "$AUDIO_FILE"

cat > "$MANIFEST_FILE" <<EOF
{
  "width": 1080,
  "height": 1920,
  "fps": 24,
  "imagePath": "$IMAGE_FILE",
  "badge": "1分でわかる心理学",
  "footer": "保存してあとで見る / #心理学 #ザイオンス効果 #shorts",
  "captions": [
    {
      "start": 0.0,
      "end": 5.2,
      "title": "ザイオンス効果",
      "body": "何度も見るものに\\n好感を持ちやすい心理。",
      "focusX": 0.50,
      "focusY": 0.50,
      "zoom": 1.02
    },
    {
      "start": 5.2,
      "end": 11.2,
      "title": "実験のやり方",
      "body": "知らない人の写真を\\n1回・2回・5回・10回見せる。",
      "focusX": 0.51,
      "focusY": 0.35,
      "zoom": 1.72
    },
    {
      "start": 11.2,
      "end": 17.2,
      "title": "回数が増える",
      "body": "1回より2回。\\n2回より5回。",
      "focusX": 0.16,
      "focusY": 0.49,
      "zoom": 1.92
    },
    {
      "start": 17.2,
      "end": 23.0,
      "title": "結果",
      "body": "10回見た顔ほど\\n好感度が上がりやすい。",
      "focusX": 0.67,
      "focusY": 0.70,
      "zoom": 1.78
    },
    {
      "start": 23.0,
      "end": 36.0,
      "title": "理由",
      "body": "説得ではなく、接触回数で\\n警戒心が下がるから。",
      "focusX": 0.50,
      "focusY": 0.90,
      "zoom": 1.42
    }
  ]
}
EOF

swift "$ROOT/scripts/render_infographic_kenburns_short.swift" "$MANIFEST_FILE" "$AUDIO_FILE" "$VIDEO_FILE"

cat > "$METADATA_FILE" <<'EOF'
# short_003_zajonc_infographic

## Title
何度も見ると好きになる心理｜ザイオンス効果 #shorts

## Description
ザイオンス効果を、ミシガン大学の実験風の図解で短く解説。
人は何度も見たものに好感を持ちやすくなることがあります。
SNSや広告、営業で「何度も見かける人」を信頼しやすい理由にもつながります。

#心理学 #ザイオンス効果 #仕事術 #SNS運用 #shorts

## Hashtags
#心理学 #ザイオンス効果 #仕事術 #SNS運用 #shorts

## Upload settings
- Privacy: Private if uploaded
- Made for kids: No
- Altered or synthetic content disclosure: No, if using only the provided source image and programmatic overlays. Yes if replacing source with generated imagery.
- Music: None
- Related video: None

## Voice note
Actual imitation of a real person's voice is avoided. This version uses a generic calm male explainer voice via VOICEVOX speaker 13.
EOF

echo "Built video: $VIDEO_FILE"
echo "Metadata: $METADATA_FILE"

