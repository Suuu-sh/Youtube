#!/bin/zsh
set -euo pipefail

ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
SLUG="short_005_psych_top5_fastcut"
BUILD_DIR="$ROOT/assets/generated/$SLUG"
OUT_DIR="$ROOT/renders"
META_DIR="$ROOT/metadata/generated"
SPRITE_SRC="${1:-$BUILD_DIR/sprite_sheet.png}"

mkdir -p "$BUILD_DIR" "$OUT_DIR" "$META_DIR"

if [[ ! -f "$SPRITE_SRC" ]]; then
  echo "Sprite sheet not found: $SPRITE_SRC" >&2
  exit 1
fi

SPRITE="$BUILD_DIR/sprite_sheet.png"
NARRATION_FILE="$BUILD_DIR/narration.txt"
AUDIO_FILE="$BUILD_DIR/coefont_fastcut_voice.m4a"
MANIFEST_FILE="$BUILD_DIR/manifest.json"
VIDEO_FILE="$OUT_DIR/$SLUG.mp4"
METADATA_FILE="$META_DIR/$SLUG.md"

if [[ "$SPRITE_SRC" != "$SPRITE" ]]; then
  cp "$SPRITE_SRC" "$SPRITE"
fi

cat > "$NARRATION_FILE" <<'EOF'
人を動かす心理学トップファイブ。
五位、ザイオンス効果。人は何度も見る相手を信頼しやすい。理由は、見慣れたものを脳が安全だと判断するからです。
四位、返報性。小さく何かをもらうと返したくなる。理由は、借りを残すと気持ち悪いからです。
三位、損失回避。人は得する喜びより、損する痛みを強く感じる。だから、得しますより、失いますの方が刺さる。
二位、ハロー効果。一つ良く見えると全部良く見える。見た目、肩書き、実績が、他の評価まで引っ張ります。
一位、希少性。今だけ、少ない、限定。手に入らないかもと思うと、価値が高く見える。
悪用はだめですが、SNS、営業、会議で、伝え方を設計するならかなり効きます。
EOF

if [[ ! -f "$AUDIO_FILE" ]]; then
  PORT="${COEFONT_PORT:-9944}"
  TMP_PROFILE="$(mktemp -d /tmp/coefont-fastcut-profile.XXXXXX)"
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
  "$CHROME" --user-data-dir="$TMP_PROFILE" --remote-debugging-port="$PORT" --no-first-run --no-default-browser-check about:blank >"$LOG" 2>&1 &
  CHROME_PID=$!
  for _ in {1..60}; do
    curl -sf "http://127.0.0.1:$PORT/json/version" >/dev/null 2>&1 && break
    sleep 1
  done

  cat > "$BUILD_DIR/voice_segment_01.txt" <<'EOF'
人を動かす心理学トップファイブ。
EOF
  cat > "$BUILD_DIR/voice_segment_02.txt" <<'EOF'
五位、ザイオンス効果。人は何度も見る相手を信頼しやすい。
EOF
  cat > "$BUILD_DIR/voice_segment_03.txt" <<'EOF'
理由は、見慣れたものを脳が安全だと判断するからです。
EOF
  cat > "$BUILD_DIR/voice_segment_04.txt" <<'EOF'
四位、返報性。小さく何かをもらうと返したくなる。
EOF
  cat > "$BUILD_DIR/voice_segment_05.txt" <<'EOF'
理由は、借りを残すと気持ち悪いからです。
EOF
  cat > "$BUILD_DIR/voice_segment_06.txt" <<'EOF'
三位、損失回避。人は得する喜びより、損する痛みを強く感じる。
EOF
  cat > "$BUILD_DIR/voice_segment_07.txt" <<'EOF'
だから、得しますより、失いますの方が刺さる。
EOF
  cat > "$BUILD_DIR/voice_segment_08.txt" <<'EOF'
二位、ハロー効果。一つ良く見えると全部良く見える。
EOF
  cat > "$BUILD_DIR/voice_segment_09.txt" <<'EOF'
見た目、肩書き、実績が、他の評価まで引っ張ります。
EOF
  cat > "$BUILD_DIR/voice_segment_10.txt" <<'EOF'
一位、希少性。今だけ、少ない、限定。
EOF
  cat > "$BUILD_DIR/voice_segment_11.txt" <<'EOF'
手に入らないかもと思うと、価値が高く見える。
EOF
  cat > "$BUILD_DIR/voice_segment_12.txt" <<'EOF'
悪用はだめですが、SNS、営業、会議で、伝え方を設計するならかなり効きます。
EOF

  segment_mp4s=()
  for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
    node "$ROOT/scripts/generate_coefont_hiroyuki_mp4.mjs" "$PORT" "$BUILD_DIR" "$BUILD_DIR/voice_segment_${i}.txt" "coefont_segment_${i}.mp4"
    segment_mp4s+=("$BUILD_DIR/coefont_segment_${i}.mp4")
  done
  swift "$ROOT/scripts/concat_audio_from_videos.swift" "$AUDIO_FILE" "${segment_mp4s[@]}"
  trap - EXIT
  cleanup
fi

