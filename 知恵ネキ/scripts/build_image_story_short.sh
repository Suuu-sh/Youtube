#!/bin/zsh
set -euo pipefail

ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
SLUG="short_002_meeting_visibility"
BUILD_DIR="$ROOT/assets/generated/$SLUG"
OUT_DIR="$ROOT/renders"
META_DIR="$ROOT/metadata/generated"

mkdir -p "$BUILD_DIR" "$OUT_DIR" "$META_DIR"

SOURCE_IMAGE="${1:-$BUILD_DIR/background.png}"
if [[ ! -f "$SOURCE_IMAGE" ]]; then
  echo "Background image not found: $SOURCE_IMAGE" >&2
  echo "Pass a generated background image path as the first argument, or place one at $BUILD_DIR/background.png" >&2
  exit 1
fi

BACKGROUND_FILE="$BUILD_DIR/background.png"
NARRATION_FILE="$BUILD_DIR/narration.txt"
AUDIO_FILE="$BUILD_DIR/voice.aiff"
MANIFEST_FILE="$BUILD_DIR/manifest.json"
VIDEO_FILE="$OUT_DIR/$SLUG.mp4"
METADATA_FILE="$META_DIR/$SLUG.md"

if [[ "$SOURCE_IMAGE" != "$BACKGROUND_FILE" ]]; then
  cp "$SOURCE_IMAGE" "$BACKGROUND_FILE"
fi

cat > "$NARRATION_FILE" <<'EOF'
会議で発言しない人、実は能力が低いんじゃなくて、見えてないだけで損してます。
人は頭の中より、外に出た言葉で相手を評価します。
だから同じアイデアを持っていても、短く言語化した人の方が、考えている人に見えやすい。
対策は簡単。完璧な意見を言う必要はありません。
結論は賛成です。理由は一つで、リスクが小さいからです。
この形で一回だけ出す。
発言は自己主張じゃなく、存在を見える化する行動です。
EOF

cat > "$MANIFEST_FILE" <<EOF
{
  "width": 1080,
  "height": 1920,
  "fps": 24,
  "subtitle": "仕事で損しない心理学",
  "footer": "保存して会議前に見る / #心理学 #仕事術 #shorts",
  "backgroundImage": "$BACKGROUND_FILE",
  "segments": [
    {
      "hook": "会議で\\n発言しない人\\n損してます",
      "body": "能力が低いんじゃなく\\n“見えてない”だけ。",
      "accentHex": "#F7C46C"
    },
    {
      "hook": "人は\\n頭の中を\\n評価できない",
      "body": "評価されるのは\\n外に出た言葉と行動。",
      "accentHex": "#88D8FF"
    },
    {
      "hook": "同じ考えでも\\n言った人が\\n得をする",
      "body": "短く言語化した人ほど\\n“考えている人”に見える。",
      "accentHex": "#A5F0A0"
    },
    {
      "hook": "完璧な意見は\\nいらない",
      "body": "結論＋理由1つ。\\nまずはこの型だけでOK。",
      "accentHex": "#FF9AB6"
    },
    {
      "hook": "発言は\\n自己主張じゃない",
      "body": "存在を見える化する\\n小さな仕事術。",
      "accentHex": "#B8A6FF"
    }
  ]
}
EOF

say -v Kyoko -r 255 -f "$NARRATION_FILE" -o "$AUDIO_FILE"
swift "$ROOT/scripts/render_image_story_short.swift" "$MANIFEST_FILE" "$AUDIO_FILE" "$VIDEO_FILE"

cat > "$METADATA_FILE" <<'EOF'
# short_002_meeting_visibility

## Title
会議で発言しない人が損する理由 #shorts

## Description
会議で発言しない人が損しやすい理由を、仕事で使える心理学として短く解説します。
能力の問題ではなく、考えが周囲から見えにくいことが評価差につながることがあります。
まずは「結論＋理由1つ」だけでOK。

#心理学 #仕事術 #会議 #コミュニケーション #shorts

## Hashtags
#心理学 #仕事術 #会議 #コミュニケーション #shorts

## Upload settings
- Privacy: Private if uploaded
- Made for kids: No
- Altered or synthetic content disclosure: Yes, background image generated with AI
- Music: None
- Related video: None

## Visual generation prompt summary
Cinematic semi-realistic vertical illustration of a cozy office meeting scene, no text/logos, generous negative space for captions.
EOF

echo "Built video: $VIDEO_FILE"
echo "Metadata: $METADATA_FILE"

