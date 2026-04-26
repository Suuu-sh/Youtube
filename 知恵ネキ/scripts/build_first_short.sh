#!/bin/zsh
set -euo pipefail

ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
BUILD_DIR="$ROOT/assets/generated/short_001_gmail_filter"
OUT_DIR="$ROOT/renders"
META_DIR="$ROOT/metadata/generated"

mkdir -p "$BUILD_DIR" "$OUT_DIR" "$META_DIR"

NARRATION_FILE="$BUILD_DIR/narration.txt"
AUDIO_FILE="$BUILD_DIR/voice.aiff"
MANIFEST_FILE="$BUILD_DIR/manifest.json"
VIDEO_FILE="$OUT_DIR/short_001_gmail_filter.mp4"
METADATA_FILE="$META_DIR/short_001_gmail_filter.md"

cat > "$NARRATION_FILE" <<'EOF'
毎日同じメール整理をしているなら、Gmailのフィルタを一回作るだけでかなり楽になります。
まず検索欄に送り主や件名の条件を入れて、検索オプションからフィルタを作成。
次に、ラベルを付ける、受信トレイをスキップする、既読にする、みたいな処理を選びます。
最後に一致する既存スレッドにも適用すれば、請求書、通知、メルマガを自動で分けられます。
手で整理していた人は、まず一つだけ作ってみてください。保存してあとで設定できます。
EOF

cat > "$MANIFEST_FILE" <<'EOF'
{
  "width": 1080,
  "height": 1920,
  "fps": 30,
  "title": "Gmailの自動振り分け3分設定",
  "subtitle": "AI / 自動化 Tips",
  "footer": "保存してあとで設定 / #Gmail #自動化 #仕事効率化 #shorts",
  "slides": [
    {
      "title": "毎日の\nメール整理\nこれで終了",
      "lines": [
        "毎回同じメールを探す作業を減らす",
        "Gmailのフィルタを1回作るだけ",
        "最初は1種類だけでOK"
      ],
      "accentHex": "#6C8CFF"
    },
    {
      "title": "STEP 1\n条件を入れる",
      "lines": [
        "検索欄に送り主や件名を入力",
        "通知・請求書・メルマガで分ける",
        "まずは一番多い種類から"
      ],
      "accentHex": "#6FD3FF"
    },
    {
      "title": "STEP 2\nフィルタを作成",
      "lines": [
        "検索オプションを開く",
        "条件を確認してフィルタを作成",
        "ここで自動化の入口ができる"
      ],
      "accentHex": "#8FE388"
    },
    {
      "title": "STEP 3\n処理を選ぶ",
      "lines": [
        "ラベルを付ける",
        "受信トレイをスキップする",
        "必要なら既読にもする"
      ],
      "accentHex": "#FFD36C"
    },
    {
      "title": "結果\n受信箱が静かになる",
      "lines": [
        "一致する既存スレッドにも適用",
        "手作業の整理時間を減らせる",
        "保存してあとで設定してみる"
      ],
      "accentHex": "#FF8C8C"
    }
  ]
}
EOF

say -v Kyoko -r 250 -f "$NARRATION_FILE" -o "$AUDIO_FILE"
swift "$ROOT/scripts/render_short.swift" "$MANIFEST_FILE" "$AUDIO_FILE" "$VIDEO_FILE"

cat > "$METADATA_FILE" <<'EOF'
# short_001_gmail_filter

## Title
Gmailの自動振り分け3分設定 #shorts

## Description
毎日のメール整理を減らすなら、まず1つフィルタを作るだけ。
検索欄から条件を入れて、フィルタを作成し、ラベル付けや受信トレイのスキップを設定します。
自分の運用に合わせて調整してください。

#Gmail #自動化 #仕事効率化 #shorts

## Hashtags
#Gmail #自動化 #仕事効率化 #shorts

## Upload settings
- Privacy: Private
- Made for kids: No
- Altered or synthetic content disclosure: No
- Music: None
- Related video: None
EOF

echo "Built video: $VIDEO_FILE"
echo "Metadata: $METADATA_FILE"