cat > "$MANIFEST_FILE" <<EOF
{
  "width": 1080,
  "height": 1920,
  "fps": 24,
  "spriteSheet": "$SPRITE",
  "columns": 5,
  "rows": 5,
  "badge": "黒い心理学TOP5",
  "footer": "保存してあとで見る / #心理学 #仕事術 #shorts",
  "scenes": [
    {"tag":"HOOK","title":"人を動かす\\n心理学TOP5","body":"知ってるだけで\\n見え方が変わる。"},
    {"tag":"第5位","title":"ザイオンス効果","body":"何度も見る相手を\\n信頼しやすい。"},
    {"tag":"理由","title":"脳は見慣れたものを\\n安全と判断する","body":"警戒心が下がるから\\n好感につながる。"},
    {"tag":"使い方","title":"一発より\\n接触回数","body":"自然に何度も\\n見られる設計。"},
    {"tag":"注意","title":"しつこいと\\n逆効果","body":"接触は自然さが命。"},
    {"tag":"第4位","title":"返報性の原理","body":"もらうと\\n返したくなる。"},
    {"tag":"理由","title":"借りを残すと\\n気持ち悪い","body":"だからお返しで\\nバランスを取る。"},
    {"tag":"使い方","title":"先にGiveする","body":"売る前に\\n役に立つ。"},
    {"tag":"注意","title":"見返り目的は\\nバレる","body":"露骨だと信用を失う。"},
    {"tag":"第3位","title":"損失回避","body":"得よりも\\n損が怖い。"},
    {"tag":"理由","title":"損の痛みは\\n得の喜びより強い","body":"だから失う未来に\\n反応しやすい。"},
    {"tag":"使い方","title":"失うものを\\n見せる","body":"ベネフィットより\\n放置リスク。"},
    {"tag":"注意","title":"煽りすぎは\\n逆効果","body":"不安商法にしない。"},
    {"tag":"第2位","title":"ハロー効果","body":"一つ良いと\\n全部良く見える。"},
    {"tag":"理由","title":"目立つ長所が\\n全体評価に広がる","body":"第一印象が\\n判断を引っ張る。"},
    {"tag":"使い方","title":"最初の1秒を\\n整える","body":"アイコン、肩書き、\\n冒頭が大事。"},
    {"tag":"注意","title":"中身が薄いと\\n続かない","body":"印象は入口でしかない。"},
    {"tag":"第1位","title":"希少性の原理","body":"少ないものほど\\n欲しくなる。"},
    {"tag":"理由","title":"手に入らないかもで\\n価値が上がる","body":"限定・残りわずか・\\n今だけに反応する。"},
    {"tag":"使い方","title":"期限と数を\\n明確にする","body":"本当に限りがある時だけ。"},
    {"tag":"注意","title":"嘘の限定は\\n信用を壊す","body":"信頼は一瞬で消える。"},
    {"tag":"まとめ","title":"人は理屈だけで\\n動かない","body":"感情と認知で\\n判断している。"},
    {"tag":"実践","title":"SNSなら\\n接触回数","body":"営業ならGive。\\n提案なら損失回避。"},
    {"tag":"保存推奨","title":"悪用せず\\n設計に使う","body":"人を騙すより、\\n伝わる形にする。"},
    {"tag":"END","title":"次は\\n職場心理TOP5","body":"見たい人は\\n保存して待ってて。"}
  ]
}
EOF

FRAMES_DIR="$BUILD_DIR/vertical_frames"
rm -rf "$FRAMES_DIR"
swift "$ROOT/scripts/create_vertical_story_frames.swift" "$MANIFEST_FILE" "$FRAMES_DIR"
python3 - "$MANIFEST_FILE" "$FRAMES_DIR" <<'PY'
import json, sys, pathlib
manifest = pathlib.Path(sys.argv[1])
frames_dir = pathlib.Path(sys.argv[2])
data = json.loads(manifest.read_text())
data["imageFiles"] = [str(frames_dir / f"frame_{i:02d}.png") for i in range(1, len(data["scenes"]) + 1)]
# Keep old sprite fields only as fallback metadata. Renderer now prefers imageFiles.
manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2))
PY

swift "$ROOT/scripts/render_fastcut_storyboard_short.swift" "$MANIFEST_FILE" "$AUDIO_FILE" "$VIDEO_FILE"

cat > "$METADATA_FILE" <<'EOF'
# short_005_psych_top5_fastcut

## Title
人を動かす黒い心理学TOP5 #shorts

## Description
人の判断に影響する心理学をTOP5形式で高速解説。
ザイオンス効果、返報性、損失回避、ハロー効果、希少性を短くまとめました。
各心理効果の理由まで入れて、SNS・営業・会議で「伝わりやすくする設計」として使える形にまとめました。

音声: CoeFont おしゃべりひろゆきメーカー
画像: 1080×1920ネイティブ縦長ストーリー画像25枚 + コード字幕

#心理学 #仕事術 #SNS運用 #黒い心理学 #shorts

## Upload settings
- Privacy: Private if uploaded
- Made for kids: No
- Altered or synthetic content disclosure: Yes
- Music: None
EOF

echo "Built video: $VIDEO_FILE"
echo "Metadata: $METADATA_FILE"
