#!/bin/zsh
set -euo pipefail

ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
SLUG="short_006_psych_top5_reference"
BUILD_DIR="$ROOT/assets/generated/$SLUG"
IMG_DIR="$BUILD_DIR/real_images"
OUT_DIR="$ROOT/renders"
META_DIR="$ROOT/metadata/generated"
AUDIO_SRC="$ROOT/assets/generated/short_005_psych_top5_fastcut/coefont_fastcut_voice.m4a"
SEG_SRC_DIR="$ROOT/assets/generated/short_005_psych_top5_fastcut"
AUDIO_FILE="$BUILD_DIR/coefont_reference_voice.m4a"
MANIFEST_FILE="$BUILD_DIR/manifest.json"
VIDEO_FILE="$OUT_DIR/$SLUG.mp4"
METADATA_FILE="$META_DIR/$SLUG.md"

mkdir -p "$BUILD_DIR" "$OUT_DIR" "$META_DIR"
cp "$AUDIO_SRC" "$AUDIO_FILE"
for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
  cp "$SEG_SRC_DIR/coefont_segment_${i}.mp4" "$BUILD_DIR/coefont_segment_${i}.mp4"
done

cat > "$MANIFEST_FILE" <<EOF
{
  "width": 1080,
  "height": 1920,
  "fps": 18,
  "badge": "黒い心理学TOP5",
  "footer": "保存してあとで見る / #心理学 #仕事術 #shorts",
  "pauseSeconds": 0.12,
  "segmentVideos": [
    "$BUILD_DIR/coefont_segment_01.mp4",
    "$BUILD_DIR/coefont_segment_02.mp4",
    "$BUILD_DIR/coefont_segment_03.mp4",
    "$BUILD_DIR/coefont_segment_04.mp4",
    "$BUILD_DIR/coefont_segment_05.mp4",
    "$BUILD_DIR/coefont_segment_06.mp4",
    "$BUILD_DIR/coefont_segment_07.mp4",
    "$BUILD_DIR/coefont_segment_08.mp4",
    "$BUILD_DIR/coefont_segment_09.mp4",
    "$BUILD_DIR/coefont_segment_10.mp4",
    "$BUILD_DIR/coefont_segment_11.mp4",
    "$BUILD_DIR/coefont_segment_12.mp4"
  ],
  "scenes": [
    {"tag":"HOOK", "title":"人を動かす心理学", "subtitle":"人を動かす\n心理学TOP5", "imageFile":"$IMG_DIR/frame_01.png"},
    {"tag":"第5位", "title":"ザイオンス効果", "subtitle":"何度も見る相手を\n信頼しやすい", "imageFile":"$IMG_DIR/frame_02.png"},
    {"tag":"理由", "title":"なぜ効く？", "subtitle":"見慣れたものを\n脳が安全と判断する", "imageFile":"$IMG_DIR/frame_03.png"},
    {"tag":"第4位", "title":"返報性", "subtitle":"小さくもらうと\n返したくなる", "imageFile":"$IMG_DIR/frame_04.png"},
    {"tag":"理由", "title":"なぜ効く？", "subtitle":"借りを残すと\n気持ち悪い", "imageFile":"$IMG_DIR/frame_05.png"},
    {"tag":"第3位", "title":"損失回避", "subtitle":"得よりも\n損が強く刺さる", "imageFile":"$IMG_DIR/frame_06.png"},
    {"tag":"使い方", "title":"刺さる言い換え", "subtitle":"得しますより\n失いますの方が刺さる", "imageFile":"$IMG_DIR/frame_07.png"},
    {"tag":"第2位", "title":"ハロー効果", "subtitle":"一つ良いと\n全部良く見える", "imageFile":"$IMG_DIR/frame_08.png"},
    {"tag":"理由", "title":"印象が評価を引っ張る", "subtitle":"肩書き・実績・見た目が\n他の評価まで動かす", "imageFile":"$IMG_DIR/frame_09.png"},
    {"tag":"第1位", "title":"希少性", "subtitle":"今だけ、少ない、限定で\n欲しくなる", "imageFile":"$IMG_DIR/frame_10.png"},
    {"tag":"理由", "title":"なぜ効く？", "subtitle":"手に入らないかもで\n価値が上がる", "imageFile":"$IMG_DIR/frame_11.png"},
    {"tag":"まとめ", "title":"悪用は禁止", "subtitle":"営業・SNS・会議で\n伝え方の設計に使う", "imageFile":"$IMG_DIR/frame_12.png"}
  ]
}
EOF

RENDER_BIN="/tmp/render_reference_real_short"
swiftc -O -o "$RENDER_BIN" "$ROOT/scripts/render_reference_real_short.swift"
"$RENDER_BIN" "$MANIFEST_FILE" "$AUDIO_FILE" "$VIDEO_FILE"

cat > "$METADATA_FILE" <<'EOF'
# short_006_psych_top5_reference

## Title
人を動かす黒い心理学TOP5 #shorts

## Description
人を動かす心理学TOP5を、リアル人物画像と中央字幕で高速解説。
ザイオンス効果、返報性、損失回避、ハロー効果、希少性の「なぜ効くのか」までまとめました。

音声: CoeFont おしゃべりひろゆきメーカー
画像: GPT-image生成の縦長リアル人物画像 + コード字幕
編集: 音声セグメント境界で画像切替

#心理学 #仕事術 #SNS運用 #黒い心理学 #shorts

## Upload settings
- Privacy: Private if uploaded
- Made for kids: No
- Altered or synthetic content disclosure: Yes
- Music: None
EOF

echo "Built video: $VIDEO_FILE"
echo "Metadata: $METADATA_FILE"
