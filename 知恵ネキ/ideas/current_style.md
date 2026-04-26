# Current style decision

## Voice
- 関西弁は使わない。
- 標準語ベース。喋るスピードは通常よりかなり速め、目安1.5倍。
- 候補: VOICEVOX ナースロボ＿タイプＴ
  - ノーマル: 47
  - 恐怖: 49
  - 内緒話: 50
- まずはナースロボ＿タイプＴの「恐怖」または「内緒話」を短尺サンプルで比較する。

## Theme
- 心理学専門ではなく「上手く生きる知恵」。
- 心理学、仕事、人間関係、SNS、習慣、判断力などを扱う。

## Test format
- 方針決め中はフル動画不要。
- 1トピック、20〜45秒の短尺サンプルで確認する。
- 理由だけでなく、具体例を入れる。

## Visual / audio
- リアル人物画像
- 字幕の四角い背景は使わない
- 太い字幕、黒フチ、薄いゴールド縁取り
- 下部の「保存してあとで見る」やハッシュタグ表示は使わない
- 上部のプログレスバーは使わない
- 下だけ黒くなるグラデーション/帯は使わない
- 上部のチャンネル名・タグ・タイトルは間隔を空けすぎず、まとまった情報ブロックにする
- 重要ワードは字幕内でゴールドにする
- ページ遷移/場面切り替え時の効果音は入れない
- 効果音を使う場合は、重要ワードや強調箇所だけに短く入れる。ただし声の邪魔にならない音量にする
- BGMは固定しない。動画内容に合わせて都度生成・選定する
  - 心理系: 不穏・低音・緊張感
  - 仕事術: ミニマルでテンポのある緊張感
  - 習慣/自己改善: 少し前向きで集中感
  - 人間関係: 静かで深い空気感

## Speed
- VOICEVOXでは speedScale を 1.45〜1.55 目安にする。
- 聞き取りづらければ 1.35 まで下げる。

## 2026-04-26 修正方針: 画像使い回し禁止・スマホ下部黒対策

- 公開候補動画では既存の `real_images/frame_*.png` をコピー流用しない。
- 各動画・各シーンごとに専用画像を新規生成する。
- 画像プロンプトには必ず以下を入れる。
  - `vertical 9:16, 1080x1920 composition`
  - `no black empty lower area, no dark foreground band, no heavy black table occupying the bottom`
  - `important subject and action centered in the middle safe area, away from YouTube Shorts right buttons and bottom caption UI`
  - `bright readable lower third with natural detail, not a black vignette`
- YouTubeアプリの下部UI・右ボタン・チャンネル表示は消せないため、動画内の重要文字と顔は中央寄せにする。
- 下部 360px には重要情報を置かない。暗い机・黒帯・影だけの画にしない。
- 上部 180px もスマホUIと被るため、タイトル文字は少し下げる。
