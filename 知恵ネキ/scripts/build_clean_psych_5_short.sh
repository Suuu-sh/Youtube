#!/bin/zsh
set -euo pipefail

ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
SLUG="short_007_psych_5_clean"
BUILD_DIR="$ROOT/assets/generated/$SLUG"
IMG_SRC_DIR="$ROOT/assets/generated/short_006_psych_top5_reference/real_images"
IMG_DIR="$BUILD_DIR/real_images"
OUT_DIR="$ROOT/renders"
META_DIR="$ROOT/metadata/generated"
AUDIO_FILE="$BUILD_DIR/kyoko_clean_voice.m4a"
MANIFEST_FILE="$BUILD_DIR/manifest.json"
VIDEO_FILE="$OUT_DIR/$SLUG.mp4"
METADATA_FILE="$META_DIR/$SLUG.md"

mkdir -p "$BUILD_DIR" "$IMG_DIR" "$OUT_DIR" "$META_DIR"
for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
  cp "$IMG_SRC_DIR/frame_${i}.png" "$IMG_DIR/frame_${i}.png"
done

texts=(
"人を動かす心理学を五つだけ、短く話します。悪用はなしで、伝え方の設計として見てください。"
"ザイオンス効果。人は何度も見る相手を、自然に信頼しやすくなります。"
"理由は、見慣れたものを脳が安全だと判断して、警戒心が下がるからです。"
"返報性。小さく何かをもらうと、人は返したくなります。"
"借りを残すと気持ち悪いので、お返ししてバランスを取りたくなるんです。"
"損失回避。人は得する喜びより、損する痛みを強く感じます。"
"だから、得しますより、このままだと失います、の方が行動につながりやすい。"
"ハロー効果。一つ良く見えると、他の部分まで良く見えてしまいます。"
"見た目、肩書き、実績など、目立つ印象が全体評価を引っ張るからです。"
"希少性。今だけ、少ない、限定。これだけで欲しい気持ちは強くなります。"
"手に入らないかもしれないと思うと、同じものでも価値が高く見えるからです。"
"大事なのは、騙すためじゃなく伝わる形にすること。SNS、営業、会議で使えます。"
)

audio_segments=()
for i in {1..12}; do
  printf -v n "%02d" "$i"
  text_file="$BUILD_DIR/voice_segment_${n}.txt"
  aiff_file="$BUILD_DIR/voice_segment_${n}.aiff"
  print -r -- "${texts[$i]}" > "$text_file"
  say -v Kyoko -r 285 -o "$aiff_file" -f "$text_file"
  audio_segments+=("$aiff_file")
done

swift "$ROOT/scripts/concat_audio_files.swift" "$AUDIO_FILE" 0.08 "${audio_segments[@]}"

cat > "$MANIFEST_FILE" <<EOF
{
  "width": 1080,
  "height": 1920,
  "fps": 18,
  "badge": "人を動かす心理学",
  "footer": "保存してあとで見る / #心理学 #仕事術 #shorts",
  "pauseSeconds": 0.08,
  "showCounter": false,
  "segmentAudioFiles": [
    "$BUILD_DIR/voice_segment_01.aiff",
    "$BUILD_DIR/voice_segment_02.aiff",
    "$BUILD_DIR/voice_segment_03.aiff",
    "$BUILD_DIR/voice_segment_04.aiff",
    "$BUILD_DIR/voice_segment_05.aiff",
    "$BUILD_DIR/voice_segment_06.aiff",
    "$BUILD_DIR/voice_segment_07.aiff",
    "$BUILD_DIR/voice_segment_08.aiff",
    "$BUILD_DIR/voice_segment_09.aiff",
    "$BUILD_DIR/voice_segment_10.aiff",
    "$BUILD_DIR/voice_segment_11.aiff",
    "$BUILD_DIR/voice_segment_12.aiff"
  ],
  "scenes": [
    {"tag":"HOOK", "title":"理屈だけでは動かない", "subtitle":"人を動かす\n心理学5選", "imageFile":"$IMG_DIR/frame_01.png"},
    {"tag":"心理効果", "title":"ザイオンス効果", "subtitle":"何度も見る相手を\n信頼しやすい", "imageFile":"$IMG_DIR/frame_02.png"},
    {"tag":"理由", "title":"見慣れたものは安全", "subtitle":"警戒心が下がって\n好感につながる", "imageFile":"$IMG_DIR/frame_03.png"},
    {"tag":"心理効果", "title":"返報性", "subtitle":"小さくもらうと\n返したくなる", "imageFile":"$IMG_DIR/frame_04.png"},
    {"tag":"理由", "title":"借りを残したくない", "subtitle":"お返しで\nバランスを取る", "imageFile":"$IMG_DIR/frame_05.png"},
    {"tag":"心理効果", "title":"損失回避", "subtitle":"得よりも\n損の痛みが強い", "imageFile":"$IMG_DIR/frame_06.png"},
    {"tag":"使い方", "title":"刺さる言い換え", "subtitle":"得しますより\n失いますが刺さる", "imageFile":"$IMG_DIR/frame_07.png"},
    {"tag":"心理効果", "title":"ハロー効果", "subtitle":"一つ良いと\n全部良く見える", "imageFile":"$IMG_DIR/frame_08.png"},
    {"tag":"理由", "title":"印象が評価を引っ張る", "subtitle":"肩書き・実績・見た目が\n全体評価に広がる", "imageFile":"$IMG_DIR/frame_09.png"},
    {"tag":"心理効果", "title":"希少性", "subtitle":"今だけ・少ない・限定で\n欲しくなる", "imageFile":"$IMG_DIR/frame_10.png"},
    {"tag":"理由", "title":"逃すかもが価値を上げる", "subtitle":"手に入らないほど\n価値が高く見える", "imageFile":"$IMG_DIR/frame_11.png"},
    {"tag":"まとめ", "title":"悪用せず設計に使う", "subtitle":"SNS・営業・会議で\n伝わる形にする", "imageFile":"$IMG_DIR/frame_12.png"}
  ]
}
EOF

RENDER_BIN="/tmp/render_reference_clean_short"
swiftc -O -o "$RENDER_BIN" "$ROOT/scripts/render_reference_clean_short.swift"
"$RENDER_BIN" "$MANIFEST_FILE" "$AUDIO_FILE" "$VIDEO_FILE"

cat > "$METADATA_FILE" <<'EOF'
# short_007_psych_5_clean

## Title
人を動かす心理学5選 #shorts

## Description
順位形式をやめて、心理効果を5つ並列で高速解説。
ザイオンス効果、返報性、損失回避、ハロー効果、希少性を、理由つきでまとめました。

音声: macOS Kyoko 日本語音声
画像: GPT-image生成の縦長リアル人物画像
編集: 音声の区切りに合わせて画像切替、中央字幕あり

#心理学 #仕事術 #SNS運用 #shorts

## Upload settings
- Privacy: Private if uploaded
- Made for kids: No
- Altered or synthetic content disclosure: Yes
- Music: None
EOF

echo "Built video: $VIDEO_FILE"
echo "Metadata: $METADATA_FILE"
