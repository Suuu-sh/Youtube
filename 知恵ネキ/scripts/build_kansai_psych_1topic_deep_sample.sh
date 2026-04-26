#!/bin/zsh
set -euo pipefail

ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
SRC_BUILD="$ROOT/assets/generated/short_007_psych_5_clean"
SLUG="sample_011_kansai_zajonc_deep"
BUILD_DIR="$ROOT/assets/generated/$SLUG"
IMG_DIR="$BUILD_DIR/real_images"
OUT_DIR="$ROOT/renders"
META_DIR="$ROOT/metadata/generated"
VOICE_FILE="$BUILD_DIR/kyoko_kansai_zajonc_voice.m4a"
BGM_FILE="$BUILD_DIR/psychology_bgm.wav"
AUDIO_FILE="$BUILD_DIR/kyoko_kansai_zajonc_with_bgm.m4a"
MANIFEST_FILE="$BUILD_DIR/manifest.json"
VIDEO_FILE="$OUT_DIR/$SLUG.mp4"
METADATA_FILE="$META_DIR/$SLUG.md"

mkdir -p "$BUILD_DIR" "$IMG_DIR" "$OUT_DIR" "$META_DIR"
# One-topic deep sample: hook + explanation + reason + examples + caution + summary
cp "$SRC_BUILD/real_images/frame_01.png" "$IMG_DIR/frame_01.png"
cp "$SRC_BUILD/real_images/frame_02.png" "$IMG_DIR/frame_02.png"
cp "$SRC_BUILD/real_images/frame_03.png" "$IMG_DIR/frame_03.png"
cp "$SRC_BUILD/real_images/frame_02.png" "$IMG_DIR/frame_04.png"
cp "$SRC_BUILD/real_images/frame_03.png" "$IMG_DIR/frame_05.png"
cp "$SRC_BUILD/real_images/frame_12.png" "$IMG_DIR/frame_06.png"
cp "$SRC_BUILD/real_images/frame_12.png" "$IMG_DIR/frame_07.png"

texts=(
"今日はザイオンス効果だけ、ちょい深掘りするで。これ、SNSとか営業でめちゃ使えるやつやねん。"
"ザイオンス効果っていうのは、人は何回も見る相手ほど、なんか信頼しやすくなるって心理や。"
"理由はシンプルで、脳は見慣れたもんを安全やと判断しやすい。つまり、知らん人から、知ってる人に変わるんよ。"
"たとえばSNSやったら、一回だけバズるより、毎日短く顔出す人のほうが覚えられやすい。"
"営業でも同じで、初回で売り込むより、事例、豆知識、軽い連絡を何回か挟むほうが警戒されにくいんや。"
"ただし注意点もある。しつこいDMとか、毎回売り込みばっかりやと逆効果やで。自然に役立つ接触にするのがコツ。"
"まとめると、一発で信用を取ろうとせんこと。何回も自然に見られる設計を作る。これがザイオンス効果の使い方や。"
)

audio_segments=()
for i in {1..7}; do
  printf -v n "%02d" "$i"
  text_file="$BUILD_DIR/voice_segment_${n}.txt"
  aiff_file="$BUILD_DIR/voice_segment_${n}.aiff"
  print -r -- "${texts[$i]}" > "$text_file"
  say -v Kyoko -r 295 -o "$aiff_file" -f "$text_file"
  audio_segments+=("$aiff_file")
done

swift "$ROOT/scripts/concat_audio_files.swift" "$VOICE_FILE" 0.08 "${audio_segments[@]}"
DURATION=$(afinfo "$VOICE_FILE" | awk '/estimated duration/ {print $3; exit}')
python3 "$ROOT/scripts/generate_psych_bgm.py" "$DURATION" "$BGM_FILE"
swift "$ROOT/scripts/mix_voice_bgm.swift" "$VOICE_FILE" "$BGM_FILE" "$AUDIO_FILE" 1.0 0.15

cat > "$MANIFEST_FILE" <<EOF
{
  "width": 1080,
  "height": 1920,
  "fps": 18,
  "badge": "関西弁で心理学",
  "footer": "保存してあとで見る / #心理学 #SNS運用 #shorts",
  "pauseSeconds": 0.08,
  "showCounter": false,
  "segmentAudioFiles": [
    "$BUILD_DIR/voice_segment_01.aiff",
    "$BUILD_DIR/voice_segment_02.aiff",
    "$BUILD_DIR/voice_segment_03.aiff",
    "$BUILD_DIR/voice_segment_04.aiff",
    "$BUILD_DIR/voice_segment_05.aiff",
    "$BUILD_DIR/voice_segment_06.aiff",
    "$BUILD_DIR/voice_segment_07.aiff"
  ],
  "scenes": [
    {"tag":"DEEP DIVE", "title":"1テーマだけ深掘り", "subtitle":"ザイオンス効果を\n具体例で解説", "imageFile":"$IMG_DIR/frame_01.png"},
    {"tag":"心理効果", "title":"ザイオンス効果", "subtitle":"何回も見る相手を\n信頼しやすい", "imageFile":"$IMG_DIR/frame_02.png"},
    {"tag":"理由", "title":"知らん人から知ってる人へ", "subtitle":"見慣れたもんを\n脳が安全と判断する", "imageFile":"$IMG_DIR/frame_03.png"},
    {"tag":"具体例 SNS", "title":"一回のバズより接触回数", "subtitle":"毎日短く顔出す人は\n覚えられやすい", "imageFile":"$IMG_DIR/frame_04.png"},
    {"tag":"具体例 営業", "title":"初回で売り込まない", "subtitle":"事例・豆知識・軽い連絡で\n警戒心を下げる", "imageFile":"$IMG_DIR/frame_05.png"},
    {"tag":"注意", "title":"しつこいと逆効果", "subtitle":"売り込み連発より\n自然に役立つ接触", "imageFile":"$IMG_DIR/frame_06.png"},
    {"tag":"まとめ", "title":"信用は一発で取らない", "subtitle":"何回も自然に\n見られる設計を作る", "imageFile":"$IMG_DIR/frame_07.png"}
  ]
}
EOF

RENDER_BIN="/tmp/render_reference_clean_short"
swiftc -O -o "$RENDER_BIN" "$ROOT/scripts/render_reference_clean_short.swift"
"$RENDER_BIN" "$MANIFEST_FILE" "$AUDIO_FILE" "$VIDEO_FILE"

cat > "$METADATA_FILE" <<'EOF'
# sample_011_kansai_zajonc_deep

## Title
ザイオンス効果を関西弁で具体例解説 #shorts

## Description
方針確認用の1トピック深掘りサンプル。
理由だけでなく、SNS・営業での具体例まで入れた構成。

音声: macOS Kyoko 日本語音声（関西弁台本）
BGM: ローカル生成のオリジナル心理学風アンビエント
画像: GPT-image生成の縦長リアル人物画像

#心理学 #SNS運用 #営業 #関西弁 #shorts
EOF

echo "Built video: $VIDEO_FILE"
echo "Metadata: $METADATA_FILE"
echo "BGM: $BGM_FILE"
echo "Mixed audio: $AUDIO_FILE"
