#!/bin/zsh
set -euo pipefail

ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
SRC_BUILD="$ROOT/assets/generated/short_007_psych_5_clean"
SLUG="sample_010_kansai_psych_2topic"
BUILD_DIR="$ROOT/assets/generated/$SLUG"
IMG_DIR="$BUILD_DIR/real_images"
OUT_DIR="$ROOT/renders"
META_DIR="$ROOT/metadata/generated"
VOICE_FILE="$BUILD_DIR/kyoko_kansai_2topic_voice.m4a"
BGM_FILE="$BUILD_DIR/psychology_bgm.wav"
AUDIO_FILE="$BUILD_DIR/kyoko_kansai_2topic_with_bgm.m4a"
MANIFEST_FILE="$BUILD_DIR/manifest.json"
VIDEO_FILE="$OUT_DIR/$SLUG.mp4"
METADATA_FILE="$META_DIR/$SLUG.md"

mkdir -p "$BUILD_DIR" "$IMG_DIR" "$OUT_DIR" "$META_DIR"
# 2 topics + hook + closing = 6 cuts
cp "$SRC_BUILD/real_images/frame_01.png" "$IMG_DIR/frame_01.png"
cp "$SRC_BUILD/real_images/frame_02.png" "$IMG_DIR/frame_02.png"
cp "$SRC_BUILD/real_images/frame_03.png" "$IMG_DIR/frame_03.png"
cp "$SRC_BUILD/real_images/frame_04.png" "$IMG_DIR/frame_04.png"
cp "$SRC_BUILD/real_images/frame_05.png" "$IMG_DIR/frame_05.png"
cp "$SRC_BUILD/real_images/frame_12.png" "$IMG_DIR/frame_06.png"

texts=(
"人を動かす心理学、今日は二つだけ試すで。短いから、雰囲気だけ見てな。"
"まずザイオンス効果。人は何回も見る相手ほど、なんか信頼しやすくなるんよ。"
"理由は、見慣れたもんを脳が安全やと判断して、警戒心が下がるからやねん。"
"次は返報性。ちょっと何かをもらうと、人は返したくなるんよ。"
"借りを残したままやと気持ち悪いから、お返ししてバランス取りたくなるんや。"
"こんな感じで関西弁にすると、硬い心理学も少し聞きやすくなるで。"
)

audio_segments=()
for i in {1..6}; do
  printf -v n "%02d" "$i"
  text_file="$BUILD_DIR/voice_segment_${n}.txt"
  aiff_file="$BUILD_DIR/voice_segment_${n}.aiff"
  print -r -- "${texts[$i]}" > "$text_file"
  say -v Kyoko -r 300 -o "$aiff_file" -f "$text_file"
  audio_segments+=("$aiff_file")
done

swift "$ROOT/scripts/concat_audio_files.swift" "$VOICE_FILE" 0.08 "${audio_segments[@]}"
DURATION=$(afinfo "$VOICE_FILE" | awk '/estimated duration/ {print $3; exit}')
python3 "$ROOT/scripts/generate_psych_bgm.py" "$DURATION" "$BGM_FILE"
swift "$ROOT/scripts/mix_voice_bgm.swift" "$VOICE_FILE" "$BGM_FILE" "$AUDIO_FILE" 1.0 0.16

cat > "$MANIFEST_FILE" <<EOF
{
  "width": 1080,
  "height": 1920,
  "fps": 18,
  "badge": "関西弁で心理学",
  "footer": "保存してあとで見る / #心理学 #仕事術 #shorts",
  "pauseSeconds": 0.08,
  "showCounter": false,
  "segmentAudioFiles": [
    "$BUILD_DIR/voice_segment_01.aiff",
    "$BUILD_DIR/voice_segment_02.aiff",
    "$BUILD_DIR/voice_segment_03.aiff",
    "$BUILD_DIR/voice_segment_04.aiff",
    "$BUILD_DIR/voice_segment_05.aiff",
    "$BUILD_DIR/voice_segment_06.aiff"
  ],
  "scenes": [
    {"tag":"SAMPLE", "title":"まずは2トピックだけ", "subtitle":"関西弁で\n心理学サンプル", "imageFile":"$IMG_DIR/frame_01.png"},
    {"tag":"心理効果", "title":"ザイオンス効果", "subtitle":"何回も見る相手を\n信頼しやすい", "imageFile":"$IMG_DIR/frame_02.png"},
    {"tag":"理由", "title":"見慣れたもんは安全", "subtitle":"警戒心が下がって\n好感につながる", "imageFile":"$IMG_DIR/frame_03.png"},
    {"tag":"心理効果", "title":"返報性", "subtitle":"ちょっともらうと\n返したくなる", "imageFile":"$IMG_DIR/frame_04.png"},
    {"tag":"理由", "title":"借りを残したくない", "subtitle":"お返しで\nバランスを取る", "imageFile":"$IMG_DIR/frame_05.png"},
    {"tag":"方向性", "title":"硬さをなくして差別化", "subtitle":"関西弁なら\n聞きやすくなる", "imageFile":"$IMG_DIR/frame_06.png"}
  ]
}
EOF

RENDER_BIN="/tmp/render_reference_clean_short"
swiftc -O -o "$RENDER_BIN" "$ROOT/scripts/render_reference_clean_short.swift"
"$RENDER_BIN" "$MANIFEST_FILE" "$AUDIO_FILE" "$VIDEO_FILE"

cat > "$METADATA_FILE" <<'EOF'
# sample_010_kansai_psych_2topic

## Title
関西弁で心理学サンプル #shorts

## Description
方針確認用の2トピック短尺サンプル。
ザイオンス効果と返報性のみ。

音声: macOS Kyoko 日本語音声（関西弁台本）
BGM: ローカル生成のオリジナル心理学風アンビエント
画像: GPT-image生成の縦長リアル人物画像

#心理学 #仕事術 #関西弁 #shorts
EOF

echo "Built video: $VIDEO_FILE"
echo "Metadata: $METADATA_FILE"
echo "BGM: $BGM_FILE"
echo "Mixed audio: $AUDIO_FILE"
