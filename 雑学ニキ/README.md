# 雑学ニキ

雑学解説系チャンネル用の作業領域です。
知恵ネキとは素材、台本形式、投稿手順、検証観点を分けて管理します。

## ディレクトリ

- `ideas/` — 企画、テーマ候補、構成メモ
- `prompts/` — 台本・リサーチ・メタデータ生成用プロンプト
- `metadata/generated/` — 投稿用メタデータ、動画仕様 JSON
- `assets/generated/` — 生成画像、音声、manifest などの動画素材
- `renders/` — 書き出し済み mp4 と確認用画像
- `automation/` — アップロード、予約投稿、検証ログ
- `branding/` — チャンネルアイコン、トーン、デザインルール
- `scripts/` — 雑学ニキ向けの制作・投稿補助スクリプト
- `analytics/` — 投稿後の計測メモ

## 初期運用メモ

- 知恵ネキ用の素材やログを流用しない。
- 出典確認、事実確認、誤情報チェックを制作フローに含める。
- 投稿方法や使用する音声・BGM・画作りは、雑学ニキ用 README/手順書に追記していく。


## BGMルール

- 動画作成時は、原則として `Escort / もっぴーさうんど（DOVA-SYNDROME）` をBGMとして薄く入れる。
- BGMファイル: `/Users/yota/Projects/Automation/Youtube/_shared/bgm/dova-syndrome/escort_moppy_sound.mp3`
- 標準音量はナレーション `1.0`、BGM `0.10`。声が聞き取りづらい場合はBGMを `0.06〜0.08` に下げる。
- 動画説明欄に `BGM: Escort / もっぴーさうんど（DOVA-SYNDROME）` を入れる。
- レンダー後、BGMが声を邪魔していないか必ず確認する。
