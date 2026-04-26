#!/bin/zsh
set -euo pipefail

ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
SRC_SLUG="short_007_psych_5_clean"
SLUG="short_009_psych_5_kansai_bgm"
SRC_BUILD="$ROOT/assets/generated/$SRC_SLUG"
BUILD_DIR="$ROOT/assets/generated/$SLUG"
IMG_DIR="$BUILD_DIR/real_images"
OUT_DIR="$ROOT/renders"
META_DIR="$ROOT/metadata/generated"
VOICE_FILE="$BUILD_DIR/kyoko_kansai_voice_only.m4a"
BGM_FILE="$BUILD_DIR/psychology_bgm.wav"
AUDIO_FILE="$BUILD_DIR/kyoko_kansai_with_psychology_bgm.m4a"
MANIFEST_FILE="$BUILD_DIR/manifest.json"
VIDEO_FILE="$OUT_DIR/$SLUG.mp4"
METADATA_FILE="$META_DIR/$SLUG.md"

mkdir -p "$BUILD_DIR" "$IMG_DIR" "$OUT_DIR" "$META_DIR"
for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
  cp "$SRC_BUILD/real_images/frame_${i}.png" "$IMG_DIR/frame_${i}.png"
done

texts=(
"人を動かす心理学を五つだけ、サクッと話すで。悪用はあかん。伝え方の設計として見てな。"
"ザイオンス効果。人は何回も見る相手ほど、なんか信頼しやすくなるんよ。"
"なんでか言うと、見慣れたもんを脳が安全やと判断して、警戒心が下がるからやねん。"
"返報性。ちょっと何かをもらうと、人は返したくなるんよ。"
"借りを残したままやと気持ち悪いから、お返ししてバランス取りたくなるんや。"
"損失回避。人は得する嬉しさより、損する痛みのほうを強く感じるんよ。"
"せやから、得しますより、このままやと失います、のほうが行動につながりやすい。"
"ハロー効果。一つ良く見えたら、他の部分まで良く見えてまう。"
"見た目、肩書き、実績みたいな目立つ印象が、全体の評価まで引っ張るんやね。"
"希少性。今だけ、少ない、限定。これだけで欲しい気持ちは強くなる。"
"手に入らへんかも、と思った瞬間、同じもんでも価値が高く見えるんよ。"
"大事なんは、騙すためやなくて伝わる形にすること。SNS、営業、会議で使えるで。"
)

audio_segments=()
for i in {1..12}; do
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
    "$BUILD_DIR/voice_segment_06.aiff",
    "$BUILD_DIR/voice_segment_07.aiff",
    "$BUILD_DIR/voice_segment_08.aiff",
    "$BUILD_DIR/voice_segment_09.aiff",
    "$BUILD_DIR/voice_segment_10.aiff",
    "$BUILD_DIR/voice_segment_11.aiff",
    "$BUILD_DIR/voice_segment_12.aiff"
  ],
  "scenes": [
    {"tag":"HOOK", "title":"理屈だけでは動かへん", "subtitle":"関西弁で\n心理学5選", "imageFile":"$IMG_DIR/frame_01.png"},
    {"tag":"心理効果", "title":"ザイオンス効果", "subtitle":"何回も見る相手を\n信頼しやすい", "imageFile":"$IMG_DIR/frame_02.png"},
    {"tag":"理由", "title":"見慣れたもんは安全", "subtitle":"警戒心が下がって\n好感につながる", "imageFile":"$IMG_DIR/frame_03.png"},
    {"tag":"心理効果", "title":"返報性", "subtitle":"ちょっともらうと\n返したくなる", "imageFile":"$IMG_DIR/frame_04.png"},
    {"tag":"理由", "title":"借りを残したくない", "subtitle":"お返しで\nバランスを取る", "imageFile":"$IMG_DIR/frame_05.png"},
    {"tag":"心理効果", "title":"損失回避", "subtitle":"得よりも\n損の痛みが強い", "imageFile":"$IMG_DIR/frame_06.png"},
    {"tag":"使い方", "title":"刺さる言い換え", "subtitle":"得しますより\n失いますが刺さる", "imageFile":"$IMG_DIR/frame_07.png"},
    {"tag":"心理効果", "title":"ハロー効果", "subtitle":"一つ良いと\n全部良く見えてまう", "imageFile":"$IMG_DIR/frame_08.png"},
    {"tag":"理由", "title":"印象が評価を引っ張る", "subtitle":"目立つ印象が\n全体評価に広がる", "imageFile":"$IMG_DIR/frame_09.png"},
    {"tag":"心理効果", "title":"希少性", "subtitle":"今だけ・少ない・限定で\n欲しくなる", "imageFile":"$IMG_DIR/frame_10.png"},
    {"tag":"理由", "title":"逃すかもが価値を上げる", "subtitle":"手に入らへんほど\n価値が高く見える", "imageFile":"$IMG_DIR/frame_11.png"},
    {"tag":"まとめ", "title":"悪用せんと設計に使う", "subtitle":"SNS・営業・会議で\n伝わる形にする", "imageFile":"$IMG_DIR/frame_12.png"}
  ]
}
EOF

RENDER_BIN="/tmp/render_reference_clean_short"
swiftc -O -o "$RENDER_BIN" "$ROOT/scripts/render_reference_clean_short.swift"
"$RENDER_BIN" "$MANIFEST_FILE" "$AUDIO_FILE" "$VIDEO_FILE"

cat > "$METADATA_FILE" <<'EOF'
# short_009_psych_5_kansai_bgm

## Title
関西弁で人を動かす心理学5選 #shorts

## Description
関西弁ナレーションで差別化した版。
心理学っぽい暗めのアンビエントBGM、順位なし、中央の黒帯なし、リアル人物画像と中央字幕で解説。

音声: macOS Kyoko 日本語音声（関西弁台本）
BGM: ローカル生成のオリジナル心理学風アンビエント
画像: GPT-image生成の縦長リアル人物画像
編集: 音声の区切りに合わせて画像切替、中央字幕あり

#心理学 #仕事術 #SNS運用 #関西弁 #shorts

## Upload settings
- Privacy: Private if uploaded
- Made for kids: No
- Altered or synthetic content disclosure: Yes
- Music: Original generated BGM
EOF

echo "Built video: $VIDEO_FILE"
echo "Metadata: $METADATA_FILE"
echo "BGM: $BGM_FILE"
echo "Mixed audio: $AUDIO_FILE"
